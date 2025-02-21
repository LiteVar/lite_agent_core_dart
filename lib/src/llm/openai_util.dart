import 'dart:async';

import 'package:dart_openai/dart_openai.dart';
import 'model.dart';

class OpenAIUtil {
  late LLMConfig llmConfig;

  OpenAIUtil(this.llmConfig) {
    OpenAI.baseUrl = llmConfig.baseUrl;
    OpenAI.apiKey = llmConfig.apiKey;
  }

  static Future<bool> checkLLMConfig(String baseUrl, String apiKey) async {
    try {
      OpenAI.baseUrl = baseUrl;
      OpenAI.apiKey = apiKey;
      List<OpenAIModelModel> modelList = await OpenAI.instance.model.list();
      /// Remove model list check
      // OpenAIModelModel openAIModelModel = modelList.firstWhere((openAIModelModel) => openAIModelModel.id == llmConfig.model);
      return true;
    } catch(e) {
      print(e);
      return false;
    }
  }

  Future<ChatCompletion> chat({required List<OpenAIChatCompletionChoiceMessageModel> messageList, List<OpenAIToolModel>? toolList, ResponseFormat? responseFormat}) async {
      OpenAIChatCompletionModel chatCompletion = await OpenAI.instance.chat.create(
          model: llmConfig.model,
          responseFormat: responseFormat == null ? ResponseFormat(type: ResponseFormatType.TEXT).toJson() : responseFormat.toJson(),
          seed: 6,
          messages: messageList,
          tools: toolList,
          temperature: llmConfig.temperature,
          maxTokens: llmConfig.maxTokens,
          topP: llmConfig.topP,
      );

      TokenUsage tokenUsage = TokenUsage(
          promptTokens: chatCompletion.usage.promptTokens,
          completionTokens: chatCompletion.usage.completionTokens,
          totalTokens: chatCompletion.usage.totalTokens
      );

      Completions completions = Completions(tokenUsage: tokenUsage, id: chatCompletion.id, model: llmConfig.model);

      return ChatCompletion(message: chatCompletion.choices.first.message, completions: completions);
  }

  Future<Stream<ChatCompletionDelta>> chatByStream({required List<OpenAIChatCompletionChoiceMessageModel> messageList, List<OpenAIToolModel>? toolList, ResponseFormat? responseFormat}) async {
    Stream<OpenAIStreamChatCompletionModel> chatCompletionStream = await OpenAI.instance.chat.createStream(
      model: llmConfig.model,
      responseFormat: responseFormat == null ? ResponseFormat(type: ResponseFormatType.TEXT).toJson() : responseFormat.toJson(),
      seed: 6,
      messages: messageList,
      tools: toolList,
      temperature: llmConfig.temperature,
      maxTokens: llmConfig.maxTokens,
      topP: llmConfig.topP,
    );

    return chatCompletionStream
      .where((streamCompletion) => streamCompletion.choices.first.delta.content != null)
      .map((streamCompletion) {
        Completions? completions = null;
        /// Waiting for the completion usage to be supported
        // if(streamCompletion.usage != null) {
        //   TokenUsage tokenUsage = TokenUsage(
        //       promptTokens: streamCompletion.usage.promptTokens,
        //       completionTokens: streamCompletion.usage.completionTokens,
        //       totalTokens: streamCompletion.usage.totalTokens
        //   );
        //   completions = Completions(tokenUsage: tokenUsage, id: streamCompletion.id, model: llmConfig.model);
        // }
        return ChatCompletionDelta(delta: streamCompletion.choices.first.delta, completions: completions);
    });

  }

}