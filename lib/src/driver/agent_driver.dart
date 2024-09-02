import 'dart:async';
import 'package:opentool_dart/opentool_dart.dart';
import '../agents/llm/model.dart';
import '../agents/model.dart';
import '../agents/session_agent/model.dart';
import '../service/model.dart';

class AgentDriver extends ToolDriver {
  final String promptKey = "prompt";
  final String promptDescription = "A sentence described in natural language like a human. e.g. `Help me to do something.`";
  final String resultKey = "result";

  List<AgentModel> agents;

  AgentDriver({required this.agents});

  @override
  List<FunctionModel> parse() {
    List<FunctionModel> functionModelList = [];
    agents.forEach((agentModel) {
      Parameter parameter = Parameter(name: promptKey, description: promptDescription, schema: Schema(type: DataType.STRING), required: true);
      FunctionModel functionModel = FunctionModel(
          name: agentModel.name,
          description: agentModel.agent.systemPrompt??"",
          parameters: [parameter]
      );
      functionModelList.add(functionModel);
    });
    return functionModelList;
  }

  @override
  bool hasFunction(String functionName) {
    try {
      return agents.where((agentModel)=>agentModel.name == functionName).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {
    try {
      String prompt = functionCall.parameters[promptKey];
      AgentModel agentModel = agents.where((agentModel) => agentModel.name == functionCall.name).first;
      Content content = Content(type: ContentType.TEXT, message: prompt);

      Completer<AgentMessage> completer = Completer();
      void Function(AgentMessage) listen = (agentMessage) {
        if(agentMessage.from == AgentRoleType.AGENT && agentMessage.to == AgentRoleType.USER && agentMessage.type == AgentMessageType.TEXT) {
          completer.complete(agentMessage);
        }
      };
      agentModel.agent.agentSession.addAgentMessageListener(listen);

      agentModel.agent.userToAgent(contentList: [content]);

      AgentMessage agentMessage = await completer.future;
      String result = agentMessage.message as String;

      return ToolReturn(id: functionCall.id, result: { resultKey: result });
    } catch(e) {
      return ToolReturn(id: functionCall.id, result: { "error": "Not Support agent `${functionCall.name}`" });
    }

  }

}