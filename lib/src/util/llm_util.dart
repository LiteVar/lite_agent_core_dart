import 'dart:convert';

import 'package:dart_openai/dart_openai.dart';
import 'package:lite_agent_core/lite_agent_core.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../model.dart';

class LLMRunner {
  late String _model;

  LLMRunner(String baseUrl, String apiKey, String model) {
    OpenAI.baseUrl = baseUrl;
    OpenAI.apiKey = apiKey;
    _model = model;
  }

  Future<AgentMessage> requestLLM({required List<AgentMessage> agentMessageList, List<FunctionModel>? functionModelList }) async {

    List<OpenAIChatCompletionChoiceMessageModel> requestMessageList = agentMessageList.map((AgentMessage agentMessage) => _buildOpenAIMessage(agentMessage)).toList();
    List<OpenAIToolModel>? tools = functionModelList?.map((FunctionModel functionModel) => _buildOpenAIToolModel(functionModel)).toList();

    OpenAIChatCompletionModel chatCompletion = await OpenAI.instance.chat.create(
      model: _model,
      responseFormat: {"type": "text"},
      seed: 6,
      messages: requestMessageList,
      tools: tools,
      temperature: 0,
      maxTokens: 4096,
    );

    AgentMessage agentMessage = _toAgentMessage(chatCompletion.choices.first.message, tokenUsage: chatCompletion.usage.totalTokens);

    return agentMessage;
  }

  OpenAIToolModel _buildOpenAIToolModel(FunctionModel functionModel) {
    List<OpenAIFunctionProperty> openAIFunctionPropertyList = [];
    functionModel.parameters.properties.forEach((String name, Property property) {
      switch(property.type) {
        case OpenAIFunctionProperty.functionTypeBoolean: openAIFunctionPropertyList.add(OpenAIFunctionProperty.boolean(name: name, description: property.description, isRequired: property.required));
        case OpenAIFunctionProperty.functionTypeInteger: openAIFunctionPropertyList.add(OpenAIFunctionProperty.integer(name: name, description: property.description, isRequired: property.required));
        case OpenAIFunctionProperty.functionTypeNumber: openAIFunctionPropertyList.add(OpenAIFunctionProperty.number(name: name, description: property.description, isRequired: property.required));
        case OpenAIFunctionProperty.functionTypeString: openAIFunctionPropertyList.add(OpenAIFunctionProperty.string(name: name, description: property.description, isRequired: property.required, enumValues: property.enum_));
      }
    });
    OpenAIFunctionModel openAIFunctionModel = OpenAIFunctionModel.withParameters(name: functionModel.name, parameters: openAIFunctionPropertyList);
    OpenAIToolModel openAIToolModel = OpenAIToolModel(type: "function", function: openAIFunctionModel);
    return openAIToolModel;
  }

  OpenAIChatCompletionChoiceMessageModel _buildOpenAIMessage(AgentMessage agentMessage) {

    //系统预置文字
    if(agentMessage.from == AgentRole.SYSTEM && agentMessage.type == AgentMessageType.TEXT) {
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.system,
        content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)]
      );
    }

    //大模型返回的纯文本
    if(agentMessage.from == AgentRole.LLM && agentMessage.type == AgentMessageType.TEXT) {
      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)]
      );
    }

    //大模型返回的图片
    if(agentMessage.from == AgentRole.LLM && agentMessage.type == AgentMessageType.IMAGE_URL) {
      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(agentMessage.message as String)]
      );
    }

    //大模型返回的函数调用
    if(agentMessage.from == AgentRole.LLM && agentMessage.type == AgentMessageType.FUNCTION_CALL_LIST) {
      List<FunctionCall> functionCallList = agentMessage.message as List<FunctionCall>;
      List<OpenAIResponseToolCall> openAIResponseToolCallList = functionCallList.map((FunctionCall functionCall) {
        return _toOpenAIResponseToolCall(functionCall);
      }).toList();

      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: null,
          toolCalls: openAIResponseToolCallList
      );
    }

    //Agent转发工具返回的调用结果
    if(agentMessage.from == AgentRole.AGENT && agentMessage.type == AgentMessageType.TOOL_RETURN) {
      ToolReturn toolReturn = agentMessage.message as ToolReturn;
      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.tool,
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(jsonEncode(toolReturn.result))],
      ).asRequestFunctionMessage(toolCallId: toolReturn.id);
    }

    //Agent文本大模型，fromAgent toLLM
    return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)]
    );

  }

  OpenAIResponseToolCall _toOpenAIResponseToolCall(FunctionCall functionCall) {
    return OpenAIResponseToolCall.fromMap({
      "id": functionCall.id,
      "type": "function",
      "function": {
        "name": functionCall.name,
        "arguments":jsonEncode(functionCall.parameters)
      }
    });

  }

  AgentMessage _toAgentMessage(OpenAIChatCompletionChoiceMessageModel openAIChatCompletionChoiceMessageModel, {int tokenUsage = 0}) {

    dynamic message;

    message = openAIChatCompletionChoiceMessageModel.toolCalls?.map((OpenAIResponseToolCall openAIResponseToolCall) {
      String id = openAIResponseToolCall.id!;
      String name = openAIResponseToolCall.function.name!;
      Map<String, dynamic> parameters = jsonDecode(openAIResponseToolCall.function.arguments);
      return FunctionCall(id: id, name: name, parameters: parameters);
    }).toList();
    if(message!= null) {
      return AgentMessage(from: AgentRole.LLM, to:AgentRole.AGENT, type: AgentMessageType.FUNCTION_CALL_LIST, message: message, tokenUsage: tokenUsage);
    }

    message = openAIChatCompletionChoiceMessageModel.content?.first.text;
    return AgentMessage(from: AgentRole.LLM, to:AgentRole.AGENT, type: AgentMessageType.TEXT, message: message, tokenUsage: tokenUsage);
  }
}
