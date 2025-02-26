import 'dart:async';
import 'dart:convert';
import 'package:lite_agent_core_dart/src/agents/pipeline/pipeline.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../../agents/text_agent/text_agent.dart';
import '../llm/exception.dart';
import '../llm/openai_executor.dart';
import '../model.dart';
import '../pipeline/model.dart';
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
  late Pipeline<FunctionCallParam> toolPipeLine;

  ToolAgent({
    required super.sessionId,
    required this.toolDriverList,
    required super.llmConfig,
    required super.agentSession,
    String? super.systemPrompt,
    super.timeoutSeconds = 3600,
    List<ReflectPrompt> toolReflectPromptList = const[],
    super.taskPipelineStrategy,
    String toolPipelineStrategy = PipelineStrategyType.PARALLEL,
  }) {
    toolReflectPromptList.forEach((reflectPrompt){
      ReflectorAgent reflectorAgent = ReflectorAgent(llmExecutor: OpenAIExecutor(reflectPrompt.llmConfig), systemPrompt: reflectPrompt.prompt);
      AgentReflector agentReflector = AgentReflector(agent: reflectorAgent, subscribeCompletions: subscribeCompletions);
      toolReflectionManager.addReflector(agentReflector);
    });

    manager.registerHandler(from: TextRoleType.USER, handler: UserMessageHandler(toolReflectionManager, toLLM));//override TextAgent User handler, for save List<Content>
    manager.registerHandler(from: ToolRoleType.ASSISTANT, handler: LLMFunctionCallingMessageHandler(toolReflectionManager, toReflection, toUser, toTool)); //override TextAgent LLM handler
    manager.registerHandler(from: ToolRoleType.TOOL, handler: ToolMessageHandler(toolReflectionManager, toLLM, onToolReturn: onToolReturn));
    manager.registerHandler(from: ToolRoleType.REFLECTION, handler: ToolReflectionMessageHandler(toolReflectionManager, toLLM, toTool, onToolRetry: super.onReflectionRetry));

    toolPipeLine = Pipeline(toolPipelineStrategy);
  }

  void onToolReturn(AgentMessage agentLLMMessage) {
    agentSession.addListenAgentMessage(agentLLMMessage);
  }

  @override
  Future<void> toAgent(AgentMessage agentMessage) async {
    agentSession.addListenAgentMessage(agentMessage);
    Command? nextCommand = manager.handleMessage(agentMessage);
    if (nextCommand != null) dispatcherMap.dispatch(nextCommand);
  }

  @override
  List<AgentMessage> prepareAgentLLMMessageList(AgentMessage agentMessage) {
    List<AgentMessage> agentLLMMessageList = [];
    List<AgentMessage> sessionMessageList = List<AgentMessage>.from(agentSession.taskDoneAgentMessageList);
    List<AgentMessage> taskMessageList = dispatcherMap.getTaskMessageList(agentMessage.taskId);
    sessionMessageList.addAll(taskMessageList);
    sessionMessageList.forEach((sessionMessage){
      if( sessionMessage.role == TextRoleType.DEVELOPER ||
          sessionMessage.role == TextRoleType.ASSISTANT ||
          sessionMessage.to == TextRoleType.ASSISTANT ||
          sessionMessage.role == ToolRoleType.TOOL ) {
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
      if(super.agentSession.isStream) {
        Stream<AgentMessage> agentMessageStream = await OpenAIExecutor(llmConfig).requestByStream(agentMessageList: agentLLMMessageList, functionModelList: functionModelList,
            listenChunk: (AgentMessageChunk agentMessageChunk){
              if(agentMessageChunk.type == TextMessageType.TEXT) {
                agentMessageChunk.role = TextRoleType.AGENT;
                agentMessageChunk.to = TextRoleType.USER;
              } else if(agentMessageChunk.type == TextMessageType.TASK_STATUS) {
                agentMessageChunk.role = TextRoleType.AGENT;
                agentMessageChunk.to = TextRoleType.CLIENT;
              }
              agentSession.addListenAgentMessageChunk(agentMessageChunk);
            }
        );
        agentMessageStream.listen((newAgentMessage) {
          Command nextCommand = Command(toAgent, newAgentMessage);
          dispatcherMap.dispatch(nextCommand);
        },
          onDone: () {},
          onError: (e) {
            ExceptionMessage exceptionMessage = ExceptionMessage(code: e.code, message: e.message);
            pushException(
                agentMessage.sessionId,
                agentMessage.taskId,
                exceptionMessage
            );
          }
        );
      } else {
        AgentMessage llmMessage = await OpenAIExecutor(llmConfig).request(agentMessageList: agentLLMMessageList, functionModelList: functionModelList);
        Command nextCommand = Command(toAgent, llmMessage);
        dispatcherMap.dispatch(nextCommand);
      }
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
          role: TextRoleType.REFLECTION,
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
      FunctionCallParam functionCallParam = FunctionCallParam(sessionId: agentMessage.sessionId, taskId: agentMessage.taskId, functionCall: functionCall);
      toolPipeLine.addJob(functionCallParam);
    }

    List<String> functionCallIdList = functionCallList.map((functionCall) => functionCall.id).toList();

    toolPipeLine.run(_requestTool, onComplete: () async {
      AgentMessage toolDoneMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          role: ToolRoleType.TOOL,
          to: ToolRoleType.AGENT,
          type: ToolMessageType.TASK_STATUS,
          message: TaskStatus(status: ToolStatusType.DONE, taskId: agentMessage.taskId, description: ToolStatusDescription(functionCallIdList: functionCallIdList).toJson())
      );
      Command command = Command(toAgent, toolDoneMessage);
      dispatcherMap.dispatch(command);
    });

    // for (FunctionCall functionCall in functionCallList) {
      // try {
      //   ToolDriver toolDriver = toolDriverList.firstWhere((ToolDriver toolDriver) => toolDriver.hasFunction(functionCall.name));
      //   ToolReturn toolReturn = await toolDriver.call(functionCall);
      //   AgentMessage toolMessage = AgentMessage(
      //     sessionId: agentMessage.sessionId,
      //     taskId: agentMessage.taskId,
      //     role: ToolRoleType.TOOL,
      //     to: ToolRoleType.AGENT,
      //     type: ToolMessageType.TOOL_RETURN,
      //     message: toolReturn
      //   );
      //   Command command = Command(toAgent, toolMessage);
      //   dispatcherMap.dispatch(command);
      // } on ToolBreakException catch(e) {
      //   /** When toolDriver.call throw ToolBreakException, it will break task.*/
      //   this.dispatcherMap.breakTask(agentMessage.taskId);
      //   throw e;
      // } on StateError {
      //   /** role internal/iterable: Error thrown by, e.g., [Iterable.first] when there is no result. */
      //   Map<String, dynamic> result = FunctionNotSupportedException(functionName: functionCall.name).toJson();
      //   ToolReturn toolReturn = ToolReturn(id: functionCall.id, result: result);
      //   AgentMessage toolMessage = AgentMessage(
      //     sessionId: agentMessage.sessionId,
      //     taskId: agentMessage.taskId,
      //     role: ToolRoleType.TOOL,
      //     to: ToolRoleType.AGENT,
      //     type: ToolMessageType.TOOL_RETURN,
      //     message: toolReturn
      //   );
      //   Command command = Command(toAgent, toolMessage);
      //   dispatcherMap.dispatch(command);
      // }
    // }

  }

  Future<void> _requestTool(FunctionCallParam functionCallParam) async {
    try {
      ToolDriver toolDriver = toolDriverList.firstWhere((ToolDriver toolDriver) => toolDriver.hasFunction(functionCallParam.functionCall.name));
      ToolReturn toolReturn = await toolDriver.call(functionCallParam.functionCall);
      AgentMessage toolMessage = AgentMessage(
          sessionId: functionCallParam.sessionId,
          taskId: functionCallParam.taskId,
          role: ToolRoleType.TOOL,
          to: ToolRoleType.AGENT,
          type: ToolMessageType.TOOL_RETURN,
          message: toolReturn
      );
      Command command = Command(toAgent, toolMessage);
      dispatcherMap.dispatch(command);
    } on ToolBreakException catch(e) {
      /** When toolDriver.call throw ToolBreakException, it will break task.*/
      this.dispatcherMap.breakTask(functionCallParam.taskId);
      throw e;
    } on StateError {
      /** role internal/iterable: Error thrown by, e.g., [Iterable.first] when there is no result. */
      Map<String, dynamic> result = FunctionNotSupportedException(functionName: functionCallParam.functionCall.name).toJson();
      ToolReturn toolReturn = ToolReturn(id: functionCallParam.functionCall.id, result: result);
      AgentMessage toolMessage = AgentMessage(
          sessionId: functionCallParam.sessionId,
          taskId: functionCallParam.taskId,
          role: ToolRoleType.TOOL,
          to: ToolRoleType.AGENT,
          type: ToolMessageType.TOOL_RETURN,
          message: toolReturn
      );
      Command command = Command(toAgent, toolMessage);
      dispatcherMap.dispatch(command);
    }
  }

  Future<void> toTool(AgentMessage agentMessage) async {
    if(agentMessage.type == ToolMessageType.FUNCTION_CALL_LIST) {
      List<FunctionCall> functionCallList = agentMessage.message as List<FunctionCall>;
      List<String> functionCallIdList = functionCallList.map((functionCall) => functionCall.id).toList();
      agentSession.addListenAgentMessage(agentMessage);
      Command clientCommand = Command(
          toClient,
          AgentMessage(
              sessionId: agentMessage.sessionId,
              taskId: agentMessage.taskId,
              role: ToolRoleType.AGENT,
              to: ToolRoleType.CLIENT,
              type: ToolMessageType.TASK_STATUS,
              message: TaskStatus(status:ToolStatusType.START, taskId: agentMessage.taskId, description: ToolStatusDescription(functionCallIdList: functionCallIdList).toJson())
          ));
      dispatcherMap.dispatch(clientCommand);
      requestTools(agentMessage);
    }
  }
}
