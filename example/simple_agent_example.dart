import 'dart:convert';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';

String systemPrompt = "";
String userPrompt = "Hello!";
ResponseFormat responseFormat = ResponseFormat(type: ResponseFormatType.TEXT);

Future<void> main() async {
  LLMExecutor llmExecutor = _buildLLMExecutor();
  SimpleAgent simpleAgent = SimpleAgent(llmExecutor: llmExecutor, systemPrompt: systemPrompt, responseFormat: responseFormat);
  AgentMessage agentMessage = await simpleAgent.userToAgent(contentList: [Content(message: userPrompt, type: ContentType.TEXT)], taskId: "task-1");
  print(jsonEncode(AgentMessageDto.fromModel(agentMessage).toJson()));
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