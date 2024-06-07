import 'package:lite_agent_core/lite_agent_core.dart';

import 'simple_agent.dart';

// only character prompt, run once.
abstract class CharacterAgent extends SimpleAgent {
  String character; // Character description, notes, restriction

  CharacterAgent({required super.llmRunner, required this.character});

  @override
  Future<AgentMessage> userToAgent(String prompt) async {
    AgentMessage systemMessage = AgentMessage(from: AgentRole.SYSTEM, to: AgentRole.AGENT, type: AgentMessageType.TEXT, message: character);
    AgentMessage userMessage = AgentMessage(from: AgentRole.AGENT, to: AgentRole.LLM, type: AgentMessageType.TEXT, message: prompt);

    List<AgentMessage> agentLlmMessageList = [
      systemMessage,
      userMessage
    ];

    AgentMessage newAgentLlmMessage = await llmRunner.requestLLM(agentMessageList: agentLlmMessageList);
    return newAgentLlmMessage;
  }

}