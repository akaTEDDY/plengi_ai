import 'package:json_annotation/json_annotation.dart';

part 'chat_request.g.dart';

@JsonSerializable()
class ChatRequest {
  @JsonKey(name: 'model')
  final String model;

  @JsonKey(name: 'messages')
  final List<Message> messages;

  @JsonKey(name: 'max_tokens')
  final int maxTokens;

  ChatRequest({
    required this.model,
    required this.messages,
    this.maxTokens = 1000,
  });

  factory ChatRequest.fromJson(Map<String, dynamic> json) =>
      _$ChatRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ChatRequestToJson(this);
}

@JsonSerializable()
class Message {
  final String role;
  final String content;

  Message({required this.role, required this.content});

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
