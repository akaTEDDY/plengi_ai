import 'package:hive/hive.dart';
import 'package:plengi_ai/models/frequent_question.dart';

class FrequentQuestionService {
  late Box<FrequentQuestion> _questionBox;
  static const String _boxName = 'frequentQuestions';

  Future<void> initialize() async {
    _questionBox = await Hive.openBox<FrequentQuestion>(_boxName);

    // 초기 데이터가 없으면 기본 질문들 추가
    if (_questionBox.isEmpty) {
      await _addDefaultQuestions();
    }
  }

  Future<void> _addDefaultQuestions() async {
    final defaultQuestions = [
      FrequentQuestion(question: '내 위치 어디야?', category: '위치'),
      FrequentQuestion(question: '내가 있었던 곳 알려줘', category: '위치'),
      FrequentQuestion(question: '지금 어디야?', category: '위치'),
      FrequentQuestion(question: '여기 어디야?', category: '위치'),
    ];

    for (var question in defaultQuestions) {
      await _questionBox.add(question);
    }
  }

  List<FrequentQuestion> getQuestions() {
    return _questionBox.values.toList();
  }

  List<FrequentQuestion> getQuestionsByCategory(String category) {
    return _questionBox.values
        .where((question) => question.category == category)
        .toList();
  }

  Future<void> addQuestion(String question, String category) async {
    await _questionBox.add(
      FrequentQuestion(question: question, category: category),
    );
  }

  Future<void> updateQuestion(
    int index,
    String question,
    String category,
  ) async {
    await _questionBox.putAt(
      index,
      FrequentQuestion(question: question, category: category),
    );
  }

  Future<void> deleteQuestion(int index) async {
    await _questionBox.deleteAt(index);
  }

  void dispose() {
    _questionBox.close();
  }
}
