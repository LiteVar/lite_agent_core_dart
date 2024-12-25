import 'dart:async';
import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import 'package:opentool_dart/opentool_dart.dart';
import 'exception.dart';
import '../../llm/openai_util.dart';
import '../../llm/model.dart';
import '../model.dart';
import 'llm_executor.dart';
import 'model.dart';

class OpenAIExecutor extends OpenAIUtil implements LLMExecutor {
  late String _sessionId;
  late String _taskId;

  OpenAIExecutor(super.llmConfig) {
    OpenAI.baseUrl = llmConfig.baseUrl;
    OpenAI.apiKey = llmConfig.apiKey;
  }

  Future<AgentMessage> request({required List<AgentMessage> agentMessageList, List<FunctionModel>? functionModelList, ResponseFormat? responseFormat}) async {
    AgentMessage agentMessage = agentMessageList.lastWhere((agentMessage)=> agentMessage.from == AgentRoleType.AGENT);
    _sessionId = agentMessage.sessionId;
    _taskId = agentMessage.taskId;
    List<OpenAIChatCompletionChoiceMessageModel> requestMessageList = [];

    for(AgentMessage agentMessage in agentMessageList) {
      if (agentMessage.from == AgentRoleType.TOOL && agentMessage.type == AgentMessageType.TASK_STATUS) {
        // If tool return status, skip
        continue;
      } else {
        requestMessageList.add(_buildOpenAIMessage(agentMessage));
      }
    }

    List<OpenAIToolModel>? tools = functionModelList?.map((FunctionModel functionModel) => _buildOpenAIToolModel(functionModel)).toList();

    try {
      SimpleCompletion chatCompletion = await super.chat(messageList: requestMessageList, toolList: tools, responseFormat: responseFormat);

      AgentMessage agentMessage = _toAgentMessage(
          chatCompletion.message,
          completions: chatCompletion.completions
      );

      return agentMessage;
    } catch(e) {
      throw LLMException(message: e.toString());
    }
  }

  OpenAIToolModel _buildOpenAIToolModel(FunctionModel functionModel) {
    List<OpenAIFunctionProperty> openAIFunctionPropertyList = [];
    functionModel.parameters.forEach((Parameter parameter) {
      openAIFunctionPropertyList.add(_convertToOpenAIFunctionProperty(parameter));
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

  OpenAIFunctionProperty _convertToOpenAIFunctionProperty(Parameter parameter) {
    return _toOpenAIFunctionProperty(
      parameter.name,
      parameter.description??(parameter.schema.description??""),
      parameter.schema,
      parameter.required
    );
  }

  OpenAIFunctionProperty _toOpenAIFunctionProperty(String name, String? description, Schema schema, bool required) {
    switch (schema.type) {
      case DataType.BOOLEAN:
        return OpenAIFunctionProperty.boolean(
          name: name,
          description: description??(schema.description),
          isRequired: required
        );
      case DataType.INTEGER:
        return OpenAIFunctionProperty.integer(
          name: name,
          description: description??(schema.description),
          isRequired: required
        );
      case DataType.NUMBER:
        return OpenAIFunctionProperty.number(
          name: name,
          description: description??(schema.description),
          isRequired: required
        );
      case DataType.STRING:
        return OpenAIFunctionProperty.string(
          name: name,
          description: description??(schema.description),
          isRequired: required,
          enumValues: schema.enum_
        );
      case DataType.ARRAY:
        {
          OpenAIFunctionProperty openAIFunctionProperty = _toOpenAIFunctionProperty(name, description??(schema.description), schema.items!, required);
          return OpenAIFunctionProperty.array(
            name: name,
            description: schema.description,
            isRequired: required,
            items: openAIFunctionProperty
          );
        }
      case DataType.OBJECT:
        {
          Map<String, Schema> properties = schema.properties!;
          List<String>? requiredList = schema.required;
          Map<String, OpenAIFunctionProperty> openAIFunctionProperties = {};
          properties.forEach((String name, Schema schema0) {
            bool required = false;
            if(requiredList != null && requiredList.contains(name)) {
              required = true;
            }
            OpenAIFunctionProperty openAIFunctionProperty = _toOpenAIFunctionProperty(name, schema0.description??"", schema0, required);
            openAIFunctionProperties[name] = openAIFunctionProperty;
          });

          return OpenAIFunctionProperty.object(
            name: name,
            description: schema.description,
            isRequired: required,
            properties: openAIFunctionProperties.values);
        }
      default: {
        return OpenAIFunctionProperty(name: "", typeMap: {});
      }
    }
  }

  OpenAIChatCompletionChoiceMessageModel _buildOpenAIMessage(AgentMessage agentMessage) {
    //System Prompt
    if (agentMessage.from == AgentRoleType.SYSTEM && agentMessage.type == AgentMessageType.TEXT) {
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.system,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)
        ]);
    }

    //LLM return text
    if (agentMessage.from == AgentRoleType.LLM && agentMessage.type == AgentMessageType.TEXT) {
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.assistant,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)
        ]);
    }

    //LLM return image
    if (agentMessage.from == AgentRoleType.LLM && agentMessage.type == AgentMessageType.IMAGE_URL) {
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.assistant,
        content: [OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(agentMessage.message as String)
        ]);
    }

    //LLM return function calling
    if (agentMessage.from == AgentRoleType.LLM && agentMessage.type == AgentMessageType.FUNCTION_CALL_LIST) {
      List<FunctionCall> functionCallList =
      agentMessage.message as List<FunctionCall>;
      List<OpenAIResponseToolCall> openAIResponseToolCallList =
      functionCallList.map((FunctionCall functionCall) {
        return _toOpenAIResponseToolCall(functionCall);
      }).toList();

      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.assistant,
        content: null,
        toolCalls: openAIResponseToolCallList
      );
    }

    //AGENT return TOOL result
    if (agentMessage.from == AgentRoleType.TOOL && agentMessage.type == AgentMessageType.TOOL_RETURN) {
      ToolReturn toolReturn = agentMessage.message as ToolReturn;
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.tool,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(jsonEncode(toolReturn.result))
        ],
      ).asRequestFunctionMessage(toolCallId: toolReturn.id);
    }

    //AGENT forward USER messages
    if (agentMessage.from == AgentRoleType.AGENT && agentMessage.type == AgentMessageType.CONTENT_LIST) {
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
        OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)
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
    message = openAIChatCompletionChoiceMessageModel.toolCalls?.map((OpenAIResponseToolCall openAIResponseToolCall) {
      String id = openAIResponseToolCall.id!;
      String name = openAIResponseToolCall.function.name!;
      Map<String, dynamic> parameters = jsonDecode(openAIResponseToolCall.function.arguments);
      return FunctionCall(id: id, name: name, parameters: parameters);
    }).toList();

    if (message != null) {
      return AgentMessage(
        sessionId: _sessionId,
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
      sessionId: _sessionId,
      taskId: _taskId,
      from: AgentRoleType.LLM,
      to: AgentRoleType.AGENT,
      type: AgentMessageType.TEXT,
      message: message,
      completions: completions
    );
  }
}