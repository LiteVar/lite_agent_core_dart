import 'dart:convert';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';

String systemPrompt = "";
String userPrompt = "Hello!";
ResponseFormat responseFormat = ResponseFormat(type: ResponseFormatType.TEXT);

Future<void> main() async {
  LLMConfig llmConfig = _buildLLMConfig();
  SimpleAgent simpleAgent = SimpleAgent(llmConfig: llmConfig, systemPrompt: systemPrompt, responseFormat: responseFormat);
  String taskId = uniqueId();
  AgentMessage agentMessage = await simpleAgent.userToAgent(contentList: [Content(message: userPrompt, type: ContentType.TEXT)], taskId: taskId);
  print(jsonEncode(AgentMessageDto.fromModel(agentMessage).toJson()));
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