import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:plengi_ai/models/message.dart';

class AIServices {
  static const String _baseUrl = 'https://api.anthropic.com/v1';
  static String? _apiKey;

  static Future<void> initialize() async {
    if (!kIsWeb) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        print('Error loading .env file: $e');
      }
    }
    _apiKey = kIsWeb
        ? const String.fromEnvironment('ANTHROPIC_API_KEY')
        : dotenv.env['ANTHROPIC_API_KEY'];
  }

  // 마지막 유효한 assistant 메시지의 인덱스를 찾는 헬퍼 메서드
  static int findLastValidAssistantIndex(List<Message> messageHistory) {
    for (int i = messageHistory.length - 1; i >= 0; i--) {
      final message = messageHistory[i];
      if (message.role == 'assistant' && message.content.isNotEmpty) {
        return i;
      }
    }
    return -1; // 유효한 assistant 메시지를 찾지 못한 경우
  }

  static List<Message> flilterValidMessage(List<Message> messageHistory) {
    final List<Message> validMessages = [];
    final int totalMessages = messageHistory.length;

    // 마지막 더미 세트를 제외한 메시지들만 처리
    final int processLength = totalMessages - 2; // 마지막 2개(더미 세트) 제외

    for (int i = 0; i < processLength; i++) {
      final currentMessage = messageHistory[i];
      final String role = currentMessage.role;

      // 시작은 user부터여야 함
      if (i == 0 && role == 'assistant') {
        continue;
      }

      if (role == 'user') {
        // 다음 메시지가 있는지 확인
        if (i + 1 < processLength) {
          final nextMessage = messageHistory[i + 1];
          final String nextRole = nextMessage.role;
          final String nextContent = nextMessage.content;

          // assistant 메시지가 있고 내용이 비어있지 않은 경우만 유효한 세트로 간주
          if (nextRole == 'assistant' && nextContent.isNotEmpty) {
            validMessages.add(currentMessage);
            validMessages.add(nextMessage);
            i++; // assistant 메시지를 처리했으므로 다음 인덱스로 건너뜀
          }
          // assistant가 없거나 내용이 비어있으면 user 메시지도 제외
        }
        // 마지막 user 메시지인 경우 제외
      }
      // assistant 메시지는 user와 짝이 맞는 경우만 위에서 처리됨
    }

    return validMessages;
  }

  static Future<String> getAIResponse(
    String userMessage,
    List<Message> messageHistory,
  ) async {
    if (_apiKey == null) {
      await initialize();
    }

    // API 키가 여전히 null인 경우 에러 처리
    if (_apiKey == null) {
      return 'API key is not initialized';
    }

    // 유효한 메시지 중 필요한 메시지만 필터링
    final recentMessages = flilterValidMessage(messageHistory);

    // 기존 동기 응답 메서드
    final response = await http.post(
      Uri.parse('$_baseUrl/messages'),
      headers: {
        'x-api-key': _apiKey!,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
        'anthropic-beta': 'mcp-client-2025-04-04',
      },
      body: jsonEncode({
        'model': 'claude-opus-4-20250514',
        'max_tokens': 1024,
        'messages': [
          ...recentMessages,
          {'role': 'user', 'content': userMessage},
        ],
        // 'mcp_servers': [
        //   {
        //     'type': 'url',
        //     'url': 'https://107b-175-116-24-228.ngrok-free.app/sse',
        //     'name': 'restaurants_finder',
        //   },
        // ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['content'] as List;
      return content.isNotEmpty
          ? content.last['text'] ?? '응답이 없습니다.'
          : '응답이 없습니다.';
    } else {
      return 'API 호출 실패: ${response.statusCode}';
    }
  }

  static Stream<String> getAIResponseStream(
    String userMessage,
    List<Message> messageHistory,
  ) async* {
    if (_apiKey == null) {
      await initialize();
    }

    // API 키가 여전히 null인 경우 에러 처리
    if (_apiKey == null) {
      yield 'API key is not initialized';
    }

    try {
      // 유효한 메시지 중 필요한 메시지만 필터링
      final recentMessages = flilterValidMessage(messageHistory);

      final request = http.Request('POST', Uri.parse('$_baseUrl/messages'));

      request.headers.addAll({
        'x-api-key': _apiKey!,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
        'anthropic-beta': 'mcp-client-2025-04-04',
      });

      request.body = jsonEncode({
        'model': 'claude-opus-4-20250514',
        'max_tokens': 1024,
        'messages': [
          ...recentMessages,
          {'role': 'user', 'content': userMessage},
        ],
        'stream': true,
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          // 각 청크를 개별 이벤트로 분리
          final events = chunk.split('\n');
          for (final event in events) {
            if (event.startsWith('event: ')) {
              final eventType = event.substring(7);
              if (eventType == 'content_block_delta') {
                // 다음 라인에서 data를 읽기
                final dataLine = events[events.indexOf(event) + 1];
                if (dataLine.startsWith('data: ')) {
                  try {
                    final json = jsonDecode(dataLine.substring(6));
                    if (json['delta'] != null &&
                        json['delta']['type'] == 'text_delta' &&
                        json['delta']['text'] != null) {
                      final text = json['delta']['text'];
                      if (text.isNotEmpty) {
                        yield text;
                      }
                    }
                  } catch (e) {
                    print('Error parsing chunk: $e');
                  }
                }
              }
            }
          }
        }
      } else {
        yield 'API 호출 실패: ${response.statusCode}';
      }
    } catch (e) {
      print('AI 응답 스트림 오류: $e');
      rethrow;
    }
  }
}
