import 'model.dart';
import 'llm/llm_executor.dart';
import 'text_agent/model.dart';

class SimpleAgent {
  LLMExecutor llmExecutor;
  SimpleAgent({required this.llmExecutor});

  Future<AgentMessage> userToAgent(String prompt, String? taskId) async {
    return await llmExecutor.request(agentMessageList: [
      AgentMessage(
          taskId: taskId??"",
          from: TextRoleType.AGENT,
          to: TextRoleType.LLM,
          type: TextMessageType.TEXT,
          message: prompt
      )
    ]);
  }
}
