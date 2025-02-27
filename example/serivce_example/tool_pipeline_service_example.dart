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


AgentService agentService = AgentService();

Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(
      llmConfig: _buildLLMConfig(),
      systemPrompt: _buildSystemPrompt(),
      openSpecList: await _buildOpenSpecList(),
      /// Add tool pipeline strategy here
      toolPipelineStrategy: PipelineStrategyType.REJECT
  );

  print("[CapabilityDto] " + capabilityDto.toJson().toString());

  SessionDto sessionDto = await agentService.initSession(
      capabilityDto,
      listen,
      /// Add opentool Map here
      opentoolDriverMap: await _buildOpenToolDriverMap()
  );

  print("[SessionDto] " + sessionDto.toJson().toString());

  try {
    String prompt1 = "Help me set store a text 'hello1'.";
    String taskId1 = uniqueId();
    print("taskId1: $taskId1");
    UserTaskDto userTaskDto = UserTaskDto(taskId: taskId1, contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt1)]);
    await agentService.startSession(sessionDto.id, userTaskDto);
  } on TaskRejectException catch (e) {
    print(e);
  }
  try {
    String prompt2 = "Help me set store a text 'hello22'.";
    String taskId2 = uniqueId();
    print("taskId2: $taskId2");
    UserTaskDto userTaskDto = UserTaskDto(taskId: taskId2, contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt2)]);
    await agentService.startSession(sessionDto.id, userTaskDto);
  } on TaskRejectException catch (e) {
    print(e);
  }
  try {
    String prompt3 = "Help me set store a text 'hello333'.";
    String taskId3 = uniqueId();
    print("taskId3: $taskId3");
    UserTaskDto userTaskDto = UserTaskDto(taskId: taskId3, contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt3)]);
    await agentService.startSession(
        sessionDto.id,
        userTaskDto,
    );
  } on TaskRejectException catch (e) {
    print(e);
  }

  await sleep(15);

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