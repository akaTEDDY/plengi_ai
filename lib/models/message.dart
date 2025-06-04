import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class Message extends HiveObject {
  @HiveField(0)
  @JsonKey(name: 'role')
  final String role;

  @HiveField(1)
  @JsonKey(name: 'content')
  final String content;

  Message({required this.role, required this.content});

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
