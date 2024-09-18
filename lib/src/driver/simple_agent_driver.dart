import 'dart:async';
import 'package:opentool_dart/opentool_dart.dart';
import '../agents/model.dart';
import '../agents/session_agent/model.dart';
import 'model.dart';
import 'agent_driver.dart';

class SimpleAgentDriver extends AgentDriver {

  List<NamedSimpleAgent> namedSimpleAgents;

  SimpleAgentDriver({required this.namedSimpleAgents});

  @override
  List<FunctionModel> parse() {
    List<FunctionModel> functionModelList = [];
    namedSimpleAgents.forEach((nameSimpleAgent) {
      Parameter parameter = Parameter(name: promptKey, description: truncateWithEllipsis(promptDescription, llmFunctionDescriptionMaxLength), schema: Schema(type: DataType.STRING), required: true);
      FunctionModel functionModel = FunctionModel(
          name: nameSimpleAgent.name,
          description: nameSimpleAgent.agent.systemPrompt == null?"": truncateWithEllipsis(nameSimpleAgent.agent.systemPrompt!, llmFunctionDescriptionMaxLength),
          parameters: [parameter]
      );
      functionModelList.add(functionModel);
    });
    return functionModelList;
  }

  @override
  bool hasFunction(String functionName) {
    try {
      return namedSimpleAgents.where((agentModel)=>agentModel.name == functionName).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {
    try {
      String prompt = functionCall.parameters[promptKey];
      NamedSimpleAgent agentModel = namedSimpleAgents.where((agentModel) => agentModel.name == functionCall.name).first;
      Content content = Content(type: ContentType.TEXT, message: prompt);

      AgentMessage agentMessage = await agentModel.agent.userToAgent(contentList: [content]);

      String result = agentMessage.message as String;

      return ToolReturn(id: functionCall.id, result: { resultKey: result });
    } catch(e) {
      return ToolReturn(id: functionCall.id, result: { "error": "Not Support agent `${functionCall.name}`" });
    }

  }

}