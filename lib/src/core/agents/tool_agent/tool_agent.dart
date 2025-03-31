import 'dart:async';
import 'dart:convert';
import 'package:opentool_dart/opentool_dart.dart';
import '../../agents/text_agent/text_agent.dart';
import '../../driver/client_driver.dart';
import '../llm/exception.dart';
import '../llm/openai_executor.dart';
import '../model.dart';
import '../pipeline/model.dart';
import '../pipeline/pipeline.dart';
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
  ClientOpenTool? clientOpenTool;

  ToolAgent({
    required super.sessionId,
    required this.toolDriverList,
    this.clientOpenTool,
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
    List<FunctionModel> functionModelList = await _buildFunctionModelList();
    if(this.clientOpenTool != null && this.clientOpenTool!.fetchClientDriver != null) {
      ClientDriver clientDriver = await _buildClientDriver(agentMessage);
      toolDriverList.add(clientDriver);
      this.clientOpenTool!.fetchClientDriver!(agentMessage.sessionId, clientDriver);
      functionModelList.addAll(clientDriver.parse());
    }

    try {
      if(super.agentSession.isStream) {
        Stream<AgentMessage> agentMessageStream = await OpenAIExecutor(llmConfig).requestByStream(agentMessageList: agentLLMMessageList, functionModelList: functionModelList, listenChunk: listenChunk);
        agentMessageStream.listen((newAgentMessage) {
          Command nextCommand = Command(toAgent, newAgentMessage);
          dispatcherMap.dispatch(nextCommand);
        },
          onDone: () {},
          onError: (e) {
            pushException(agentMessage.sessionId, agentMessage.taskId, e.toString());
          }
        );
      } else {
        AgentMessage llmMessage = await OpenAIExecutor(llmConfig).request(agentMessageList: agentLLMMessageList, functionModelList: functionModelList);
        Command nextCommand = Command(toAgent, llmMessage);
        dispatcherMap.dispatch(nextCommand);
      }
    } on LLMException catch(e) {
      pushException(agentMessage.sessionId, agentMessage.taskId, jsonEncode(e.toJson()));
    }
  }

  @override
  Future<void> toReflection(AgentMessage agentMessage) async {
    if(agentMessage.type == ToolMessageType.FUNCTION_CALL_LIST) {
      List<FunctionCall> functionCallList = agentMessage.content as List<FunctionCall>;
      List<Map<String, dynamic>> functionCallJsonList = functionCallList.map((functionCall)=>functionCall.toJson()).toList();
      Reflection reflection = await toolReflectionManager.reflect(agentMessage.type, jsonEncode(functionCallJsonList));
      AgentMessage reflectionMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          role: TextRoleType.REFLECTION,
          to: TextRoleType.AGENT,
          type: TextMessageType.REFLECTION,
          content: reflection,
          completions: currAgentReflectorCompletions
      );
      Command reflectionCommand = Command(toAgent, reflectionMessage);
      dispatcherMap.dispatch(reflectionCommand);
    } else {
      super.toReflection(agentMessage);
    }
  }

  Future<List<FunctionModel>> _buildFunctionModelList() async {
    List<FunctionModel> functionModelList = [];
    toolDriverList.forEach((ToolDriver toolDriver) {
      functionModelList.addAll(toolDriver.parse());
    });
    return functionModelList;
  }

  Future<ClientDriver> _buildClientDriver(AgentMessage agentMessage) async {
    OpenTool openTool = await OpenToolLoader().load(this.clientOpenTool!.opentool);
    void Function(FunctionCall functionCall) listenClientFunctionCall = (FunctionCall functionCall) {
      AgentMessage clientMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          role: ToolRoleType.AGENT,
          to: ToolRoleType.CLIENT,
          type: ToolMessageType.FUNCTION_CALL,
          content: functionCall
      );
      Command functionCallCommand = Command(toAgent, clientMessage);
      dispatcherMap.dispatch(functionCallCommand);
    };
    return ClientDriver(listenClientFunctionCall, timeout: clientOpenTool!.timeout??60).bind(openTool) as ClientDriver;
  }

  Future<void> requestTools(AgentMessage agentMessage) async {
    List<FunctionCall> functionCallList = agentMessage.content as List<FunctionCall>;

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
          content: TaskStatus(status: ToolStatusType.DONE, taskId: agentMessage.taskId, description: ToolStatusDescription(functionCallIdList: functionCallIdList).toJson())
      );
      Command command = Command(toAgent, toolDoneMessage);
      dispatcherMap.dispatch(command);
    });

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
          content: toolReturn
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
          content: toolReturn
      );
      Command command = Command(toAgent, toolMessage);
      dispatcherMap.dispatch(command);
    }
  }

  Future<void> toTool(AgentMessage agentMessage) async {
    if(agentMessage.type == ToolMessageType.FUNCTION_CALL_LIST) {
      List<FunctionCall> functionCallList = agentMessage.content as List<FunctionCall>;
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
              content: TaskStatus(status:ToolStatusType.START, taskId: agentMessage.taskId, description: ToolStatusDescription(functionCallIdList: functionCallIdList).toJson())
          ));
      dispatcherMap.dispatch(clientCommand);
      requestTools(agentMessage);
    }
  }
}
