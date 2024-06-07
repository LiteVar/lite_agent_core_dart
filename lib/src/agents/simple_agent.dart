import '../model.dart';
import '../util/llm_util.dart';

class LLM {
  LLMRunner llmRunner;
  LLM({required this.llmRunner});
}

class SimpleAgent extends LLM {
  SimpleAgent({required super.llmRunner});

  Future<AgentMessage> userToAgent(String prompt) async {
    return await llmRunner.requestLLM(agentMessageList: [AgentMessage(from: AgentRole.AGENT, to: AgentRole.LLM, type: AgentMessageType.TEXT, message: prompt)]);
  }
}