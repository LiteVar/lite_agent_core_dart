import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:uuid/uuid.dart';
import '../llm/model.dart';
import 'llm/llm_executor.dart';
import 'session_agent/model.dart';
import 'text_agent/model.dart';
import 'model.dart';

class SimpleAgent {
  late String sessionId;
  LLMExecutor llmExecutor;
  String? systemPrompt;
  ResponseFormat? responseFormat;

  SimpleAgent({required this.llmExecutor, this.systemPrompt, this.responseFormat, sessionId}){
    this.sessionId = sessionId??Uuid().v4();
  }

  Future<AgentMessage> userToAgent({required List<Content> contentList, String? taskId}) async {
    if(taskId == null) taskId = Uuid().v4();

    List<AgentMessage> agentLlmMessageList = [];

    if(systemPrompt != null && systemPrompt!.isNotEmpty) {
      AgentMessage systemMessage = AgentMessage(
          sessionId: sessionId,
          taskId: taskId,
          from: TextRoleType.SYSTEM,
          to: TextRoleType.AGENT,
          type: TextMessageType.TEXT,
          message: systemPrompt
      );
      agentLlmMessageList.add(systemMessage);
    }

    AgentMessage userMessage = AgentMessage(
      sessionId: sessionId,
      taskId: taskId,
      from: TextRoleType.AGENT,
      to: TextRoleType.LLM,
      type: TextMessageType.CONTENT_LIST,
      message: contentList
    );
    agentLlmMessageList.add(userMessage);

    return await llmExecutor.request(
      agentMessageList: agentLlmMessageList,
      responseFormat: responseFormat
    );
  }
}
