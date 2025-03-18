import 'dart:async';
import 'dart:io';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';
import 'package:dotenv/dotenv.dart';
import 'package:openrpc_dart/openrpc_dart.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../custom_driver/mock_driver.dart';
import '../listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenSpec json file, according to `/example/json/*.json`, which is callable.
/// 2. Run your tool server, which is described in json file.
/// 3. Add LLM baseUrl and apiKey to `.env` file
String prompt = "Help me set store a text 'hello1', and read text id 1";

Future<void> main() async {
  String sessionId = uniqueId();
  ToolAgent toolAgent = ToolAgent(
    sessionId: sessionId,
    llmConfig: _buildLLMConfig(),
    agentSession: _buildSession(sessionId),
    toolDriverList: await _buildToolDriverList(),
    systemPrompt: _buildSystemPrompt()
  );
  String taskId = uniqueId();
  await toolAgent.userToAgent(taskId: taskId, contentList: [Content(type: ContentType.TEXT, message: prompt)], stream: true);

  toolAgent.agentSession.taskDoneAgentMessageList.forEach((AgentMessage agentMessage) {
    print(AgentMessageDto.fromModel(agentMessage).toJson());
  });
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

/// Standard protocol for tool driver, openrpc/openapi3
// Future<List<ToolDriver>> _buildToolDriverList() async {
//   String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json${Platform.pathSeparator}openrpc";
//   List<String> fileNameList = [
//     "json-rpc-book.json"
//     // "json-rpc-food.json" // you can add more tool spec json file.
//   ];
//
//   List<ToolDriver> toolRunnerList = [];
//   for (String fileName in fileNameList) {
//     OpenRPC openRPC = await OpenRPCLoader()
//         .loadFromFile("$folder${Platform.pathSeparator}$fileName");
//     ToolDriver toolRunner = JsonRPCDriver(openRPC);
//
//     /// If your tools interface is `HTTP API`/`json-rpc 2.0 over HTTP`/`Modbus`, REMEMBER return these ToolDriver of the tools.
//     // OpenAPI openAPI = await OpenAPILoader().loadFromFile("$folder/$fileName");
//     // ToolDriver toolRunner = OpenAPIRunner(openAPI);
//
//     toolRunnerList.add(toolRunner);
//   }
//   return toolRunnerList;
// }

AgentSession _buildSession(String sessionId) {
  AgentSession session = AgentSession();
  session.addAgentMessageListener((AgentMessage agentMessage) {
    listen(sessionId, AgentMessageDto.fromModel(agentMessage));
  });
  session.addAgentMessageChunkListener((AgentMessageChunk agentMessageChunk) {
    listenChunk(sessionId, AgentMessageChunkDto.fromModel(agentMessageChunk));
  });
  return session;
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return 'You are a tools caller, who can call tools to help me manage my storage.';
}
