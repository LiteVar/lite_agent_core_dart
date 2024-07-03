import '../model.dart';
import '../util/llm_executor.dart';

class LLM {
  LLMExecutor llmExecutor;
  LLM({required this.llmExecutor});
}

class SimpleAgent extends LLM {
  SimpleAgent({required super.llmExecutor});

  Future<AgentMessage> userToAgent(String prompt) async {
    return await llmExecutor.requestLLM(agentMessageList: [AgentMessage(from: AgentRole.AGENT, to: AgentRole.LLM, type: AgentMessageType.text, message: prompt)]);
  }
}