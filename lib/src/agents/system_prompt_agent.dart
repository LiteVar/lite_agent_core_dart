import 'text_agent/model.dart';
import 'model.dart';
import 'simple_agent.dart';

// prompt with system message, run once.
abstract class SystemPromptAgent extends SimpleAgent {
  String systemPrompt;

  SystemPromptAgent({required super.llmExecutor, required this.systemPrompt});

  @override
  Future<AgentMessage> userToAgent(String prompt, String? taskId) async {
    AgentMessage systemMessage = AgentMessage(
      taskId: taskId??"",
      from: TextRoleType.SYSTEM,
      to: TextRoleType.AGENT,
      type: TextMessageType.TEXT,
      message: systemPrompt
    );
    AgentMessage userMessage = AgentMessage(
      taskId: taskId??"",
        from: TextRoleType.AGENT,
        to: TextRoleType.LLM,
        type: TextMessageType.TEXT,
      message: prompt
    );

    List<AgentMessage> agentLlmMessageList = [systemMessage, userMessage];
    AgentMessage newAgentLlmMessage = await llmExecutor.request(agentMessageList: agentLlmMessageList);
    return newAgentLlmMessage;
  }
}
