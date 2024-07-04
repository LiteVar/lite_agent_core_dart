import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:dotenv/dotenv.dart';
import 'package:openrpc_dart/openrpc_dart.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenSpec json file, according to `/example/json/*.json`, which is callable.
/// 2. Run your tool server, which is described in json file.
/// 3. Add LLM baseUrl and apiKey to `.env` file
String prompt = "Check the status of the book which id is 1.";

Future<void> main() async {
  ToolAgent toolAgent = ToolAgent(
      llmExecutor: _buildLLMRunner(),
      session: _buildSession(),
      toolRunnerList: await _buildToolRunnerList(),
      systemPrompt: _buildSystemPrompt());
  toolAgent.userToAgent([Content(type: ContentType.text, message: prompt)]);
}

LLMExecutor _buildLLMRunner() {
  DotEnv env = DotEnv();
  env.load(['example/.env']);

  LLMConfig llmConfig = LLMConfig(
    baseUrl: env["baseUrl"]!,
    apiKey: env["apiKey"]!,
    model: "gpt-3.5-turbo",
  );
  return LLMExecutor(llmConfig);
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
Future<List<ToolRunner>> _buildToolRunnerList() async {
  String folder =
      "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json";
  List<String> fileNameList = [
    "json-rpc-book.json"
    // "json-rpc-food.json" // you can add more tool spec json file.
  ];

  List<ToolRunner> toolRunnerList = [];
  for (String fileName in fileNameList) {
    OpenRPC openRPC = await OpenRPCLoader().loadFromFile("$folder/$fileName");
    ToolRunner toolRunner = JsonRPCRunner(openRPC);

    /// If your tools interface is `HTTP API`/`json-rpc 2.0 over HTTP`/`Modbus`, REMEMBER return these ToolRunner of the tools.
    // OpenAPI openAPI = await OpenAPILoader().loadFromFile("$folder/$fileName");
    // ToolRunner toolRunner = OpenAPIRunner(openAPI);

    toolRunnerList.add(toolRunner);
  }
  return toolRunnerList;
}

AgentSession _buildSession() {
  AgentSession session = AgentSession();
  session.addAgentMessageListener((AgentMessage agentMessage) {
    String system = "🖥SYSTEM";
    String user = "👤USER";
    String agent = "🤖AGENT";
    String llm = "💡LLM";
    String tool = "🔧TOOL";
    String client = "🔗CLIENT";

    String message = "";
    if (agentMessage.type == AgentMessageType.text)
      message = agentMessage.message as String;
    if (agentMessage.type == AgentMessageType.imageUrl)
      message = agentMessage.message as String;
    if (agentMessage.type == AgentMessageType.functionCallList)
      message = jsonEncode((agentMessage.message as List<FunctionCall>)
          .map((functionCall) => functionCall.toJson())
          .toList());
    if (agentMessage.type == AgentMessageType.toolReturn)
      message = jsonEncode(agentMessage.message as ToolReturn);
    if (agentMessage.type == AgentMessageType.contentList)
      message = jsonEncode((agentMessage.message as List<Content>)
          .map((content) => content.toJson())
          .toList());

    String from = "";
    if (agentMessage.from == AgentRole.system) {
      from = system;
      message = "\n$message";
    }
    if (agentMessage.from == AgentRole.user) from = user;
    if (agentMessage.from == AgentRole.agent) from = agent;
    if (agentMessage.from == AgentRole.llm) from = llm;
    if (agentMessage.from == AgentRole.tool) from = tool;
    if (agentMessage.from == AgentRole.client) from = client;

    String to = "";
    if (agentMessage.to == AgentRole.system) to = system;
    if (agentMessage.to == AgentRole.user) to = user;
    if (agentMessage.to == AgentRole.agent) to = agent;
    if (agentMessage.to == AgentRole.llm) to = llm;
    if (agentMessage.to == AgentRole.tool) to = tool;
    if (agentMessage.to == AgentRole.client) to = client;

    if (from.isNotEmpty && to.isNotEmpty) {
      print("$from -> $to: [${agentMessage.type.name}] $message");
    }
  });
  return session;
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return 'You are a tools caller, who can call book system tools to help me manage my books.';
}
