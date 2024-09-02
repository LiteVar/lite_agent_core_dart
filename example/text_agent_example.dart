import 'dart:async';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:uuid/uuid.dart';

import 'listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Add LLM baseUrl and apiKey to `.env` file
String prompt = "Who are you?";

Future<void> main() async {
  String sessionId = Uuid().v4();
  TextAgent textAgent = TextAgent(
    sessionId: sessionId,
    llmExecutor: _buildLLMExecutor(),
    agentSession: _buildSession(sessionId),
    systemPrompt: _buildSystemPrompt()
  );
  textAgent.userToAgent(taskId: "0", contentList: [Content(type: ContentType.TEXT, message: prompt)]);
}

LLMExecutor _buildLLMExecutor() {
  DotEnv env = DotEnv();
  env.load(['example/.env']);

  LLMConfig llmConfig = LLMConfig(
    baseUrl: env["baseUrl"]!,
    apiKey: env["apiKey"]!,
    model: "gpt-3.5-turbo",
  );

  OpenAIExecutor openAIExecutor = OpenAIExecutor(llmConfig);

  return openAIExecutor;
}

AgentSession _buildSession(String sessionId) {
  AgentSession session = AgentSession();
  session.addAgentMessageListener((AgentMessage agentMessage) {
    listen(sessionId, agentMessage);
  });
  return session;
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return 'You are a Q&A robot.';
}
