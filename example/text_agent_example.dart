import 'dart:async';
import 'dart:convert';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenSpec json file, according to `/example/json/*.json`, which is callable.
/// 2. Run your tool server, which is described in json file.
/// 3. Add LLM baseUrl and apiKey to `.env` file
String prompt = "Who are you?";

Future<void> main() async {
  TextAgent textAgent = TextAgent(
      llmExecutor: _buildLLMExecutor(),
      agentSession: _buildSession(),
      systemPrompt: _buildSystemPrompt());
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

AgentSession _buildSession() {
  AgentSession session = AgentSession();
  session.addAgentMessageListener((AgentMessage agentMessage) {
    String system = "🖥SYSTEM";
    String user = "👤USER";
    String agent = "🤖AGENT";
    String llm = "💡LLM";
    String client = "🔗CLIENT";

    String message = "";
    if (agentMessage.type == TextMessageType.TEXT)
      message = agentMessage.message as String;
    if (agentMessage.type == TextMessageType.IMAGE_URL)
      message = agentMessage.message as String;
    if (agentMessage.type == AgentMessageType.CONTENT_LIST)
      message = jsonEncode((agentMessage.message as List<Content>)
          .map((content) => content.toJson())
          .toList());

    String from = "";
    if (agentMessage.from == TextRoleType.SYSTEM) {
      from = system;
      message = "\n$message";
    }
    if (agentMessage.from == TextRoleType.USER) from = user;
    if (agentMessage.from == TextRoleType.AGENT) from = agent;
    if (agentMessage.from == TextRoleType.LLM) from = llm;
    if (agentMessage.from == TextRoleType.CLIENT) from = client;

    String to = "";
    if (agentMessage.to == TextRoleType.SYSTEM) to = system;
    if (agentMessage.to == TextRoleType.USER) to = user;
    if (agentMessage.to == TextRoleType.AGENT) to = agent;
    if (agentMessage.to == TextRoleType.LLM) to = llm;
    if (agentMessage.to == TextRoleType.CLIENT) to = client;

    if (from.isNotEmpty && to.isNotEmpty) {
      print("$from -> $to: [${agentMessage.type}] $message");
    }
  });
  return session;
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return 'You are a Q&A robot.';
}
