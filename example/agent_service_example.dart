import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:opentool_dart/opentool_dart.dart';
import 'custom_driver/mock_driver.dart';
import 'listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenSpec json file, according to `/example/json/open*/*.json`, which is callable.
/// 2. Run your tool server, which is described in json file.
/// 3. Add LLM baseUrl and apiKey to `.env` file
String prompt = "Add text `Hello world`.";

AgentService agentService = AgentService();

Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(
      llmConfig: _buildLLMConfig(),
      systemPrompt: _buildSystemPrompt(),
      openSpecList: await _buildOpenSpecList()
  );

  print("[CapabilityDto] " + capabilityDto.toJson().toString());

  List<ToolDriver> customToolDriverList = await _buildCustomToolDriverList();

  SessionDto sessionDto = await agentService.initChat(capabilityDto, listen, customToolDriverList: customToolDriverList);

  print("[SessionDto] " + sessionDto.toJson().toString());

  UserTaskDto userTaskDto = UserTaskDto(taskId: "0", contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt)]);
  await agentService.startChat(sessionDto.id, userTaskDto);

  print("[prompt] " + prompt);

  await sleep(10);

  SessionTaskDto sessionTaskDto = SessionTaskDto(id: sessionDto.id);
  await agentService.stopChat(sessionTaskDto);
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
  return 'You are a tools caller, who can call storage API.';
}

Future<List<OpenSpecDto>> _buildOpenSpecList() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json${Platform.pathSeparator}openrpc";
  List<String> fileNameList = [
    "json-rpc-book.json"

    /// you can add more tool spec json file.
    // "json-rpc-food.json"
  ];

  List<OpenSpecDto> openSpecList = [];
  for (String fileName in fileNameList) {
    File file = File("$folder${Platform.pathSeparator}$fileName");
    String jsonString = await file.readAsString();

    OpenSpecDto openSpecDto = OpenSpecDto(openSpec: jsonString, protocol: Protocol.JSONRPCHTTP);

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

Future<List<ToolDriver>> _buildCustomToolDriverList() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}custom_driver";
  List<String> fileNameList = [
    "mock_tool.json"
  ];

  List<ToolDriver> toolDriverList = [];
  for (String fileName in fileNameList) {
    String jsonPath = "$folder${Platform.pathSeparator}$fileName";

    OpenTool openTool = await OpenToolLoader().loadFromFile(jsonPath);
    ToolDriver toolDriver = MockDriver(openTool);

    toolDriverList.add(toolDriver);
  }
  return toolDriverList;
}
