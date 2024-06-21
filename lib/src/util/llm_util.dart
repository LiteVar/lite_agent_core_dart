import 'dart:convert';

import 'package:dart_openai/dart_openai.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../model.dart';

class LLMRunner {
  late LLMConfig llmConfig;

  LLMRunner(this.llmConfig) {
    OpenAI.baseUrl = llmConfig.baseUrl;
    OpenAI.apiKey = llmConfig.apiKey;
  }

  Future<AgentMessage> requestLLM({required List<AgentMessage> agentMessageList, List<FunctionModel>? functionModelList }) async {

    List<OpenAIChatCompletionChoiceMessageModel> requestMessageList = agentMessageList.map((AgentMessage agentMessage) => _buildOpenAIMessage(agentMessage)).toList();
    List<OpenAIToolModel>? tools = functionModelList?.map((FunctionModel functionModel) => _buildOpenAIToolModel(functionModel)).toList();

    OpenAIChatCompletionModel chatCompletion = await OpenAI.instance.chat.create(
      model: llmConfig.model,
      responseFormat: {"type": "text"},
      seed: 6,
      messages: requestMessageList,
      tools: tools,
      temperature: llmConfig.temperature,
      maxTokens: llmConfig.maxTokens,
      topP: llmConfig.topP
    );


    TokenUsage tokenUsage = TokenUsage(promptTokens: chatCompletion.usage.promptTokens, completionTokens: chatCompletion.usage.completionTokens, totalTokens: chatCompletion.usage.totalTokens);

    Completions completions = Completions(tokenUsage: tokenUsage, id: chatCompletion.id, model: llmConfig.model);

    AgentMessage agentMessage = _toAgentMessage(chatCompletion.choices.first.message, completions: completions);

    return agentMessage;
  }

  OpenAIToolModel _buildOpenAIToolModel(FunctionModel functionModel) {
    List<OpenAIFunctionProperty> openAIFunctionPropertyList = [];
    functionModel.parameters.properties.forEach((String name, Property property) {
      openAIFunctionPropertyList.add(_convertToOpenAIFunctionProperty(name, property));
    });
    OpenAIFunctionModel openAIFunctionModel = OpenAIFunctionModel.withParameters(name: functionModel.name, description: functionModel.description, parameters: openAIFunctionPropertyList);
    OpenAIToolModel openAIToolModel = OpenAIToolModel(type: "function", function: openAIFunctionModel);
    return openAIToolModel;
  }



  OpenAIFunctionProperty _convertToOpenAIFunctionProperty(String name, Property property) {
    switch(property.type) {
      case PropertyType.boolean:return OpenAIFunctionProperty.boolean(name: name, description: property.description, isRequired: property.required);
      case PropertyType.integer: return OpenAIFunctionProperty.integer(name: name, description: property.description, isRequired: property.required);
      case PropertyType.number: return OpenAIFunctionProperty.number(name: name, description: property.description, isRequired: property.required);
      case PropertyType.string: return OpenAIFunctionProperty.string(name: name, description: property.description, isRequired: property.required, enumValues: property.enum_);
      case PropertyType.array: {
        OpenAIFunctionProperty openAIFunctionProperty = _convertToOpenAIFunctionProperty(name, property.items!);
        return OpenAIFunctionProperty.array(name: name, description: property.description, isRequired: property.required, items: openAIFunctionProperty);
      }
      case PropertyType.object: {
        Map<String, Property> properties = property.properties!;
        Map<String, OpenAIFunctionProperty> openAIFunctionProperties = {};
        properties.forEach((String name, Property property0) {
          OpenAIFunctionProperty openAIFunctionProperty = _convertToOpenAIFunctionProperty(name, property0);
          openAIFunctionProperties[name] = openAIFunctionProperty;
        });

        return OpenAIFunctionProperty.object(name: name, description: property.description, isRequired: property.required, properties: openAIFunctionProperties.values);
      }
    }
  }

  OpenAIChatCompletionChoiceMessageModel _buildOpenAIMessage(AgentMessage agentMessage) {

    //系统预置文字
    if(agentMessage.from == AgentRole.SYSTEM && agentMessage.type == AgentMessageType.text) {
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.system,
        content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)]
      );
    }

    //大模型返回的纯文本
    if(agentMessage.from == AgentRole.LLM && agentMessage.type == AgentMessageType.text) {
      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)]
      );
    }

    //大模型返回的图片
    if(agentMessage.from == AgentRole.LLM && agentMessage.type == AgentMessageType.imageUrl) {
      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(agentMessage.message as String)]
      );
    }

    //大模型返回的函数调用
    if(agentMessage.from == AgentRole.LLM && agentMessage.type == AgentMessageType.functionCallList) {
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
    if(agentMessage.from == AgentRole.AGENT && agentMessage.type == AgentMessageType.toolReturn) {
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

  AgentMessage _toAgentMessage(OpenAIChatCompletionChoiceMessageModel openAIChatCompletionChoiceMessageModel, {Completions? completions}) {

    dynamic message;

    message = openAIChatCompletionChoiceMessageModel.toolCalls?.map((OpenAIResponseToolCall openAIResponseToolCall) {
      String id = openAIResponseToolCall.id!;
      String name = openAIResponseToolCall.function.name!;
      Map<String, dynamic> parameters = jsonDecode(openAIResponseToolCall.function.arguments);
      return FunctionCall(id: id, name: name, parameters: parameters);
    }).toList();

    if(message!= null) {
      return AgentMessage(from: AgentRole.LLM, to:AgentRole.AGENT, type: AgentMessageType.functionCallList, message: message, completions: completions);
    }

    message = openAIChatCompletionChoiceMessageModel.content?.first.text;
    return AgentMessage(from: AgentRole.LLM, to:AgentRole.AGENT, type: AgentMessageType.text, message: message, completions: completions);
  }
}

