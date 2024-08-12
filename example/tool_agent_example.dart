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
      llmExecutor: _buildLLMExecutor(),
      agentSession: _buildSession(),
      toolDriverList: await _buildToolDriverList(),
      systemPrompt: _buildSystemPrompt());
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
  String folder =
      "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json${Platform.pathSeparator}openrpc";
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
    if (agentMessage.type == ToolMessageType.TEXT)
      message = agentMessage.message as String;
    if (agentMessage.type == ToolMessageType.IMAGE_URL)
      message = agentMessage.message as String;
    if (agentMessage.type == ToolMessageType.FUNCTION_CALL_LIST)
      message = jsonEncode((agentMessage.message as List<FunctionCall>)
          .map((functionCall) => functionCall.toJson())
          .toList());
    if (agentMessage.type == AgentMessageType.TOOL_RETURN)
      message = jsonEncode(agentMessage.message as ToolReturn);
    if (agentMessage.type == AgentMessageType.CONTENT_LIST)
      message = jsonEncode((agentMessage.message as List<Content>)
          .map((content) => content.toJson())
          .toList());

    String from = "";
    if (agentMessage.from == ToolRoleType.SYSTEM) {
      from = system;
      message = "\n$message";
    }
    if (agentMessage.from == ToolRoleType.USER) from = user;
    if (agentMessage.from == ToolRoleType.AGENT) from = agent;
    if (agentMessage.from == ToolRoleType.LLM) from = llm;
    if (agentMessage.from == ToolRoleType.TOOL) from = tool;
    if (agentMessage.from == ToolRoleType.CLIENT) from = client;

    String to = "";
    if (agentMessage.to == ToolRoleType.SYSTEM) to = system;
    if (agentMessage.to == ToolRoleType.USER) to = user;
    if (agentMessage.to == ToolRoleType.AGENT) to = agent;
    if (agentMessage.to == ToolRoleType.LLM) to = llm;
    if (agentMessage.to == ToolRoleType.TOOL) to = tool;
    if (agentMessage.to == ToolRoleType.CLIENT) to = client;

    if (from.isNotEmpty && to.isNotEmpty) {
      print("$from -> $to: [${agentMessage.type}] $message");
    }
  });
  return session;
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return 'You are a tools caller, who can call book system tools to help me manage my books.';
}
