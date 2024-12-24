import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:dotenv/dotenv.dart';
import 'package:opentool_dart/opentool_dart.dart';
import 'package:uuid/uuid.dart';
import '../custom_driver/mock_driver.dart';
import '../listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenSpec json file, according to `/example/json/*.json`, which is callable.
/// 2. Run your tool server, which is described in json file.
/// 3. Add LLM baseUrl and apiKey to `.env` file
String prompt = "Help me set store a text 'hello'.";

Future<void> main() async {
  String sessionId = Uuid().v4();
  ToolAgent toolAgent = ToolAgent(
      sessionId: sessionId,
      llmConfig: _buildLLMConfig(),
      agentSession: _buildSession(sessionId),
      toolDriverList: await _buildToolDriverList(),
      systemPrompt: _buildSystemPrompt(),
      toolReflectPromptList: await _buildToolReflectPromptList(),
  );
  toolAgent.userToAgent(taskId: "0", contentList: [Content(type: ContentType.TEXT, message: prompt)]);
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

Future<List<ToolDriver>> _buildToolDriverList() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}custom_driver";
  List<String> fileNameList = [
    "mock-tool.json"
  ];

  List<ToolDriver> toolDriverList = [];
  for (String fileName in fileNameList) {
    OpenTool openTool = await OpenToolLoader().loadFromFile("$folder${Platform.pathSeparator}$fileName");
    ToolDriver toolDriver = MockDriver().bind(openTool);
    toolDriverList.add(toolDriver);
  }
  return toolDriverList;
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
  return 'You are a tools caller, who can call book system tools to help me manage my storage.';
}

Future<List<ReflectPrompt>> _buildToolReflectPromptList() async {
  LLMConfig llmConfig = _buildLLMConfig();
  String toolsDescription = await _buildToolsDescription();
  String prompt = "# Role\n\nYou are a tool reflector, you can reflect user tool usage correct or not. You should mark score 0 to 10. 10 is full score. Below is tools that user can use. \n\n$toolsDescription";
  return [
    ReflectPrompt(llmConfig: llmConfig, prompt: prompt),
  ];
}

Future<String> _buildToolsDescription() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}custom_driver";
  List<String> fileNameList = [
    "mock-tool.json"
  ];

  String toolsDescription = "# Tools\n\n";
  for (String fileName in fileNameList) {
    OpenTool openTool = await OpenToolLoader().loadFromFile("$folder${Platform.pathSeparator}$fileName");
    String jsonString = jsonEncode(openTool.toJson());
    String toolDescription = "## ${openTool.info.title} \n\n```json\n${jsonString}\n```";
    toolsDescription = toolsDescription + toolDescription;
  }

  return toolsDescription;
}