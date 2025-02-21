import 'package:dart_openai/dart_openai.dart';

class LLMConfig {
  String baseUrl;
  String apiKey;
  String model;
  double temperature;
  int maxTokens;
  double topP;
  LLMConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.temperature = 0.0,
    this.maxTokens = 4096,
    this.topP = 1.0
  });
}

class Completions {
  TokenUsage tokenUsage;
  String id;
  String model;

  Completions({required this.tokenUsage, required this.id, required this.model});
}

class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens
  });
}

class ChatCompletion {
  OpenAIChatCompletionChoiceMessageModel message;

  Completions completions;

  ChatCompletion({required this.message, required this.completions});
}

class ChatCompletionDelta {
  OpenAIStreamChatCompletionChoiceDeltaModel delta;

  Completions? completions;

  ChatCompletionDelta({required this.delta, this.completions});
}

class ResponseFormatType {
  static String TEXT = "text";
  static String JSON_OBJECT = "json_object";
}

class ResponseFormat {
  String type;

  ResponseFormat({required this.type});

  Map<String, String> toJson() {
    return {
      "type": type
    };
  }
}