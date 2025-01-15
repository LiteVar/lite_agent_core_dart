import 'dart:async';
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

Future<void> main() async {
  String sessionId = Uuid().v4();
  ToolAgent toolAgent = ToolAgent(
    sessionId: sessionId,
    llmConfig: _buildLLMConfig(),
    agentSession: _buildSession(sessionId),
    toolDriverList: await _buildToolDriverList(),
    systemPrompt: _buildSystemPrompt(),
    toolPipelineStrategy: PipelineStrategyType.SERIAL /// Can change to PARALLEL or REJECT to test
  );

  try {
    String prompt1 = "Help me set store a text 'hello1'.";
    String taskId1 = Uuid().v4();
    print("taskId1: $taskId1");
    await toolAgent.userToAgent(taskId: taskId1, contentList: [Content(type: ContentType.TEXT, message: prompt1)]);
  } on TaskRejectException catch (e) {
    print(e);
  }
  try {
    String prompt2 = "Help me set store a text 'hello22'.";
    String taskId2 = Uuid().v4();
    print("taskId2: $taskId2");
    await toolAgent.userToAgent(taskId: taskId2, contentList: [Content(type: ContentType.TEXT, message: prompt2)]);
  } on TaskRejectException catch (e) {
    print(e);
  }
  try {
    String prompt3 = "Help me set store a text 'hello333'.";
    String taskId3 = Uuid().v4();
    print("taskId3: $taskId3");
    await toolAgent.userToAgent(taskId: taskId3, contentList: [Content(type: ContentType.TEXT, message: prompt3)]);
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
  return 'You are a tools caller, who can call tools to help me manage my storage.';
}
