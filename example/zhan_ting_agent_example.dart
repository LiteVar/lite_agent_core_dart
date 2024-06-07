import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:lite_agent_core/lite_agent_core.dart';
import 'package:lite_agent_core/src/tools/tool_interface.dart';
import 'package:openapi_dart/openapi_dart.dart';
import 'package:dotenv/dotenv.dart';

String prompt = "查询AUT测试结果";

Future<void> main() async {
  ToolAgent zhanTingAgent = ToolAgent(llmRunner: _buildLLMRunner(), session: _buildSession(), toolRunnerList: await _buildToolRunnerList());
  zhanTingAgent.character = _buildCharacter();
  zhanTingAgent.userToAgent(prompt);
}

LLMRunner _buildLLMRunner() {
  DotEnv env = DotEnv();
  env.load();

  LLMConfig llmConfig = LLMConfig(
    baseUrl: env["baseUrl"]!,
    apiKey: env["apiKey"]!,
    model: "gpt-3.5-turbo",
  );
  return LLMRunner(llmConfig.baseUrl, llmConfig.apiKey, llmConfig.model);
}

Future<List<ToolRunner>> _buildToolRunnerList() async {
  String folder = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json";
  List<String> fileNameList = ["AFT-merge.json", "ASS-merge.json", "AUT-merge.json", "FCT-merge.json", "LAS-merge.json", "MDC-service.json"];

  List<ToolRunner> toolRunnerList = [];
  for (String fileName in fileNameList) {
    OpenAPI openAPI = await OpenAPILoader().loadFromFile("$folder/$fileName");
    ToolRunner toolRunner = OpenAPIRunner(openAPI);
    toolRunnerList.add(toolRunner);
  }
  return toolRunnerList;
}

Session _buildSession() {
  Session session = Session();
  session.addAgentMessageListener((AgentMessage agentMessage) {
    String system = "🖥SYSTEM";
    String user = "👤USER";
    String agent = "🤖AGENT";
    String llm = "💡LLM";
    String tool = "🔧TOOL";

    String message = "";
    if(agentMessage.type == AgentMessageType.TEXT) message = agentMessage.message as String;
    if(agentMessage.type == AgentMessageType.IMAGE_URL) message = agentMessage.message as String;
    if(agentMessage.type == AgentMessageType.FUNCTION_CALL_LIST) message = jsonEncode((agentMessage.message as List<FunctionCall>).map((functionCall) => functionCall.toJson()).toList());
    if(agentMessage.type == AgentMessageType.TOOL_RETURN) message = jsonEncode(agentMessage.message as ToolReturn);

    String from = "";
    if(agentMessage.from == AgentRole.SYSTEM) {from = system ; message = "\n$message";}
    if(agentMessage.from == AgentRole.USER) from = user;
    if(agentMessage.from == AgentRole.AGENT) from = agent;
    if(agentMessage.from == AgentRole.LLM) from = llm;
    if(agentMessage.from == AgentRole.TOOL) from = tool;

    String to = "";
    if(agentMessage.to == AgentRole.SYSTEM) to = system;
    if(agentMessage.to == AgentRole.USER) to = user;
    if(agentMessage.to == AgentRole.AGENT) to = agent;
    if(agentMessage.to == AgentRole.LLM) to = llm;
    if(agentMessage.to == AgentRole.TOOL) to = tool;

    if(from.isNotEmpty && to.isNotEmpty) {
      print("$from -> $to: [${agentMessage.type.toUpperCase()}] $message");
    }

  });
  return session;
}

String _buildCharacter() {
  return
    '# 角色和职能\n'
    '\n'
    '1. 你的角色是：PRM AI, 职能是：设备测试智能助手，公司介绍专员\n'
    '\n'
    '# 技能\n'
    '\n'
    '1. 可对AFT, ASS, AUT设备进行测试，可对LAS设备进行打印\n'
    '2. 可控制FCT两个抽屉分别关闭或打开，开始测试\n'
    '3. 可从MDC获取设备原始数据或傅里叶数据\n'
    '4. 可从KNLG搜索内容\n'
    '\n'
    '# 约束条件\n'
    '\n'
    '1. AFT仅当状态为"IDLE"时才能开始测试，之后可查询进度,结果或数据\n'
    '2. ASS或AUT仅当状态为"Idle"时才能开始测试，之后可查询进度,结果或数据\n'
    '3. FCT开始测试之后可获取状态和结果\n'
    '4. LAS设备状态为"Idle"可开始打印，之后可获取状态\n'
    '5. 其他信息必须使用KNLG_post工具，从结果提取message字段并显示';
}