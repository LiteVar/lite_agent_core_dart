import 'dart:async';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Add LLM baseUrl and apiKey to `.env` file

String microPythonCode = '''
      from machine import Pin
  import time
  led = Pin(25, Pin.OUT)
    led.value(1)
    time.sleep(1)
    led.value(0)
    time.sleep(1)
    ''';
String prompt = "帮我打开/dev/cu.usbmodem21101这个串口，写入$microPythonCode)，随后关闭端口";
// String prompt = "帮我看看有哪些串口可用？";

Future<void> main() async {
  String sessionId = uniqueId();
  ToolAgent toolAgent = ToolAgent(
      sessionId: sessionId,
      llmConfig: _buildLLMConfig(),
      agentSession: _buildSession(sessionId),
      toolDriverList: await _buildToolDriverList(),
      systemPrompt: _buildSystemPrompt()
  );
  String taskId = uniqueId();
  await toolAgent.userToAgent(taskId: taskId, contentList: [Content(type: ContentType.TEXT, message: prompt)]);
}

LLMConfig _buildLLMConfig() {
  DotEnv env = DotEnv();
  env.load(['example/.env']);

  return LLMConfig(
    baseUrl: env["baseUrl"]!,
    apiKey: env["apiKey"]!,
    model: "gpt-4o-mini",
  );
}

Future<List<ToolDriver>> _buildToolDriverList() async {
  List<ToolDriver> toolDriverList = [];
  SerialPortDriver serialPortDriver = SerialPortDriver();
  toolDriverList.add(serialPortDriver);
  return toolDriverList;
}

AgentSession _buildSession(String sessionId) {
  AgentSession session = AgentSession();
  session.addAgentMessageListener((AgentMessage agentMessage) {
    listen(sessionId, AgentMessageDto.fromModel(agentMessage));
  });
  return session;
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return '## 你是一个串口调用工具，你的功能包括：\n\n1. 列出可用端口：getAvailablePorts\n2. 打开端口：openPort\n3. 写入串口指令：writeCommand\n4. 读取串口数据：readData\n5. 关闭端口：closePort';
}
