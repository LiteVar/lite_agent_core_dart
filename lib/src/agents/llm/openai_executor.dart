import 'dart:async';
import 'dart:convert';
import 'package:dart_openai_sdk/dart_openai_sdk.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../text_agent/model.dart';
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
    AgentMessage agentMessage = agentMessageList.lastWhere((agentMessage)=> agentMessage.role == AgentRoleType.AGENT);
    _sessionId = agentMessage.sessionId;
    _taskId = agentMessage.taskId;
    List<OpenAIChatCompletionChoiceMessageModel> requestMessageList = [];

    for(AgentMessage agentMessage in agentMessageList) {
      if (agentMessage.role == AgentRoleType.TOOL && agentMessage.type == AgentMessageType.TASK_STATUS) {
        // If tool return status, skip
        continue;
      } else {
        requestMessageList.add(_buildOpenAIMessage(agentMessage));
      }
    }

    List<OpenAIToolModel>? tools = functionModelList?.map((FunctionModel functionModel) => _buildOpenAIToolModel(functionModel)).toList();

    try {
      ChatCompletion chatCompletion = await super.chat(messageList: requestMessageList, toolList: tools, responseFormat: responseFormat);

      AgentMessage agentMessage = _toAgentMessage(
          chatCompletion.message,
          completions: chatCompletion.completions
      );

      return agentMessage;
    } catch(e) {
      throw LLMException(message: e.toString());
    }
  }

  Future<Stream<AgentMessage>> requestByStream({required List<AgentMessage> agentMessageList, List<FunctionModel>? functionModelList, ResponseFormat? responseFormat}) async {
    AgentMessage agentMessage = agentMessageList.lastWhere((agentMessage)=> agentMessage.role == AgentRoleType.AGENT);
    _sessionId = agentMessage.sessionId;
    _taskId = agentMessage.taskId;
    List<OpenAIChatCompletionChoiceMessageModel> requestMessageList = [];

    for(AgentMessage agentMessage in agentMessageList) {
      if (agentMessage.role == AgentRoleType.TOOL && agentMessage.type == AgentMessageType.TASK_STATUS) {
        // If tool return status, skip
        continue;
      } else {
        requestMessageList.add(_buildOpenAIMessage(agentMessage));
      }
    }

    List<OpenAIToolModel>? tools = functionModelList?.map((FunctionModel functionModel) => _buildOpenAIToolModel(functionModel)).toList();

    try {
      Stream<ChatCompletionDelta> chatCompletionDeltaStream = await super.chatByStream(messageList: requestMessageList, toolList: tools, responseFormat: responseFormat);

      StreamController<AgentMessage> agentMessageStreamController = StreamController<AgentMessage>();

      DeltaAccumulation textAccumulation = TextAccumulation();
      DeltaAccumulation functionCallAccumulation = FunctionCallAccumulation();
      String finishReason = "";

      chatCompletionDeltaStream.listen((chatCompletionDelta) {
        if(chatCompletionDelta.finishReason == FinishReasonType.LENGTH) throw LLMException(message: "The generation exceeded max_tokens or the conversation exceeded the max context length.");
        if(chatCompletionDelta.finishReason == FinishReasonType.CONTENT_FILTER) throw LLMException(message: "the content filtering system detects harmful content");
        finishReason = chatCompletionDelta.finishReason??finishReason;
        if(chatCompletionDelta.delta?.toolCalls != null || chatCompletionDelta.finishReason == FinishReasonType.TOOL_CALLS || (finishReason == FinishReasonType.TOOL_CALLS && chatCompletionDelta.completions != null)) {
          functionCallAccumulation.appendDelta(chatCompletionDelta, <FunctionCall> (functionCallList, Completions completions) {
            AgentMessage agentMessage = AgentMessage(
              sessionId: _sessionId,
              taskId: _taskId,
              role: AgentRoleType.LLM,
              to: AgentRoleType.AGENT,
              type: AgentMessageType.FUNCTION_CALL_LIST,
              message: functionCallList,
              completions: completions
            );
            agentMessageStreamController.add(agentMessage);
          });
        } else if(chatCompletionDelta.delta?.content != null ||  chatCompletionDelta.finishReason == FinishReasonType.STOP || (finishReason == FinishReasonType.STOP && chatCompletionDelta.completions != null)) {
          AgentMessage? agentMessage = _chunkDeltaToAgentMessage(chatCompletionDelta);
          if(agentMessage != null) agentMessageStreamController.add(agentMessage);
          textAccumulation.appendDelta(chatCompletionDelta, <String>(text, Completions completions) {
            AgentMessage agentMessage = AgentMessage(
              sessionId: _sessionId,
              taskId: _taskId,
              role: AgentRoleType.LLM,
              to: AgentRoleType.AGENT,
              type: AgentMessageType.TEXT,
              message: text,
              completions: completions
            );
            agentMessageStreamController.add(agentMessage);

            AgentMessage chunkDoneMessage = AgentMessage(
                sessionId: agentMessage.sessionId,
                taskId: agentMessage.taskId,
                role: AgentRoleType.LLM,
                to: AgentRoleType.AGENT,
                type: AgentMessageType.TASK_STATUS,
                message: TaskStatus(status: TextStatusType.CHUNK_DONE, taskId: agentMessage.taskId)
            );
            agentMessageStreamController.add(chunkDoneMessage);
          });
        }
      },
        onDone: () {
          agentMessageStreamController.close();
        },
        onError: (e) {
          agentMessageStreamController.addError(e);
        }
      );

      return agentMessageStreamController.stream;
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
    if (agentMessage.role == AgentRoleType.SYSTEM && agentMessage.type == AgentMessageType.TEXT) {
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.system,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)
        ]);
    }

    //LLM return text
    if (agentMessage.role == AgentRoleType.LLM && agentMessage.type == AgentMessageType.TEXT) {
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.assistant,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(agentMessage.message as String)
        ]);
    }

    //LLM return image
    if (agentMessage.role == AgentRoleType.LLM && agentMessage.type == AgentMessageType.IMAGE_URL) {
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.assistant,
        content: [OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(agentMessage.message as String)
        ]);
    }

    //LLM return function calling
    if (agentMessage.role == AgentRoleType.LLM && agentMessage.type == AgentMessageType.FUNCTION_CALL_LIST) {
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
    if (agentMessage.role == AgentRoleType.TOOL && agentMessage.type == AgentMessageType.TOOL_RETURN) {
      ToolReturn toolReturn = agentMessage.message as ToolReturn;
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.tool,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(jsonEncode(toolReturn.result))
        ],
      ).asRequestFunctionMessage(toolCallId: toolReturn.id);
    }

    //AGENT forward USER messages
    if (agentMessage.role == AgentRoleType.AGENT && agentMessage.type == AgentMessageType.CONTENT_LIST) {
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

    // if (openAIChatCompletionChoiceMessageModel.haveToolCalls) {
    //   return _toFunctionCallList(openAIChatCompletionChoiceMessageModel.toolCalls!, completions);
    // }

    message = openAIChatCompletionChoiceMessageModel.content?.first.text;
    return AgentMessage(
      sessionId: _sessionId,
      taskId: _taskId,
      role: AgentRoleType.LLM,
      to: AgentRoleType.AGENT,
      type: AgentMessageType.TEXT,
      message: message,
      completions: completions
    );
  }
  //
  // AgentMessage _toFunctionCallList(List<OpenAIResponseToolCall> toolCalls, Completions? completions) {
  //   List<FunctionCall> functionCallList = toolCalls.map((OpenAIResponseToolCall openAIResponseToolCall) {
  //     String id = openAIResponseToolCall.id!;
  //     String name = openAIResponseToolCall.function.name!;
  //     print(openAIResponseToolCall.function.arguments);
  //     Map<String, dynamic> parameters = jsonDecode(openAIResponseToolCall.function.arguments);
  //     return FunctionCall(id: id, name: name, parameters: parameters);
  //   }).toList();
  //   return AgentMessage(
  //       sessionId: _sessionId,
  //       taskId: _taskId,
  //       role: AgentRoleType.LLM,
  //       to: AgentRoleType.AGENT,
  //       type: AgentMessageType.FUNCTION_CALL_LIST,
  //       message: functionCallList,
  //       completions: completions
  //   );
  // }

  AgentMessage? _chunkDeltaToAgentMessage(ChatCompletionDelta chatCompletionDelta) {
    String text = chatCompletionDelta.delta?.content?.first?.text??"";
    if(text.isNotEmpty) {
      return AgentMessage(
        sessionId: _sessionId,
        taskId: _taskId,
        role: AgentRoleType.LLM,
        to: AgentRoleType.AGENT,
        type: AgentMessageType.CHUNK,
        message: text,
        completions: chatCompletionDelta.completions
      );
    }
    return null;
  }
}

abstract class DeltaAccumulation<T> {
  Completions? completions;
  bool finished = false;
  void appendDelta(ChatCompletionDelta delta, void Function<T>(T accumulation, Completions completions) onComplete) {
    if(completions == null) completions = delta.completions;
  }
}

class TextAccumulation extends DeltaAccumulation<String> {
  String textAccumulation = "";

  @override
  void appendDelta(ChatCompletionDelta delta, void Function<T>(T accumulation, Completions completions) onComplete) {
    super.appendDelta(delta, onComplete);
    if(delta.finishReason == null) {
      textAccumulation += delta.delta?.content?.first?.text??"";
    } else if(delta.finishReason == FinishReasonType.STOP) {
      super.finished = true;
    }

    if(super.finished && completions != null) {
      onComplete(textAccumulation, super.completions!);
    }
  }
}

class FunctionCallAccumulation extends DeltaAccumulation<List<FunctionCall>> {
  List<FunctionCall> functionCallList = [];
  String currentId = "";
  String currentName = "";
  String currentParameters = "";

  @override
  void appendDelta(ChatCompletionDelta delta, void Function<T>(T accumulation, Completions completions) onComplete) {
    super.appendDelta(delta, onComplete);
    if(delta.finishReason == null && super.completions == null) {
      OpenAIResponseToolCall toolCall = delta.delta!.toolCalls!.first;
      if(toolCall.id != null && toolCall.id != currentId) {
        _buildFunctionCall();
        currentId = toolCall.id!;
      }
      if(toolCall.function.name != null) currentName = toolCall.function.name!;
      if(toolCall.function.arguments != null) currentParameters += toolCall.function.arguments!;
    } else if(delta.finishReason == FinishReasonType.TOOL_CALLS) {
      _buildFunctionCall();
      super.finished = true;
    }

    if(super.finished && completions != null) {
      onComplete(functionCallList, super.completions!);
    }
  }

  void _buildFunctionCall() {
    if(currentName.isNotEmpty && currentParameters.isNotEmpty) {
      functionCallList.add(FunctionCall(id: currentId, name: currentName, parameters: jsonDecode(currentParameters)));
      currentId = ""; currentName = ""; currentParameters = "";
    }
  }
}