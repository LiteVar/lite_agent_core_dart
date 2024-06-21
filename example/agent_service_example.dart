import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';

String prompt = "查一下book id为1的情况";

AgentService agentService = AgentService();

Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(llmConfig: _buildLLMConfig(), systemPrompt: _buildSystemPrompt(), openSpecList: await _buildOpenSpecList());

  print("[capabilityDto] " + capabilityDto.toJson().toString());

  SessionDto sessionDto = await agentService.initChat(capabilityDto, listen);

  print("[sessionDto] " + sessionDto.toJson().toString());

  await agentService.startChat(sessionDto.id, UserMessageDto(type: UserMessageType.text, message: prompt));

  print("[prompt] " + prompt);

  await sleep(10);

  await agentService.stopChat(sessionDto.id);
  print("[stopSessionDto] ");

  await sleep(5);

  await agentService.clearChat(sessionDto.id);
  print("[clearSessionDto] ");

}

Future<void> sleep(int seconds) async {
  for(int i = seconds; i>0; i--) {
    print(i);
    await Future.delayed(Duration(seconds: 1));
  }
}

LLMConfigDto _buildLLMConfig() {
  DotEnv env = DotEnv();
  env.load();

  return LLMConfigDto(
    baseUrl: env["baseUrl"]!,
    apiKey: env["apiKey"]!,
    model: "gpt-3.5-turbo",
  );
}

String _buildSystemPrompt() {
  return '# 你可以帮我管理book和food';
  // return
  //   '# 角色和职能\n'
  //   '\n'
  //   '1. 你的角色是：PRM AI, 职能是：设备测试智能助手，公司介绍专员\n'
  //   '\n'
  //   '# 技能\n'
  //   '\n'
  //   '1. 可对AFT, ASS, AUT设备进行测试，可对LAS设备进行打印\n'
  //   '2. 可控制FCT两个抽屉分别关闭或打开，开始测试\n'
  //   '3. 可从MDC获取设备原始数据或傅里叶数据\n'
  //   '4. 可从KNLG搜索内容\n'
  //   '\n'
  //   '# 约束条件\n'
  //   '\n'
  //   '1. AFT仅当状态为"IDLE"时才能开始测试，之后可查询进度,结果或数据\n'
  //   '2. ASS或AUT仅当状态为"Idle"时才能开始测试，之后可查询进度,结果或数据\n'
  //   '3. FCT开始测试之后可获取状态和结果\n'
  //   '4. LAS设备状态为"Idle"可开始打印，之后可获取状态\n'
  //   '5. 其他信息必须使用KNLG_post工具，从结果提取message字段并显示';
}

Future<List<OpenSpecDto>> _buildOpenSpecList() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json";
  List<String> fileNameList = [
    // "AFT-merge.json",
    // "ASS-merge.json",
    // "AUT-merge.json",
    // "FCT-merge.json",
    // "LAS-merge.json",
    // "MDC-service.json",
    "json-rpc-book.json",
    "json-rpc-food.json"
  ];

  List<OpenSpecDto> openSpecList = [];
  for (String fileName in fileNameList) {
    File file = File("$folder/$fileName");
    String jsonString = await file.readAsString();

    OpenSpecDto openSpecDto = OpenSpecDto(openSpec: jsonString, protocol: Protocol.jsonrpcHttp);
    openSpecList.add(openSpecDto);
  }
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
  if(agentMessage.type == AgentMessageType.text) message = agentMessage.message as String;
  if(agentMessage.type == AgentMessageType.imageUrl) message = agentMessage.message as String;
  if(agentMessage.type == AgentMessageType.functionCallList) {
    List<dynamic> originalFunctionCallList = agentMessage.message as List<dynamic>;
    List<FunctionCall> functionCallList = originalFunctionCallList.map((dynamic json){
      return FunctionCall.fromJson(json);
    }).toList();
    message = jsonEncode(functionCallList);
  }
  if(agentMessage.type == AgentMessageType.toolReturn)  {
    message = jsonEncode(ToolReturn.fromJson(agentMessage.message));
  };

  String from = "";
  if(agentMessage.from == AgentRole.SYSTEM) {from = system ; message = "\n$message";}
  if(agentMessage.from == AgentRole.USER) from = user;
  if(agentMessage.from == AgentRole.AGENT) from = agent;
  if(agentMessage.from == AgentRole.LLM) from = llm;
  if(agentMessage.from == AgentRole.TOOL) from = tool;
  if(agentMessage.from == AgentRole.CLIENT) from = client;

  String to = "";
  if(agentMessage.to == AgentRole.SYSTEM) to = system;
  if(agentMessage.to == AgentRole.USER) to = user;
  if(agentMessage.to == AgentRole.AGENT) to = agent;
  if(agentMessage.to == AgentRole.LLM) to = llm;
  if(agentMessage.to == AgentRole.TOOL) to = tool;
  if(agentMessage.to == AgentRole.CLIENT) to = client;

  if(from.isNotEmpty && to.isNotEmpty) {
    print("#${sessionId}# $from -> $to: [${agentMessage.type.name}] $message");
  }
}