import 'package:dart_openai/dart_openai.dart';
import 'model.dart';

class OpenAIUtil {
  late LLMConfig llmConfig;

  OpenAIUtil(this.llmConfig) {
    OpenAI.baseUrl = llmConfig.baseUrl;
    OpenAI.apiKey = llmConfig.apiKey;
  }

  Future<SimpleCompletion> chat({required List<OpenAIChatCompletionChoiceMessageModel> messageList, List<OpenAIToolModel>? toolList, ResponseFormat? responseFormat}) async {

    OpenAIChatCompletionModel chatCompletion = await OpenAI.instance.chat.create(
      model: llmConfig.model,
      responseFormat: responseFormat==null?ResponseFormat(type: ResponseFormatType.TEXT).toJson(): responseFormat.toJson(),
      seed: 6,
      messages: messageList,
      tools: toolList,
      temperature: llmConfig.temperature,
      maxTokens: llmConfig.maxTokens,
      topP: llmConfig.topP
    );

    TokenUsage tokenUsage = TokenUsage(
      promptTokens: chatCompletion.usage.promptTokens,
      completionTokens: chatCompletion.usage.completionTokens,
      totalTokens: chatCompletion.usage.totalTokens
    );

    Completions completions = Completions(tokenUsage: tokenUsage, id: chatCompletion.id, model: llmConfig.model);

    return SimpleCompletion(message: chatCompletion.choices.first.message, completions: completions);
  }

}