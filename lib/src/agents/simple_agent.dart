import 'package:uuid/uuid.dart';
import '../llm/model.dart';
import 'llm/llm_executor.dart';
import 'text_agent/model.dart';
import 'model.dart';

class SimpleAgent {
  LLMExecutor llmExecutor;
  String? systemPrompt;
  ResponseFormat? responseFormat;

  SimpleAgent({required this.llmExecutor, this.systemPrompt, ResponseFormat? responseFormat});

  Future<AgentMessage> userToAgent({required String prompt, String? sessionId, String? taskId}) async {
    if(sessionId == null) sessionId = Uuid().v4();
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
      type: TextMessageType.TEXT,
      message: prompt
    );
    agentLlmMessageList.add(userMessage);

    return await llmExecutor.request(
      agentMessageList: agentLlmMessageList,
      responseFormat: responseFormat
    );
  }
}
