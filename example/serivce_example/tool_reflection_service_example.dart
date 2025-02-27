import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../custom_driver/mock_driver.dart';
import '../listener.dart';

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
      openSpecList: await _buildOpenSpecList(),
      /// Add reflection prompt list here
      reflectPromptList: await _buildToolReflectPromptList()
  );

  print("[CapabilityDto] " + capabilityDto.toJson().toString());

  SessionDto sessionDto = await agentService.initSession(
    capabilityDto,
    listen,
    /// Add opentool Map here
    opentoolDriverMap: await _buildOpenToolDriverMap()
  );

  print("[SessionDto] " + sessionDto.toJson().toString());

  String taskId = uniqueId();
  UserTaskDto userTaskDto = UserTaskDto(taskId: taskId, contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt)]);
  await agentService.startSession(sessionDto.id, userTaskDto);

  print("[prompt] " + prompt);

  await sleep(10);

  SessionTaskDto sessionTaskDto = SessionTaskDto(id: sessionDto.id);
  await agentService.stopSession(sessionTaskDto);
  print("[stopSession] ");

  await sleep(5);

  await agentService.clearSession(sessionDto.id);
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
    model: "gpt-4o-mini",
  );
}

Future<List<OpenSpecDto>> _buildOpenSpecList() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}custom_driver";
  List<String> fileNameList = [
    "mock-tool.json"
  ];

  List<OpenSpecDto> openSpecList = [];
  for (String fileName in fileNameList) {
    File file = File("$folder${Platform.pathSeparator}$fileName");
    String jsonString = await file.readAsString();
    OpenSpecDto openSpecDto = OpenSpecDto(openSpec: jsonString, protocol: Protocol.OPENTOOL, openToolId: "mock-tool");
    openSpecList.add(openSpecDto);
  }

  return openSpecList;
}

Future<Map<String, OpenToolDriver>> _buildOpenToolDriverMap() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}custom_driver";
  List<String> fileNameList = [
    "mock-tool.json"
  ];

  Map<String, OpenToolDriver> opentoolDriverMap = {};
  for (String fileName in fileNameList) {
    String jsonPath = "$folder${Platform.pathSeparator}$fileName";
    OpenTool openTool = await OpenToolLoader().loadFromFile(jsonPath);
    OpenToolDriver opentoolDriver = MockDriver().bind(openTool);
    String opentoolId = fileName.substring(0, fileName.lastIndexOf('.'),);
    opentoolDriverMap[opentoolId] = opentoolDriver;
  }
  return opentoolDriverMap;
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return 'You are a tools caller, who can call tools to help me manage my storage.';
}

Future<List<ReflectPromptDto>> _buildToolReflectPromptList() async {
  LLMConfigDto llmConfig = _buildLLMConfig();
  String toolsDescription = await _buildToolsDescription();
  String prompt = "# Role\n\nYou are a tool reflector, you can reflect user tool usage correct or not. You should mark score 0 to 10. 10 is full score. Below is tools that user can use. \n\n$toolsDescription";
  return [
    ReflectPromptDto(llmConfig: llmConfig, prompt: prompt),
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