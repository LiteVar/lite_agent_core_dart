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
AgentService agentService = AgentService();

Future<void> main() async {

  DotEnv env = DotEnv();env.load(['example/.env']);LLMConfigDto llmConfig = LLMConfigDto(baseUrl: env["baseUrl"]!, apiKey: env["apiKey"]!, model: "gpt-4o");

  String systemPrompt = "你扮演一位工具调用者，可以根据我的要求，帮我决定调用什么工具来完成，每次只调用1个工具。\n\n你支持如下工具：\n\n  1. 翻译\n  2. 增删改查工具";
  String prompt = "把ID为0的文本查找出来，然后把文本翻译成中文";//"第一步把ID为0的文本查找出来；第二步把步骤一的文本翻译成中文";//"帮我把文本`Helloworld`放到储存中，告诉我储存后的ID";

  SessionDto sessionDto1 = await _buildTextAgent();
  SessionDto sessionDto2 = await _buildToolAgent();

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt,
    sessionList: [sessionDto1, sessionDto2]
  );

  SessionDto sessionDto = await agentService.initChat(capabilityDto, listen);

  UserTaskDto userTaskDto = UserTaskDto(contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt)]);
  await agentService.startChat(sessionDto.id, userTaskDto);

  await sleep(20);

  SessionTaskDto sessionTaskDto = SessionTaskDto(id: sessionDto.id);
  await agentService.stopChat(sessionTaskDto);
  print("[stopSession] ");

  await sleep(5);

  await agentService.clearChat(sessionDto.id);
  print("[clearSession] ");
}

Future<SessionDto> _buildTextAgent() async {
  DotEnv env = DotEnv();env.load(['example/.env']);LLMConfigDto llmConfig = LLMConfigDto(baseUrl: env["baseUrl"]!, apiKey: env["apiKey"]!, model: "gpt-4o-mini");

  String systemPrompt = "Playing as a translator, knowing how to translate between languages.";

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt);
  void Function(String sessionId, AgentMessage agentMessage) listen1 = (String sessionId, AgentMessage agentMessage){};
  return await agentService.initChat(capabilityDto, listen1);
}

Future<SessionDto> _buildToolAgent() async {
  DotEnv env = DotEnv();env.load(['example/.env']);LLMConfigDto llmConfig = LLMConfigDto(baseUrl: env["baseUrl"]!, apiKey: env["apiKey"]!, model: "gpt-4o-mini");

  String systemPrompt = "A storage management tool that knows how to add, delete, modify, and query my texts.";

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt);
  void Function(String sessionId, AgentMessage agentMessage) listen2 = (String sessionId, AgentMessage agentMessage){};
  return await agentService.initChat(capabilityDto, listen2, customToolDriverList: await _buildCustomDriverList());
}

Future<void> sleep(int seconds) async {
  for (int i = seconds; i > 0; i--) {
    print(i);
    await Future.delayed(Duration(seconds: 1));
  }
}

Future<List<ToolDriver>> _buildCustomDriverList() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}custom_driver";
  List<String> fileNameList = [
    "mock_tool.json"
  ];

  List<ToolDriver> toolDriverList = [];
  for(String fileName in fileNameList) {
    String jsonPath = "$folder${Platform.pathSeparator}$fileName";
    OpenTool openTool = await OpenToolLoader().loadFromFile(jsonPath);
    MockDriver mockDriver = MockDriver(openTool);
    toolDriverList.add(mockDriver);
  }
  return toolDriverList;
}