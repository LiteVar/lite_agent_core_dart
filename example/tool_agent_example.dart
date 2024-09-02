import 'dart:async';
import 'dart:io';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:dotenv/dotenv.dart';
import 'package:openrpc_dart/openrpc_dart.dart';
import 'package:opentool_dart/opentool_dart.dart';
import 'package:uuid/uuid.dart';
import 'listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenSpec json file, according to `/example/json/*.json`, which is callable.
/// 2. Run your tool server, which is described in json file.
/// 3. Add LLM baseUrl and apiKey to `.env` file
String prompt = "Check the status of the book which id is 1.";

Future<void> main() async {
  String sessionId = Uuid().v4();
  ToolAgent toolAgent = ToolAgent(
    sessionId: sessionId,
    llmExecutor: _buildLLMExecutor(),
    agentSession: _buildSession(sessionId),
    toolDriverList: await _buildToolDriverList(),
    systemPrompt: _buildSystemPrompt()
  );
  toolAgent.userToAgent(taskId: "0", contentList: [Content(type: ContentType.TEXT, message: prompt)]);
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

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
Future<List<ToolDriver>> _buildToolDriverList() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json${Platform.pathSeparator}openrpc";
  List<String> fileNameList = [
    "json-rpc-book.json"
    // "json-rpc-food.json" // you can add more tool spec json file.
  ];

  List<ToolDriver> toolRunnerList = [];
  for (String fileName in fileNameList) {
    OpenRPC openRPC = await OpenRPCLoader()
        .loadFromFile("$folder${Platform.pathSeparator}$fileName");
    ToolDriver toolRunner = JsonRPCDriver(openRPC);

    /// If your tools interface is `HTTP API`/`json-rpc 2.0 over HTTP`/`Modbus`, REMEMBER return these ToolDriver of the tools.
    // OpenAPI openAPI = await OpenAPILoader().loadFromFile("$folder/$fileName");
    // ToolDriver toolRunner = OpenAPIRunner(openAPI);

    toolRunnerList.add(toolRunner);
  }
  return toolRunnerList;
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
  return 'You are a tools caller, who can call book system tools to help me manage my books.';
}
