import 'dart:async';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';

import '../listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Add LLM baseUrl and apiKey to `.env` file
String prompt = "Who are you?";

Future<void> main() async {
  String sessionId = uniqueId();
  TextAgent textAgent = TextAgent(
    sessionId: sessionId,
    llmConfig: _buildLLMConfig(),
    agentSession: _buildSession(sessionId),
    systemPrompt: _buildSystemPrompt()
  );
  String taskId = uniqueId();
  await textAgent.userToAgent(taskId: taskId, contentList: [Content(type: ContentType.TEXT, message: prompt)]);
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
