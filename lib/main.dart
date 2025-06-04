import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:plengi_ai/services/ai_services.dart';
import 'package:plengi_ai/services/location_service.dart';
import 'package:plengi_ai/services/permission_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:plengi_ai/models/message.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(MessageAdapter());

  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print('Error loading .env file: $e');
    }
  }

  // 웹 환경에서는 환경 변수를 직접 설정
  if (kIsWeb) {
    dotenv.env['ANTHROPIC_API_KEY'] = const String.fromEnvironment(
      'ANTHROPIC_API_KEY',
    );
  }

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
  final List<Message> _messages = [];
  final LocationService _locationService = LocationService();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _aiResponseSubscription;
  String _currentAiResponse = '';
  bool _isAiResponding = false;

  // Hive Box 변수 추가
  late Box<Message> messageBox;

  @override
  void initState() {
    super.initState();
    _openMessageBox(); // Hive Box 열기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestLocationPermission();
    });
  }

  // Hive Box를 열고 기존 메시지를 불러오는 함수
  Future<void> _openMessageBox() async {
    messageBox = await Hive.openBox<Message>('messages');
    // 저장된 메시지 불러오기
    setState(() {
      _messages.addAll(messageBox.values);
    });
    _scrollToBottom();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    // print('권한 체크 시작'); // 디버깅 로그 주석 처리
    final hasPermission = await _locationService.checkLocationPermission();
    // print('권한 체크 결과: $hasPermission'); // 디버깅 로그 주석 처리

    if (!hasPermission) {
      // print('권한이 없어서 다이얼로그 표시'); // 디버깅 로그 주석 처리
      await _showLocationPermissionDialog();
    } else {
      // print('이미 권한이 있음'); // 디버깅 로그 주석 처리
    }
  }

  Future<void> _showLocationPermissionDialog() async {
    // print('권한 요청 다이얼로그 표시'); // 디버깅 로그 주석 처리
    final result = await PermissionService.showPermissionDialog(context);
    // print('권한 요청 다이얼로그 결과: $result'); // 디버깅 로그 주석 처리

    if (result) {
      // '예'를 선택했을 경우
      // print('권한 요청 시작'); // 디버깅 로그 주석 처리
      final granted = await _requestLocationPermission();
      // print('권한 요청 결과: $granted'); // 디버깅 로그 주석 처리

      if (!granted) {
        // print('권한이 최종 거부되어 설정으로 이동하는 옵션 제공'); // 디버깅 로그 주석 처리
        // 권한 요청 결과 false일 때만 설정 이동 옵션을 제공
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('권한 필요'),
            content: const Text('이 기능을 사용하려면 위치 권한이 필요합니다. 설정에서 권한을 허용하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('아니오'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await _openAppSettings();
        }
      } else {
        // print('권한 요청 성공'); // 디버깅 로그 주석 처리
      }
    } else {
      // 다이얼로그에서 '다음에 하기'를 선택하고 result가 false인 경우 (새로운 디자인)
      // print('다이얼로그에서 다음에 하기를 선택함'); // 디버깅 로그 주석 처리
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('위치 권한이 허용되지 않아 일부 기능 사용이 제한될 수 있습니다.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openAppSettings() async {
    // print('앱 설정으로 이동'); // 디버깅 로그 주석 처리
    // TODO: 앱 설정으로 이동하는 로직 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('설정에서 권한을 허용해주세요.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _requestLocationPermission() async {
    // print('위치 권한 요청 시작'); // 디버깅 로그 주석 처리
    final result = await _locationService.requestLocationPermission();
    // print('위치 권한 요청 결과: $result'); // 디버깅 로그 주석 처리
    return result;
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

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final userMessageText = _messageController.text;
    final userMessage = Message(
      role: 'user',
      content: userMessageText,
    ); // Message 모델 사용

    setState(() {
      _messages.add(userMessage); // 리스트에 추가
      messageBox.add(userMessage); // Hive Box에 저장
      _isAiResponding = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // AI 응답 대기 메시지 추가
    final aiWaitingMessage = Message(
      role: 'ai',
      content: '...',
    ); // Message 모델 사용
    setState(() {
      _messages.add(aiWaitingMessage); // 리스트에 추가
      messageBox.add(aiWaitingMessage); // Hive Box에 저장
    });

    // AI 응답 처리
    _currentAiResponse = '';
    _aiResponseSubscription?.cancel();

    try {
      final response = await AIService.getAIResponse(userMessageText);
      setState(() {
        if (_messages.isNotEmpty) {
          final lastMessageIndex = _messages.length - 1;
          final updatedMessage = Message(
            role: _messages[lastMessageIndex].role,
            content: response,
          );
          _messages[lastMessageIndex] = updatedMessage;
          messageBox.putAt(lastMessageIndex, updatedMessage);
        }
        _isAiResponding = false;
      });
    } catch (error) {
      setState(() {
        if (_messages.isNotEmpty) {
          final lastMessageIndex = _messages.length - 1;
          final updatedMessage = Message(
            role: _messages[lastMessageIndex].role,
            content: '오류가 발생했습니다: $error',
          );
          _messages[lastMessageIndex] = updatedMessage;
          messageBox.putAt(lastMessageIndex, updatedMessage);
        }
        _isAiResponding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $error'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index]; // Message 모델 사용
                final isUser = message.role == 'user'; // Message 모델 속성 사용

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
                    child: Text(
                      message.content, // Message 모델 속성 사용
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
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
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: _isAiResponding ? _cancelAiResponse : _sendMessage,
                  backgroundColor: _isAiResponding
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  child: Icon(_isAiResponding ? Icons.close : Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _aiResponseSubscription?.cancel();
    messageBox.close(); // Hive Box 닫기
    super.dispose();
  }
}
