import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:plengi_ai/api/models/chat_request.dart';
import 'package:plengi_ai/api/models/chat_response.dart';

part 'api_client.g.dart';

@RestApi(baseUrl: "https://api.anthropic.com/v1/")
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  @POST("messages")
  Future<ChatResponse> sendMessage(
    @Header("x-api-key") String apiKey,
    @Body() ChatRequest request,
  );
}
