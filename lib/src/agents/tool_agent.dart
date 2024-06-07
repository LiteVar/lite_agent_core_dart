import 'dart:async';
import 'package:lite_agent_core/src/agents/session_agent.dart';
import 'package:lite_agent_core/src/model.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../tools/tool_interface.dart';

class ToolAgent extends SessionAgent {
  List<ToolRunner> toolRunnerList;
  String character = "";

  ToolAgent({required super.llmRunner, required super.session, required this.toolRunnerList});

  @override
  Future<String> buildSystemMessage() async {
    List<String> promptList = [];

    if(character.isNotEmpty ) {
      // String characterPrefix = "你所扮演的角色描述如下：\n";
      // String characterPrefix = "The role you play is described below:\n";
      // String fullCharacter = "$characterPrefix\n"
      //     "```\n"
      //     "$character\n"
      //     "```\n";
      String fullCharacter = character;
      promptList.add(fullCharacter);
    }

    String systemPrompt = "";
    promptList.forEach((prompt) {
      systemPrompt = "$systemPrompt$prompt---\n";
    });

    return systemPrompt;
  }

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

    for (var functionCall in functionCallList) {
      ToolRunner toolRunner = toolRunnerList.firstWhere((ToolRunner toolRunner) => toolRunner.hasFunction(functionCall.name));
      ToolReturn toolResult = await toolRunner.call(functionCall);
      AgentMessage toolMessage = AgentMessage(from: AgentRole.TOOL, to: AgentRole.AGENT, type: AgentMessageType.TOOL_RETURN, message: toolResult);
      toAgent(toolMessage);
    }
    toAgent(AgentMessage(from: AgentRole.TOOL, to: AgentRole.AGENT, type: AgentMessageType.TEXT, message: TOOL_RETURN_FINISH));
  }
}