import 'dart:async';
import 'package:opentool_dart/opentool_dart.dart';
import '../../agents/text_agent/text_agent.dart';
import '../llm/exception.dart';
import '../model.dart';
import '../llm/model.dart';
import '../session_agent/dispatcher.dart';
import '../text_agent/model.dart';
import '../tool_agent/model.dart';
import '../../driver/tool_driver.dart';

class ToolAgent extends TextAgent {
  List<ToolDriver> toolDriverList;

  ToolAgent({
    required this.toolDriverList,
    required super.llmExecutor,
    required super.agentSession,
    String? super.systemPrompt,
    super.timeoutSeconds = 3600
  });

  @override
  Future<void> toAgent(AgentMessage agentMessage) async {
    agentSession.addListenAgentMessage(agentMessage);
    Command? nextCommand = handleTextMessage(agentMessage);
    if(nextCommand == null) nextCommand = handleToolMessage(agentMessage);

    if (nextCommand != null) dispatcherMap.dispatch(nextCommand);
  }

  Command? handleToolMessage(agentMessage) {
    Command? nextCommand;
    if (agentMessage.type == ToolMessageType.FUNCTION_CALL_LIST) {
      AgentMessage agentToolMessage = AgentMessage(
        taskId: agentMessage.taskId,
        from: ToolRoleType.AGENT,
        to: ToolRoleType.TOOL,
        type: ToolMessageType.FUNCTION_CALL_LIST,
        message: agentMessage.message
      );
      nextCommand = Command(toTool, agentToolMessage); // If LLM call function, forward to TOOL.
    } else if (agentMessage.from == ToolRoleType.TOOL) {
      if (agentMessage.type == ToolMessageType.TOOL_RETURN) {
        // If TOOL return result, add the result message
        AgentMessage agentLLMMessage = AgentMessage(
          taskId: agentMessage.taskId,
          from: ToolRoleType.AGENT,
          to: TextRoleType.LLM,
          type: ToolMessageType.TOOL_RETURN,
          message: agentMessage.message
        );
        // nextCommand = Command(toLLM, agentLLMMessage);
        // Only push to listener, NOT forward to LLM until ToolsStatus.DONE
        agentSession.addListenAgentMessage(agentLLMMessage);
      } else if (agentMessage.type == ToolMessageType.TEXT) {
        // If TOOL return DONE status, forward to LLM
        String toolAgentMessageText = agentMessage.message as String;
        if (toolAgentMessageText == ToolsStatus.DONE) {
          AgentMessage agentToolMessage = AgentMessage(
            taskId: agentMessage.taskId,
            from: ToolRoleType.AGENT,
            to: ToolRoleType.CLIENT,
            type: ToolMessageType.TEXT,
            message: agentMessage.message
          );
          nextCommand = Command(toLLM, agentToolMessage);
        }
      }
    }
    return nextCommand;
  }

  @override
  List<AgentMessage> prepareAgentLLMMessageList(AgentMessage agentMessage) {
    List<AgentMessage> agentLLMMessageList = [];
    List<AgentMessage> sessionMessageList = List<AgentMessage>.from(agentSession.taskDoneAgentMessageList);
    List<AgentMessage> taskMessageList = dispatcherMap.getTaskMessageList(agentMessage.taskId);
    sessionMessageList.addAll(taskMessageList);
    sessionMessageList.forEach((sessionMessage){
      if( sessionMessage.from == TextRoleType.SYSTEM ||
          sessionMessage.from == TextRoleType.LLM ||
          sessionMessage.to == TextRoleType.LLM ||
          sessionMessage.from == ToolRoleType.TOOL ) {
        agentLLMMessageList.add(sessionMessage);
      }
    });
    return agentLLMMessageList;
  }

  @override
  Future<void> toLLM(AgentMessage agentMessage) async {
    agentSession.addListenAgentMessage(agentMessage);

    List<AgentMessage> agentLLMMessageList = prepareAgentLLMMessageList(agentMessage);
    List<FunctionModel>? functionModelList = await buildFunctionModelList();

    try {
      AgentMessage newAgentMessage = await llmExecutor.request(
          agentMessageList: agentLLMMessageList,
          functionModelList: functionModelList
      );
      Command nextCommand = Command(toAgent, newAgentMessage);
      dispatcherMap.dispatch(nextCommand);
    } on LLMException catch(e) {
      ExceptionMessage exceptionMessage = ExceptionMessage(code: e.code, message: e.message);
      pushException(agentMessage.taskId, exceptionMessage);
    }
  }

  Future<List<FunctionModel>?> buildFunctionModelList() async {
    List<FunctionModel> functionModelList = [];
    toolDriverList.forEach((ToolDriver toolDriver) {
      functionModelList.addAll(toolDriver.parse());
    });
    if (functionModelList.isEmpty) return null;
    return functionModelList;
  }

  Future<void> requestTools(AgentMessage agentMessage) async {
    List<FunctionCall> functionCallList = agentMessage.message as List<FunctionCall>;

    for (FunctionCall functionCall in functionCallList) {
      try {
        ToolDriver toolDriver = toolDriverList.firstWhere((ToolDriver toolDriver) => toolDriver.hasFunction(functionCall.name));
        ToolReturn toolReturn = await toolDriver.call(functionCall);
        AgentMessage toolMessage = AgentMessage(
          taskId: agentMessage.taskId,
          from: ToolRoleType.TOOL,
          to: ToolRoleType.AGENT,
          type: ToolMessageType.TOOL_RETURN,
          message: toolReturn
        );
        Command command = Command(toAgent, toolMessage);
        dispatcherMap.dispatch(command);
      } on StateError {
        /** FROM internal/iterable: Error thrown by, e.g., [Iterable.first] when there is no result. */
        Map<String, dynamic> result = {"error": "Function `${functionCall.name}` Not Found."};
        ToolReturn toolReturn = ToolReturn(id: functionCall.id, result: result);
        AgentMessage toolMessage = AgentMessage(
            taskId: agentMessage.taskId,
            from: ToolRoleType.TOOL,
            to: ToolRoleType.AGENT,
            type: ToolMessageType.TOOL_RETURN,
            message: toolReturn
        );
        Command command = Command(toAgent, toolMessage);
        dispatcherMap.dispatch(command);
      }
    }
    AgentMessage toolDoneMessage = AgentMessage(
      taskId: agentMessage.taskId,
      from: ToolRoleType.TOOL,
      to: ToolRoleType.AGENT,
      type: ToolMessageType.TEXT,
      message: ToolsStatus.DONE
    );
    Command command = Command(toAgent, toolDoneMessage);
    dispatcherMap.dispatch(command);
  }

  Future<void> toTool(AgentMessage agentMessage) async {
    agentSession.addListenAgentMessage(agentMessage);
    Command clientCommand = Command(
        toClient,
        AgentMessage(
          taskId: agentMessage.taskId,
          from: ToolRoleType.AGENT,
          to: ToolRoleType.CLIENT,
          type: ToolMessageType.TEXT,
          message: ToolsStatus.START
        ));
    dispatcherMap.dispatch(clientCommand);
    requestTools(agentMessage);
  }
}
