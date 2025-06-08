import 'package:flutter/material.dart';
import 'package:plengi_ai/services/ai_services.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:plengi_ai/models/message.dart';
import 'package:plengi_ai/utils/location/location_utils.dart';
import 'package:plengi_ai/utils/permission/permission_utils.dart';
import 'package:plengi_ai/services/frequent_question_service.dart';
import 'package:plengi_ai/models/frequent_question.dart';
import 'package:plengi_ai/models/location_history.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AIServices.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plengi AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isAiResponding = false;
  String _currentAiResponse = '';
  StreamSubscription? _aiResponseSubscription;
  late Box<Message> messageBox;
  final LocationHistoryManager _locationHistoryManager =
      LocationHistoryManager();
  final FrequentQuestionService _frequentQuestionService =
      FrequentQuestionService();
  List<FrequentQuestion> _frequentQuestions = [];
  String _selectedCategory = '위치';

  @override
  void initState() {
    super.initState();

    // 초기화 작업을 비동기적으로 처리
    Future.microtask(() async {
      await _initHive();
      if (mounted) {
        await PermissionUtils.checkAndRequestPermission(context);
      }
    });
  }

  // Hive 초기화
  Future<void> _initHive() async {
    try {
      Hive.registerAdapter(MessageAdapter());
      Hive.registerAdapter(FrequentQuestionAdapter());
      Hive.registerAdapter(LocationHistoryAdapter());
      messageBox = await Hive.openBox<Message>('messages');
      await _loadMessages();
      await _locationHistoryManager.initialize();
      await _frequentQuestionService.initialize();
      await _loadFrequentQuestions();
    } catch (e) {
      print('초기화 중 오류 발생: $e');
    }
  }

  // 메시지 불러오기
  Future<void> _loadMessages() async {
    setState(() {
      _messages.addAll(messageBox.values);
    });
    _scrollToBottom();
  }

  Future<void> _loadFrequentQuestions() async {
    setState(() {
      _frequentQuestions = _frequentQuestionService.getQuestionsByCategory(
        _selectedCategory,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _aiResponseSubscription?.cancel();
    messageBox.close();
    _locationHistoryManager.dispose();
    _frequentQuestionService.dispose();
    super.dispose();
  }

  void _cancelAiResponse() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('AI 응답 취소'),
          content: const Text('진행 중인 AI 응답을 취소하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                _aiResponseSubscription?.cancel();
                setState(() {
                  _isAiResponding = false;
                  // '...' 메시지 제거 (Hive에서도 제거 필요)
                  if (_messages.isNotEmpty) {
                    messageBox.deleteAt(
                      _messages.length - 1,
                    ); // Hive에서 마지막 메시지 제거
                    _messages.removeLast(); // 리스트에서 제거
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AI 응답이 취소되었습니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('예'),
            ),
          ],
        );
      },
    );
  }

  void _resetConversation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('대화 초기화'),
          content: const Text('이전 대화 내용과 위치 히스토리가 모두 삭제됩니다. 계속하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _messages.clear();
                  messageBox.clear();
                  _locationHistoryManager.clear();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('대화 내용이 초기화되었습니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('초기화'),
            ),
          ],
        );
      },
    );
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final userMessageText = _messageController.text;
    final userMessage = Message(role: 'user', content: userMessageText);

    setState(() {
      _messages.add(userMessage);
      messageBox.add(userMessage);
      _isAiResponding = true;
    });

    _messageController.clear();
    _scrollToBottom();

    final aiWaitingMessage = Message(role: 'assistant', content: '');
    setState(() {
      _messages.add(aiWaitingMessage);
      messageBox.add(aiWaitingMessage);
    });

    // AI 응답 처리
    _currentAiResponse = '';
    _aiResponseSubscription?.cancel();

    try {
      String locationContext = '';

      if (LocationUtils.needsLocation(userMessageText)) {
        if (LocationUtils.isCurrentLocationQuestion(userMessageText)) {
          // 현재 위치 관련 질문인 경우 현재 위치 가져오기
          final hasPermission = await PermissionUtils.checkAndRequestPermission(
            context,
          );
          if (!hasPermission) {
            setState(() {
              _isAiResponding = false;
              _messages.last = Message(
                role: 'assistant',
                content: '위치 권한이 허용되지 않아 위치 정보를 가져올 수 없습니다.',
              );
              messageBox.putAt(messageBox.length - 1, _messages.last);
            });
            return;
          }

          final currentLocation = await LocationUtils.getCurrentLocation();
          if (currentLocation != null) {
            _locationHistoryManager.addLocationHistory(currentLocation);
          }
        }
        // 위치 컨텍스트 생성 (현재 위치 또는 과거 위치 히스토리)
        locationContext = LocationUtils.getLocationContext(
          userMessageText,
          _locationHistoryManager.locationHistory,
        );
      }

      _aiResponseSubscription =
          AIServices.getAIResponseStream(
            '$locationContext\n$userMessageText',
            _messages,
          ).listen(
            (chunk) {
              setState(() {
                _currentAiResponse += chunk;
                _messages.last = Message(
                  role: 'assistant',
                  content: _currentAiResponse,
                );
                messageBox.putAt(messageBox.length - 1, _messages.last);
              });
              _scrollToBottom();
            },
            onDone: () {
              setState(() {
                _isAiResponding = false;
              });
            },
            onError: (error) {
              print('AI 응답 오류: $error');
              setState(() {
                _isAiResponding = false;
                _messages.last = Message(
                  role: 'assistant',
                  content: '죄송합니다. 응답을 생성하는 중에 오류가 발생했습니다.',
                );
                messageBox.putAt(messageBox.length - 1, _messages.last);
              });
            },
          );
    } catch (e) {
      print('메시지 전송 오류: $e');
      setState(() {
        _isAiResponding = false;
        _messages.last = Message(
          role: 'assistant',
          content: '죄송합니다. 메시지를 처리하는 중에 오류가 발생했습니다.',
        );
        messageBox.putAt(messageBox.length - 1, _messages.last);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showFrequentQuestions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '자주 하는 질문',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          items: const [
                            DropdownMenuItem(value: '위치', child: Text('위치')),
                          ],
                          onChanged: (String? value) {
                            if (value != null) {
                              setModalState(() {
                                _selectedCategory = value;
                                _frequentQuestions = _frequentQuestionService
                                    .getQuestionsByCategory(value);
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddQuestionDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _frequentQuestions.length,
                      itemBuilder: (context, index) {
                        final question = _frequentQuestions[index];
                        return ListTile(
                          title: Text(question.question),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditQuestionDialog(
                                  context,
                                  index,
                                  question,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    _showDeleteQuestionDialog(context, index),
                              ),
                            ],
                          ),
                          onTap: () {
                            _messageController.text = question.question;
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddQuestionDialog(BuildContext context) {
    final TextEditingController questionController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('질문 추가'),
          content: TextField(
            controller: questionController,
            decoration: const InputDecoration(hintText: '질문을 입력하세요'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (questionController.text.isNotEmpty) {
                  await _frequentQuestionService.addQuestion(
                    questionController.text,
                    _selectedCategory,
                  );
                  _loadFrequentQuestions();
                  Navigator.pop(context);
                }
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  void _showEditQuestionDialog(
    BuildContext context,
    int index,
    FrequentQuestion question,
  ) {
    final TextEditingController questionController = TextEditingController(
      text: question.question,
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('질문 수정'),
          content: TextField(
            controller: questionController,
            decoration: const InputDecoration(hintText: '질문을 입력하세요'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (questionController.text.isNotEmpty) {
                  await _frequentQuestionService.updateQuestion(
                    index,
                    questionController.text,
                    _selectedCategory,
                  );
                  _loadFrequentQuestions();
                  Navigator.pop(context);
                }
              },
              child: const Text('수정'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteQuestionDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('질문 삭제'),
          content: const Text('이 질문을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                await _frequentQuestionService.deleteQuestion(index);
                _loadFrequentQuestions();
                Navigator.pop(context);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '설정',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('대화 내용 초기화'),
                onTap: () {
                  Navigator.pop(context);
                  _resetConversation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('현재 위치 확인'),
                onTap: () async {
                  final hasPermission =
                      await PermissionUtils.checkAndRequestPermission(context);
                  if (!hasPermission) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('위치 권한이 허용되지 않아 위치 정보를 가져올 수 없습니다.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  await LocationUtils.getCurrentLocation();
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('위치 히스토리 확인'),
                onTap: () {
                  final history = _locationHistoryManager.locationHistory;
                  if (history.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('저장된 위치 히스토리가 없습니다.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      // Navigator.pop(context);
                    }
                    return;
                  }

                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('위치 히스토리'),
                          content: SizedBox(
                            width: double.maxFinite,
                            height: 300, // 적절한 높이 설정
                            child: ListView.builder(
                              itemCount: history.length,
                              itemBuilder: (context, index) {
                                final location = history[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    location.place?['name'] ??
                                        location.location?['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(location.formattedTime),
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext detailContext) {
                                        return AlertDialog(
                                          title: const Text('상세 정보'),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (location.place != null) ...[
                                                  const Text(
                                                    '장소 정보:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    const JsonEncoder.withIndent(
                                                      '  ',
                                                    ).convert(location.place),
                                                  ),
                                                  const SizedBox(height: 16),
                                                ],
                                                if (location.location !=
                                                    null) ...[
                                                  const Text(
                                                    '위치 정보:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    const JsonEncoder.withIndent(
                                                      '  ',
                                                    ).convert(
                                                      location.location,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                ],
                                                const Text(
                                                  '시간:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(location.formattedTime),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(detailContext),
                                              child: const Text('닫기'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('닫기'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.question_answer),
                title: const Text('자주 하는 질문'),
                onTap: () {
                  Navigator.pop(context);
                  _showFrequentQuestions();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == 'user';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isUser
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSecondary,
                          ),
                        ),
                        if (!isUser &&
                            _isAiResponding &&
                            message == _messages.last)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.onSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showSettings,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(25.0),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.5),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_isAiResponding ? Icons.close : Icons.send),
                  onPressed: _isAiResponding ? _cancelAiResponse : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
