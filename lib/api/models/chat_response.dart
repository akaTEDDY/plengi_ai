import 'package:json_annotation/json_annotation.dart';

part 'chat_response.g.dart';

@JsonSerializable()
class ChatResponse {
  final String id;
  final String type;
  final String role;
  final List<Content> content;

  ChatResponse({
    required this.id,
    required this.type,
    required this.role,
    required this.content,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) =>
      _$ChatResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ChatResponseToJson(this);
}

@JsonSerializable()
class Content {
  final String type;
  final String text;

  Content({
    required this.type,
    required this.text,
  });

  factory Content.fromJson(Map<String, dynamic> json) =>
      _$ContentFromJson(json);
  Map<String, dynamic> toJson() => _$ContentToJson(this);
}
