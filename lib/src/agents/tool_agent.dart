import 'dart:async';
import 'session_agent.dart';
import '../model.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../runner/tool_runner.dart';

class ToolAgent extends SessionAgent {
  List<ToolRunner> toolRunnerList;
  String systemPrompt;

  ToolAgent({required super.llmRunner, required super.session, required this.toolRunnerList, this.systemPrompt = "", super.timeoutSeconds = 3600});

  @override
  Future<String> buildSystemMessage() async => systemPrompt;

  @override
  Future<List<FunctionModel>?> buildFunctionModelList() async {
    List<FunctionModel> functionModelList = [];
    toolRunnerList.forEach((ToolRunner toolRunner) {
      functionModelList.addAll(toolRunner.parse());
    });
    if(functionModelList.isEmpty) return null;
    return functionModelList;
  }

  @override
  Future<void> requestTools(AgentMessage agentMessage) async {
    List<FunctionCall> functionCallList = agentMessage.message as List<FunctionCall>;

    for (FunctionCall functionCall in functionCallList) {
      ToolRunner toolRunner = toolRunnerList.firstWhere((ToolRunner toolRunner) => toolRunner.hasFunction(functionCall.name));
      ToolReturn toolResult;
      toolResult = await toolRunner.call(functionCall);
      AgentMessage toolMessage = AgentMessage(from: AgentRole.TOOL, to: AgentRole.AGENT, type: AgentMessageType.toolReturn, message: toolResult);
      toAgent(toolMessage);
    }
    toAgent(AgentMessage(from: AgentRole.TOOL, to: AgentRole.AGENT, type: AgentMessageType.text, message: ToolsStatus.DONE));
  }
}