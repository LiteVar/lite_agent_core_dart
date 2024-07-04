import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenSpec json file, according to `/example/json/*.json`, which is callable.
/// 2. Run your tool server, which is described in json file.
/// 3. Add LLM baseUrl and apiKey to `.env` file
String prompt = "Check the status of the book which id is 1.";

AgentService agentService = AgentService();

Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(
      llmConfig: _buildLLMConfig(),
      systemPrompt: _buildSystemPrompt(),
      openSpecList: await _buildOpenSpecList());

  print("[CapabilityDto] " + capabilityDto.toJson().toString());

  SessionDto sessionDto = await agentService.initChat(capabilityDto, listen);

  print("[SessionDto] " + sessionDto.toJson().toString());

  await agentService.startChat(sessionDto.id,
      [UserMessageDto(type: UserMessageDtoType.text, message: prompt)]);

  print("[prompt] " + prompt);

  await sleep(10);

  await agentService.stopChat(sessionDto.id);
  print("[stopSession] ");

  await sleep(5);

  await agentService.clearChat(sessionDto.id);
  print("[clearSession] ");
}

Future<void> sleep(int seconds) async {
  for (int i = seconds; i > 0; i--) {
    print(i);
    await Future.delayed(Duration(seconds: 1));
  }
}

LLMConfigDto _buildLLMConfig() {
  DotEnv env = DotEnv();
  env.load(['example/.env']);

  return LLMConfigDto(
    baseUrl: env["baseUrl"]!,
    apiKey: env["apiKey"]!,
    model: "gpt-3.5-turbo",
  );
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return 'You are a tools caller, who can call book system tools to help me manage my books.';
}

Future<List<OpenSpecDto>> _buildOpenSpecList() async {
  String folder =
      "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json";
  List<String> fileNameList = [
    "json-rpc-book.json"

    /// you can add more tool spec json file.
    // "json-rpc-food.json"
  ];

  List<OpenSpecDto> openSpecList = [];
  for (String fileName in fileNameList) {
    File file = File("$folder/$fileName");
    String jsonString = await file.readAsString();

    OpenSpecDto openSpecDto =
        OpenSpecDto(openSpec: jsonString, protocol: Protocol.jsonrpcHttp);

    openSpecList.add(openSpecDto);
  }

  /// If your tools interface is `HTTP API`/`json-rpc 2.0 over HTTP`/`Modbus`, REMEMBER return these ToolRunner of the tools.
  // for (String fileName in fileNameList) {
  //   File file = File("$folder/$fileName");
  //   String jsonString = await file.readAsString();
  //   OpenSpecDto openSpecDto = OpenSpecDto(openSpec: jsonString, protocol: Protocol.openapi); //<<-- Tool Protocol
  //   openSpecList.add(openSpecDto);
  // }

  return openSpecList;
}

void listen(String sessionId, AgentMessage agentMessage) {
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
  if (agentMessage.type == AgentMessageType.functionCallList) {
    List<FunctionCall> functionCallList =
        agentMessage.message as List<FunctionCall>;
    message = jsonEncode(functionCallList);
  }
  if (agentMessage.type == AgentMessageType.toolReturn) {
    message = jsonEncode(ToolReturn.fromJson(agentMessage.message));
  }
  ;

  String from = "";
  if (agentMessage.from == AgentRole.SYSTEM) {
    from = system;
    message = "\n$message";
  }
  if (agentMessage.from == AgentRole.USER) from = user;
  if (agentMessage.from == AgentRole.AGENT) from = agent;
  if (agentMessage.from == AgentRole.LLM) from = llm;
  if (agentMessage.from == AgentRole.TOOL) from = tool;
  if (agentMessage.from == AgentRole.CLIENT) from = client;

  String to = "";
  if (agentMessage.to == AgentRole.SYSTEM) to = system;
  if (agentMessage.to == AgentRole.USER) to = user;
  if (agentMessage.to == AgentRole.AGENT) to = agent;
  if (agentMessage.to == AgentRole.LLM) to = llm;
  if (agentMessage.to == AgentRole.TOOL) to = tool;
  if (agentMessage.to == AgentRole.CLIENT) to = client;

  if (from.isNotEmpty && to.isNotEmpty) {
    print("#${sessionId}# $from -> $to: [${agentMessage.type.name}] $message");
  }
}
