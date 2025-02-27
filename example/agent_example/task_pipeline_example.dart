import 'dart:async';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';
import '../listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Add LLM baseUrl and apiKey to `.env` file

Future<void> main() async {
  String sessionId = uniqueId();
  TextAgent textAgent = TextAgent(
    sessionId: sessionId,
    llmConfig: _buildLLMConfig(),
    agentSession: _buildSession(sessionId),
    systemPrompt: _buildSystemPrompt(),
    taskPipelineStrategy: PipelineStrategyType.REJECT /// Can change to PARALLEL or SERIAL to test
  );
  try {
    String prompt1 = "Who are you?";
    String taskId1 = uniqueId();
    print("taskId1: $taskId1");
    await textAgent.userToAgent(taskId: taskId1, contentList: [Content(type: ContentType.TEXT, message: prompt1)]);
  } on TaskRejectException catch (e) {
    print(e);
  }
  try {
    String prompt2 = "Where are you from?";
    String taskId2 = uniqueId();
    print("taskId2: $taskId2");
    await textAgent.userToAgent(taskId: taskId2, contentList: [Content(type: ContentType.TEXT, message: prompt2)]);
  } on TaskRejectException catch (e) {
    print(e);
  }
  try {
    String prompt3 = "What do you want to do?";
    String taskId3 = uniqueId();
    print("taskId3: $taskId3");
    await textAgent.userToAgent(taskId: taskId3, contentList: [Content(type: ContentType.TEXT, message: prompt3)]);
  } on TaskRejectException catch (e) {
    print(e);
  }

}

LLMConfig _buildLLMConfig() {
  DotEnv env = DotEnv();
  env.load(['example/.env']);

  return LLMConfig(
    baseUrl: env["baseUrl"]!,
    apiKey: env["apiKey"]!,
    model: "gpt-4o-mini",
  );
}

AgentSession _buildSession(String sessionId) {
  AgentSession session = AgentSession();
  session.addAgentMessageListener((AgentMessage agentMessage) {
    listen(sessionId, AgentMessageDto.fromModel(agentMessage));
  });
  return session;
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return 'You are a Q&A robot.';
}
