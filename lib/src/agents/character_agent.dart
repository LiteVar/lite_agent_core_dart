import '../model.dart';
import 'simple_agent.dart';

// prompt with system message, run once.
abstract class SystemPromptAgent extends SimpleAgent {
  String systemPrompt;

  SystemPromptAgent({required super.llmExecutor, required this.systemPrompt});

  @override
  Future<AgentMessage> userToAgent(String prompt) async {
    AgentMessage systemMessage = AgentMessage(
        from: AgentRole.system,
        to: AgentRole.agent,
        type: AgentMessageType.text,
        message: systemPrompt);
    AgentMessage userMessage = AgentMessage(
        from: AgentRole.agent,
        to: AgentRole.llm,
        type: AgentMessageType.text,
        message: prompt);

    List<AgentMessage> agentLlmMessageList = [systemMessage, userMessage];

    AgentMessage newAgentLlmMessage =
        await llmExecutor.requestLLM(agentMessageList: agentLlmMessageList);
    return newAgentLlmMessage;
  }
}
