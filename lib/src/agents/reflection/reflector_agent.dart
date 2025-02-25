import 'dart:convert';
import 'package:opentool_dart/opentool_dart.dart';
import 'package:uuid/uuid.dart';
import '../../llm/model.dart';
import '../llm/llm_executor.dart';
import '../llm/model.dart';
import '../model.dart';
import '../session_agent/model.dart';
import '../text_agent/model.dart';
import 'model.dart';
import 'reflector_driver.dart';

class ReflectorAgent {
  LLMExecutor llmExecutor;
  String systemPrompt;
  late String sessionId;
  late String taskId;

  ReflectorAgent({required this.llmExecutor, required this.systemPrompt, sessionId, taskId}) {
    this.sessionId = sessionId??Uuid().v4();
    this.taskId = taskId??Uuid().v4();
  }

  Future<ReflectScore> evaluate(List<Content> contentList, String message, void Function(Completions? completions) subscribeCompletions) async {

    String userMessage = jsonEncode(contentList.map((content)=>content.toJson()).toList());

    String messageToReflect = message;

    try {
      // if FunctionCallList, remove "id" field from each FunctionCall for reflection
      List<dynamic> jsonList = jsonDecode(message);
      List<Map<String, dynamic>> jsonWithoutIdList = jsonList.map((dyn){
        Map<String, dynamic> json = dyn as Map<String, dynamic>;
        if(json["id"] != null) json.remove("id");
        return json;
      }).toList();
      messageToReflect = jsonEncode(jsonWithoutIdList);
    } catch(e) {
      //Do nothing
    }

    String text = "# User Request:\n\n```json\n$userMessage\n```\n\n# LLM Response:\n\n```text\n$messageToReflect\n```";

    Content content = Content(type: ContentType.TEXT, message: text);

    List<Content> reflectContentList = [content];

    List<AgentMessage> agentLLMMessageList = [];

    if(systemPrompt.isNotEmpty) {
      AgentMessage systemMessage = AgentMessage(
          sessionId: sessionId,
          taskId: taskId,
          role: TextRoleType.DEVELOPER,
          to: TextRoleType.AGENT,
          type: TextMessageType.TEXT,
          message: systemPrompt
      );
      agentLLMMessageList.add(systemMessage);
    }

    AgentMessage reflectMessage = AgentMessage(
        sessionId: sessionId,
        taskId: taskId,
        role: TextRoleType.AGENT,
        to: TextRoleType.ASSISTANT,
        type: TextMessageType.CONTENT_LIST,
        message: reflectContentList
    );

    agentLLMMessageList.add(reflectMessage);

    ReflectorDriver reflectionDriver = ReflectorDriver();

    AgentMessage llmMessage = await llmExecutor.request(agentMessageList: agentLLMMessageList, functionModelList: reflectionDriver.parse());
    subscribeCompletions(llmMessage.completions);
    if (llmMessage.type == AgentMessageType.FUNCTION_CALL_LIST) {
      List<FunctionCall> functionCallList = llmMessage.message as List<FunctionCall>;
      FunctionCall functionCall = functionCallList.first;
      try {
        ReflectScore reflectScore = ReflectScore.fromJson(functionCall.parameters);
        return reflectScore;
      } catch(e) {
        return ReflectScore(score: 0, description: e.toString());
      }
    } else {
      return ReflectScore(score: 0, description: "ReflectorAgent reply message type is NOT functionCallList");
    }
  }
}

