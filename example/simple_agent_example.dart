import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';

String systemPrompt = "";
ResponseFormat responseFormat = ResponseFormat(type: ResponseFormatType.json);

Future<void> main() async {
  LLMExecutor llmExecutor = _buildLLMExecutor();
  SimpleAgent simpleAgent = SimpleAgent(llmExecutor: llmExecutor, systemPrompt: systemPrompt, responseFormat: ResponseFormat(type: ResponseFormatType.json));
  AgentMessage agentMessage = await simpleAgent.userToAgent(prompt: "Return json format!", taskId: "task-1");
  print(jsonEncode(AgentMessageDto.fromModel("session-1", agentMessage).toJson()));
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