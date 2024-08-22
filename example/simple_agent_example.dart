import 'dart:convert';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';

String systemPrompt = "";
String userPrompt = "Return json format!";
ResponseFormat responseFormat = ResponseFormat(type: ResponseFormatType.JSON_OBJECT);

Future<void> main() async {
  LLMExecutor llmExecutor = _buildLLMExecutor();
  SimpleAgent simpleAgent = SimpleAgent(llmExecutor: llmExecutor, systemPrompt: systemPrompt, responseFormat: responseFormat);
  AgentMessage agentMessage = await simpleAgent.userToAgent(prompt: userPrompt, taskId: "task-1");
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