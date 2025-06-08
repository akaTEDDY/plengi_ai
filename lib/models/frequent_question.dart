import 'package:hive/hive.dart';

part 'frequent_question.g.dart';

@HiveType(typeId: 2)
class FrequentQuestion {
  @HiveField(0)
  final String question;

  @HiveField(1)
  final String category;

  FrequentQuestion({required this.question, required this.category});
}
