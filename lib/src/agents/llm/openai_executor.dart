import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import 'package:http/http.dart';
import 'package:lite_agent_core_dart/src/agents/llm/exception.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../../llm/openai_util.dart';
import '../../llm/model.dart';
import '../model.dart';
import 'llm_executor.dart';
import 'model.dart';

class OpenAIExecutor extends OpenAIUtil implements LLMExecutor {
  late String _taskId;

  OpenAIExecutor(super.llmConfig) {
    OpenAI.baseUrl = llmConfig.baseUrl;
    OpenAI.apiKey = llmConfig.apiKey;
  }

  Future<AgentMessage> request({required List<AgentMessage> agentMessageList, List<FunctionModel>? functionModelList}) async {
    _taskId = agentMessageList.lastWhere((agentMessage)=> agentMessage.from == AgentRoleType.AGENT).taskId;
    List<OpenAIChatCompletionChoiceMessageModel> requestMessageList = agentMessageList.map((AgentMessage agentMessage) => _buildOpenAIMessage(agentMessage)).toList();
    List<OpenAIToolModel>? tools = functionModelList?.map((FunctionModel functionModel) => _buildOpenAIToolModel(functionModel)).toList();

    try {
      SimpleCompletion chatCompletion = await super.chat(messageList: requestMessageList, toolList: tools);

      AgentMessage agentMessage = _toAgentMessage(
          chatCompletion.message,
          completions: chatCompletion.completions
      );

      return agentMessage;
    } on ClientException catch(e) {
      throw LLMException(code: 500, message: e.message);
    }
  }

  OpenAIToolModel _buildOpenAIToolModel(FunctionModel functionModel) {
    List<OpenAIFunctionProperty> openAIFunctionPropertyList = [];
    functionModel.parameters.properties.forEach((String name, Property property) {
      openAIFunctionPropertyList.add(_convertToOpenAIFunctionProperty(name, property));
    });
    OpenAIFunctionModel openAIFunctionModel =
    OpenAIFunctionModel.withParameters(
        name: functionModel.name,
        description: functionModel.description,
        parameters: openAIFunctionPropertyList
    );
    OpenAIToolModel openAIToolModel = OpenAIToolModel(type: "function", function: openAIFunctionModel);
    return openAIToolModel;
  }

  OpenAIFunctionProperty _convertToOpenAIFunctionProperty(String name, Property property) {
    switch (property.type) {
      case PropertyType.boolean:
        return OpenAIFunctionProperty.boolean(
            name: name,
            description: property.description,
            isRequired: property.required);
      case PropertyType.integer:
        return OpenAIFunctionProperty.integer(
            name: name,
            description: property.description,
            isRequired: property.required);
      case PropertyType.number:
        return OpenAIFunctionProperty.number(
            name: name,
            description: property.description,
            isRequired: property.required);
      case PropertyType.string:
        return OpenAIFunctionProperty.string(
            name: name,
            description: property.description,
            isRequired: property.required,
            enumValues: property.enum_);
      case PropertyType.array:
        {
          OpenAIFunctionProperty openAIFunctionProperty =
          _convertToOpenAIFunctionProperty(name, property.items!);
          return OpenAIFunctionProperty.array(
              name: name,
              description: property.description,
              isRequired: property.required,
              items: openAIFunctionProperty);
        }
      case PropertyType.object:
        {
          Map<String, Property> properties = property.properties!;
          Map<String, OpenAIFunctionProperty> openAIFunctionProperties = {};
          properties.forEach((String name, Property property0) {
            OpenAIFunctionProperty openAIFunctionProperty =
            _convertToOpenAIFunctionProperty(name, property0);
            openAIFunctionProperties[name] = openAIFunctionProperty;
          });

          return OpenAIFunctionProperty.object(
              name: name,
              description: property.description,
              isRequired: property.required,
              properties: openAIFunctionProperties.values);
        }
    }
  }

  OpenAIChatCompletionChoiceMessageModel _buildOpenAIMessage(AgentMessage agentMessage) {
    //System Prompt
    if (agentMessage.from == AgentRoleType.SYSTEM &&
        agentMessage.type == AgentMessageType.TEXT) {
      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                agentMessage.message as String)
          ]);
    }

    //LLM return text
    if (agentMessage.from == AgentRoleType.LLM &&
        agentMessage.type == AgentMessageType.TEXT) {
      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                agentMessage.message as String)
          ]);
    }

    //LLM return image
    if (agentMessage.from == AgentRoleType.LLM &&
        agentMessage.type == AgentMessageType.IMAGE_URL) {
      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(
                agentMessage.message as String)
          ]);
    }

    //LLM return function calling
    if (agentMessage.from == AgentRoleType.LLM &&
        agentMessage.type == AgentMessageType.FUNCTION_CALL_LIST) {
      List<FunctionCall> functionCallList =
      agentMessage.message as List<FunctionCall>;
      List<OpenAIResponseToolCall> openAIResponseToolCallList =
      functionCallList.map((FunctionCall functionCall) {
        return _toOpenAIResponseToolCall(functionCall);
      }).toList();

      return OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: null,
          toolCalls: openAIResponseToolCallList);
    }

    //AGENT return TOOL result
    if (agentMessage.from == AgentRoleType.TOOL &&
        agentMessage.type == AgentMessageType.TOOL_RETURN) {
      ToolReturn toolReturn = agentMessage.message as ToolReturn;
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.tool,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
              jsonEncode(toolReturn.result))
        ],
      ).asRequestFunctionMessage(toolCallId: toolReturn.id);
    }

    //AGENT forward USER messages
    if (agentMessage.from == AgentRoleType.AGENT &&
        agentMessage.type == AgentMessageType.CONTENT_LIST) {
      List<LLMContent> contentList = agentMessage.message as List<LLMContent>;

      List<OpenAIChatCompletionChoiceMessageContentItemModel>
      openAIContentList = contentList.map((content) {
        if(content.type == LLMContentType.IMAGE_URL) {
          return OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(content.message);
        } else {
          return OpenAIChatCompletionChoiceMessageContentItemModel.text(content.message);
        }
      }).toList();

      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: openAIContentList,
      );
    }

    //Default, USER text message
    return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
              agentMessage.message as String)
        ]);
  }

  OpenAIResponseToolCall _toOpenAIResponseToolCall(FunctionCall functionCall) {
    return OpenAIResponseToolCall.fromMap({
      "id": functionCall.id,
      "type": "function",
      "function": {
        "name": functionCall.name,
        "arguments": jsonEncode(functionCall.parameters)
      }
    });
  }

  AgentMessage _toAgentMessage(OpenAIChatCompletionChoiceMessageModel openAIChatCompletionChoiceMessageModel, {Completions? completions}) {
    dynamic message;
    message = openAIChatCompletionChoiceMessageModel.toolCalls
        ?.map((OpenAIResponseToolCall openAIResponseToolCall) {
      String id = openAIResponseToolCall.id!;
      String name = openAIResponseToolCall.function.name!;
      Map<String, dynamic> parameters =
      jsonDecode(openAIResponseToolCall.function.arguments);
      return FunctionCall(id: id, name: name, parameters: parameters);
    }).toList();

    if (message != null) {
      return AgentMessage(
          taskId: _taskId,
          from: AgentRoleType.LLM,
          to: AgentRoleType.AGENT,
          type: AgentMessageType.FUNCTION_CALL_LIST,
          message: message,
          completions: completions
      );
    }

    message = openAIChatCompletionChoiceMessageModel.content?.first.text;
    return AgentMessage(
        taskId: _taskId,
        from: AgentRoleType.LLM,
        to: AgentRoleType.AGENT,
        type: AgentMessageType.TEXT,
        message: message,
        completions: completions
    );
  }
}