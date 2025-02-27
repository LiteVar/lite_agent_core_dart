import 'dart:async';
import 'dart:io';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';
import 'package:dotenv/dotenv.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../listener.dart';
import 'package:opendyn_dart/opendyn_dart.dart' as od;

/// [IMPORTANT] Prepare:
/// 1. Add LLM baseUrl and apiKey to `.env` file

String prompt = "help me call tools to calculate 28+36";

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
  String jsonFileName = "calculate.json";
  String jsonPath = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}json${Platform.pathSeparator}opendyn${Platform.pathSeparator}$jsonFileName";

  od.OpenDyn openDyn = await od.OpenDynLoader().loadFromFile(jsonPath);

  String dynFileName = "libexample.dll"; // Windows
  if(Platform.isMacOS) {
    var result = await Process.run('uname', ['-m']);
    if (result.stdout.toString().trim() == 'arm64') {
      dynFileName = "libexample_arm64.dylib"; // macOS ARM
    } else {
      dynFileName = "libexample_x86_64.dylib"; // macOS Intel
    }
  } else if(Platform.isLinux) {
    dynFileName = "libexample.so"; // Linux
  }
  File dynFile = File("${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}driver_example${Platform.pathSeparator}dyns${Platform.pathSeparator}$dynFileName");
  OpenDynDriver openDynDriver = OpenDynDriver(openDyn: openDyn, dynFile: dynFile);
  toolDriverList.add(openDynDriver);
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
  return '## You are a calculate tool. Your functions include: \n\n1. add\n2. multiply';
}
