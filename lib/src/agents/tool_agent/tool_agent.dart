import 'dart:async';
import 'dart:convert';
import 'package:opentool_dart/opentool_dart.dart';
import '../../agents/text_agent/text_agent.dart';
import '../llm/exception.dart';
import '../llm/openai_executor.dart';
import '../model.dart';
import '../reflection/model.dart';
import '../reflection/reflector.dart';
import '../reflection/reflector_agent.dart';
import '../reflection/reflector_manager.dart';
import '../session_agent/dispatcher.dart';
import '../text_agent/model.dart';
import '../text_agent/text_agent_message_handler.dart';
import '../tool_agent/model.dart';
import 'tool_agent_message_handler.dart';

class ToolAgent extends TextAgent {
  List<ToolDriver> toolDriverList;
  ReflectorManager toolReflectionManager = ReflectorManager();

  ToolAgent({
    required super.sessionId,
    required this.toolDriverList,
    required super.llmConfig,
    required super.agentSession,
    String? super.systemPrompt,
    super.timeoutSeconds = 3600,
    List<ReflectPrompt> toolReflectPromptList = const[]
  }) {
    toolReflectPromptList.forEach((reflectPrompt){
      ReflectorAgent reflectorAgent = ReflectorAgent(llmExecutor: OpenAIExecutor(reflectPrompt.llmConfig), systemPrompt: reflectPrompt.prompt);
      AgentReflector agentReflector = AgentReflector(agent: reflectorAgent, subscribeCompletions: subscribeCompletions);
      toolReflectionManager.addReflector(agentReflector);
    });

    manager.registerHandler(from: TextRoleType.USER, handler: UserMessageHandler(toolReflectionManager, toLLM));//override TextAgent User handler, for save List<Content>
    manager.registerHandler(from: ToolRoleType.LLM, handler: LLMFunctionCallingMessageHandler(toolReflectionManager, toReflection, toUser, toTool)); //override TextAgent LLM handler
    manager.registerHandler(from: ToolRoleType.TOOL, handler: ToolMessageHandler(toolReflectionManager, toLLM, onToolReturn: onToolReturn));
    manager.registerHandler(from: ToolRoleType.REFLECTION, handler: ToolReflectionMessageHandler(toolReflectionManager, toLLM, toTool, onToolRetry: super.onReflectionRetry));
  }

  void onToolReturn(AgentMessage agentLLMMessage) {
    agentSession.addListenAgentMessage(agentLLMMessage);
  }

  @override
  Future<void> toAgent(AgentMessage agentMessage) async {
    agentSession.addListenAgentMessage(agentMessage);
    // Command? nextCommand = handleTextMessage(agentMessage);
    // if(nextCommand == null) nextCommand = handleToolMessage(agentMessage);
    Command? nextCommand = manager.handleMessage(agentMessage);
    if (nextCommand != null) dispatcherMap.dispatch(nextCommand);
  }

  // Command? handleToolMessage(agentMessage) {
    // Command? nextCommand;
    // if (agentMessage.type == ToolMessageType.FUNCTION_CALL_LIST) {
    //   AgentMessage agentToolMessage = AgentMessage(
    //     sessionId: agentMessage.sessionId,
    //     taskId: agentMessage.taskId,
    //     from: ToolRoleType.AGENT,
    //     to: ToolRoleType.TOOL,
    //     type: ToolMessageType.FUNCTION_CALL_LIST,
    //     message: agentMessage.message
    //   );
    //   nextCommand = Command(toTool, agentToolMessage); // If LLM call function, forward to TOOL.
    // } else if (agentMessage.from == ToolRoleType.TOOL) {
    //   if (agentMessage.type == ToolMessageType.TOOL_RETURN) {
    //     // If TOOL return result, add the result message
    //     AgentMessage agentLLMMessage = AgentMessage(
    //       sessionId: agentMessage.sessionId,
    //       taskId: agentMessage.taskId,
    //       from: ToolRoleType.AGENT,
    //       to: TextRoleType.LLM,
    //       type: ToolMessageType.TOOL_RETURN,
    //       message: agentMessage.message
    //     );
    //     // nextCommand = Command(toLLM, agentLLMMessage);
    //     // Only push to listener, NOT forward to LLM until ToolsStatus.DONE
    //     agentSession.addListenAgentMessage(agentLLMMessage);
    //   } else if (agentMessage.type == ToolMessageType.TEXT) {
    //     // If TOOL return DONE status, forward to LLM
    //     String toolAgentMessageText = agentMessage.message as String;
    //     if (toolAgentMessageText == ToolsStatus.DONE) {
    //       AgentMessage agentToolMessage = AgentMessage(
    //         sessionId: agentMessage.sessionId,
    //         taskId: agentMessage.taskId,
    //         from: ToolRoleType.AGENT,
    //         to: ToolRoleType.CLIENT,
    //         type: ToolMessageType.TEXT,
    //         message: agentMessage.message
    //       );
    //       nextCommand = Command(toLLM, agentToolMessage);
    //     }
    //   }
    // }
    // return nextCommand;
  // }

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
      AgentMessage llmMessage = await OpenAIExecutor(llmConfig).request(
          agentMessageList: agentLLMMessageList,
          functionModelList: functionModelList
      );
      Command nextCommand = Command(toAgent, llmMessage);
      dispatcherMap.dispatch(nextCommand);
    } on LLMException catch(e) {
      ExceptionMessage exceptionMessage = ExceptionMessage(code: e.code, message: e.message);
      pushException(
          agentMessage.sessionId,
          agentMessage.taskId,
          exceptionMessage
      );
    }
  }

  @override
  Future<void> toReflection(AgentMessage agentMessage) async {
    if(agentMessage.type == ToolMessageType.FUNCTION_CALL_LIST) {
      List<FunctionCall> functionCallList = agentMessage.message as List<FunctionCall>;
      List<Map<String, dynamic>> functionCallJsonList = functionCallList.map((functionCall)=>functionCall.toJson()).toList();
      Reflection reflection = await toolReflectionManager.reflect(agentMessage.type, jsonEncode(functionCallJsonList));
      // reflection.completions = currAgentReflectorCompletions;
      AgentMessage reflectionMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          from: TextRoleType.REFLECTION,
          to: TextRoleType.AGENT,
          type: TextMessageType.REFLECTION,
          message: reflection,
          completions: currAgentReflectorCompletions
      );
      Command reflectionCommand = Command(toAgent, reflectionMessage);
      dispatcherMap.dispatch(reflectionCommand);
    } else {
      super.toReflection(agentMessage);
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
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          from: ToolRoleType.TOOL,
          to: ToolRoleType.AGENT,
          type: ToolMessageType.TOOL_RETURN,
          message: toolReturn
        );
        Command command = Command(toAgent, toolMessage);
        dispatcherMap.dispatch(command);
      } on ToolBreakException catch(e) {
        /** When toolDriver.call throw ToolBreakException, it will break task.*/
        this.dispatcherMap.breakTask(agentMessage.taskId);
        throw e;
      } on StateError {
        /** FROM internal/iterable: Error thrown by, e.g., [Iterable.first] when there is no result. */
        Map<String, dynamic> result = FunctionNotSupportedException(functionName: functionCall.name).toJson();
        ToolReturn toolReturn = ToolReturn(id: functionCall.id, result: result);
        AgentMessage toolMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
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
      sessionId: agentMessage.sessionId,
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
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          from: ToolRoleType.AGENT,
          to: ToolRoleType.CLIENT,
          type: ToolMessageType.TASK_STATUS,
          message: TaskStatus(status:ToolsStatus.START)
        ));
    dispatcherMap.dispatch(clientCommand);
    requestTools(agentMessage);
  }
}
