import 'dart:async';
import 'package:opentool_dart/opentool_dart.dart';
import 'package:uuid/uuid.dart';
import '../agents/llm/model.dart';
import '../agents/model.dart';
import '../agents/session_agent/model.dart';
import 'model.dart';
import 'agent_driver.dart';

class SessionAgentDriver extends AgentDriver {

  List<NamedSessionAgent> namedSessionAgents;

  SessionAgentDriver({required this.namedSessionAgents});

  @override
  List<FunctionModel> parse() {
    List<FunctionModel> functionModelList = [];
    namedSessionAgents.forEach((agentModel) {
      Parameter parameter = Parameter(name: promptKey, description: truncateWithEllipsis(promptDescription, llmFunctionDescriptionMaxLength), schema: Schema(type: DataType.STRING), required: true);
      FunctionModel functionModel = FunctionModel(
          name: agentModel.name,
          description: agentModel.agent.systemPrompt == null?"": truncateWithEllipsis(agentModel.agent.systemPrompt!, llmFunctionDescriptionMaxLength),
          parameters: [parameter]
      );
      functionModelList.add(functionModel);
    });
    return functionModelList;
  }

  @override
  bool hasFunction(String functionName) {
    try {
      return namedSessionAgents.where((agentModel)=>agentModel.name == functionName).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {
    try {
      String prompt = functionCall.parameters[promptKey];
      NamedSessionAgent namedSessionAgent = namedSessionAgents.where((agentModel) => agentModel.name == functionCall.name).first;
      Content content = Content(type: ContentType.TEXT, message: prompt);

      String taskId = Uuid().v4();

      Completer<AgentMessage> completer = Completer();
      void Function(AgentMessage) listen = (agentMessage) {
        if(agentMessage.taskId == taskId && agentMessage.from == AgentRoleType.AGENT && agentMessage.to == AgentRoleType.USER && agentMessage.type == AgentMessageType.TEXT) {
          completer.complete(agentMessage);
        }
      };
      namedSessionAgent.agent.agentSession.addAgentMessageListener(listen);

      namedSessionAgent.agent.userToAgent(contentList: [content], taskId: taskId);

      AgentMessage agentMessage = await completer.future;
      String result = agentMessage.message as String;

      return ToolReturn(id: functionCall.id, result: { resultKey: result });
    } catch(e) {
      return ToolReturn(id: functionCall.id, result: { "error": "Not Support agent `${functionCall.name}`" });
    }
  }

}