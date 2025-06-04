import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static Future<String> getAIResponse(String userMessage) async {
    // 기존 동기 응답 메서드
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': dotenv.env['ANTHROPIC_API_KEY'] ?? '',
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
        'anthropic-beta': 'mcp-client-2025-04-04',
      },
      body: jsonEncode({
        'model': 'claude-3-opus-20240229',
        'max_tokens': 1024,
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
        'mcp_servers': [
          {
            'type': 'url',
            'url': 'https://9287-175-116-24-228.ngrok-free.app/sse',
            'name': 'restaurants_finder',
          },
        ],
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

  static Stream<String> getAIResponseStream(String userMessage) async* {
    final request = http.Request(
      'POST',
      Uri.parse('https://api.anthropic.com/v1/messages'),
    );

    request.headers.addAll({
      'x-api-key': dotenv.env['ANTHROPIC_API_KEY'] ?? '',
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    });

    request.body = jsonEncode({
      'model': 'claude-3-5-haiku-20241022',
      'max_tokens': 1024,
      'messages': [
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
          if (event.startsWith('data: ')) {
            final data = event.substring(6);
            if (data == '[DONE]') continue;

            try {
              final json = jsonDecode(data);
              final content = json['content'][0]['text'] ?? '';
              if (content.isNotEmpty) {
                yield content;
              }
            } catch (e) {
              print('Error parsing chunk: $e');
            }
          }
        }
      }
    } else {
      yield 'API 호출 실패: ${response.statusCode}';
    }
  }
}
