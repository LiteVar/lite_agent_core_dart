import 'dart:io' as io;
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../custom_driver/mock_driver.dart';
import '../listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenTool Driver, according to `/example/custom_driver`, which is callable.
/// 2. Add LLM baseUrl and apiKey to `.env` file
AgentService agentService = AgentService();

Future<void> main() async {

  LLMConfigDto llmConfig = _buildLLMConfig(model: "gpt-4o");

  String systemPrompt = "You play the role of a tool caller. You can help me decide which tool to call to complete the task according to my requirements. You can only call one tool at a time. \n\nYou support the following tools:\n\n 1. Translation\n 2. Add, delete, modify and query tools";
  String prompt = "Find the text with ID 0 and translate it into Chinese.";

  SessionDto sessionDto1 = await _buildTextAgent();
  SessionDto sessionDto2 = await _buildToolAgent();

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt,
    sessionList: [SessionNameDto(sessionId: sessionDto1.sessionId, name: ""), SessionNameDto(sessionId: sessionDto2.sessionId)]
  );

  SessionDto sessionDto = await agentService.initSession(capabilityDto, listen);

  UserTaskDto userTaskDto = UserTaskDto(contentList: [ContentDto(type: ContentType.TEXT, message: prompt)]);
  await agentService.startSession(sessionDto.sessionId, userTaskDto);

  await sleep(20);

  SessionTaskDto sessionTaskDto = SessionTaskDto(sessionId: sessionDto.sessionId);
  await agentService.stopSession(sessionTaskDto);
  print("[stopSession] ");

  await sleep(5);

  await agentService.clearSession(sessionDto.sessionId);
  print("[clearSession] ");
}

LLMConfigDto _buildLLMConfig({String model = "gpt-4o-mini"}) {
  DotEnv env = DotEnv();
  env.load(['example/.env']);

  return LLMConfigDto(
    baseUrl: env["baseUrl"]!,
    apiKey: env["apiKey"]!,
    model: model,
  );
}

Future<SessionDto> _buildTextAgent() async {
  LLMConfigDto llmConfig = _buildLLMConfig();

  String systemPrompt = "Playing as a translator, knowing how to translate between languages.";

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt);
  void Function(String sessionId, AgentMessageDto agentMessageDto) listen1 = (String sessionId, AgentMessageDto agentMessageDto){};
  return await agentService.initSession(capabilityDto, listen1);
}

Future<SessionDto> _buildToolAgent() async {
  LLMConfigDto llmConfig = _buildLLMConfig();

  String systemPrompt = "A storage management tool that knows how to add, delete, modify, and query my texts.";

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt);
  void Function(String sessionId, AgentMessageDto agentMessageDto) listen2 = (String sessionId, AgentMessageDto agentMessageDto){};
  return await agentService.initSession(capabilityDto, listen2, customToolDriverList: await _buildCustomDriverList());
}

Future<void> sleep(int seconds) async {
  for (int i = seconds; i > 0; i--) {
    print(i);
    await Future.delayed(Duration(seconds: 1));
  }
}

Future<List<ToolDriver>> _buildCustomDriverList() async {
  String folder = "${io.Directory.current.path}${io.Platform.pathSeparator}example${io.Platform.pathSeparator}custom_driver";
  List<String> fileNameList = [
    "mock-tool.json"
  ];

  List<ToolDriver> toolDriverList = [];
  for(String fileName in fileNameList) {
    String jsonPath = "$folder${io.Platform.pathSeparator}$fileName";
    OpenTool openTool = await OpenToolLoader().loadFromFile(jsonPath);
    OpenToolDriver mockDriver = MockDriver().bind(openTool);
    toolDriverList.add(mockDriver);
  }
  return toolDriverList;
}
