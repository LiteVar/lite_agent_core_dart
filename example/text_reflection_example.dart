import 'dart:async';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:uuid/uuid.dart';

import 'listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Add LLM baseUrl and apiKey to `.env` file
String prompt = "你好！";

Future<void> main() async {
  String sessionId = Uuid().v4();
  TextAgent textAgent = TextAgent(
    sessionId: sessionId,
    llmConfig: _buildLLMConfig(),
    agentSession: _buildSession(sessionId),
    systemPrompt: _buildSystemPrompt(),
    textReflectPromptList: _buildTextReflectPromptList(),
  );
  textAgent.userToAgent(taskId: "0", contentList: [Content(type: ContentType.TEXT, message: prompt)]);
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
  return 'You are a translate robot. Translate any user content language to English. Reply sentence after translating, not chatting.';
}

List<ReflectPrompt> _buildTextReflectPromptList() {
  LLMConfig llmConfig = _buildLLMConfig();
  return [
    ReflectPrompt(llmConfig: llmConfig, prompt: "You are a language reflector, you can reflect `LLM Response` language is English or not. If English, score is 10, else score is 0."),
  ];
}
