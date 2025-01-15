import '../../llm/model.dart';
import '../llm/exception.dart';
import '../llm/openai_executor.dart';
import '../model.dart';
import '../reflection/model.dart';
import '../reflection/reflector.dart';
import '../reflection/reflector_agent.dart';
import '../reflection/reflector_manager.dart';
import '../session_agent/agent_message_handler.dart';
import '../session_agent/dispatcher.dart';
import '../session_agent/model.dart';
import '../session_agent/session_agent.dart';
import 'text_agent_message_handler.dart';
import 'model.dart';

class TextAgent extends SessionAgent {
  LLMConfig llmConfig;
  ReflectorManager reflectionManager = ReflectorManager();
  Completions? currAgentReflectorCompletions;
  late AgentMessageHandlerManager manager = AgentMessageHandlerManager();

  TextAgent({
    required super.sessionId,
    required this.llmConfig,
    required super.agentSession,
    String? super.systemPrompt,
    super.timeoutSeconds = 600,
    List<ReflectPrompt> textReflectPromptList = const [],
    super.taskPipelineStrategy,
  }) {
    textReflectPromptList.forEach((reflectPrompt){
      ReflectorAgent reflectorAgent = ReflectorAgent(llmExecutor: OpenAIExecutor(reflectPrompt.llmConfig), systemPrompt: reflectPrompt.prompt);
      AgentReflector agentReflector = AgentReflector(agent: reflectorAgent, subscribeCompletions: subscribeCompletions);
      reflectionManager.addReflector(agentReflector);
    });

    manager.registerHandler(from: TextRoleType.USER, handler: UserMessageHandler(reflectionManager, toLLM));
    manager.registerHandler(from: TextRoleType.LLM, handler: LLMMessageHandler(reflectionManager, toReflection, toUser));
    manager.registerHandler(from: TextRoleType.REFLECTION, handler: TextReflectionMessageHandler(reflectionManager, toLLM, toUser, onTextRetry: onReflectionRetry));
  }

  void subscribeCompletions(Completions? completions) {
    currAgentReflectorCompletions = completions;
  }

  @override
  Future<void> toAgent(AgentMessage agentMessage) async {
    agentSession.addListenAgentMessage(agentMessage);
    Command? nextCommand = manager.handleMessage(agentMessage);
    if (nextCommand != null) dispatcherMap.dispatch(nextCommand);
  }

  Future<void> toReflection(AgentMessage agentMessage) async {
    Reflection reflection = await reflectionManager.reflect(agentMessage.type, agentMessage.message as String);
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
  }

  void onReflectionRetry(AgentMessage agentMessage) {
    dispatcherMap.clearTaskMessageList(agentMessage.taskId);
  }

  Future<void> toUser(AgentMessage sessionMessage) async {
    agentSession.addListenAgentMessage(sessionMessage);
    AgentMessage clientMessage = AgentMessage(
      sessionId: sessionMessage.sessionId,
      taskId: sessionMessage.taskId,
      from: TextRoleType.AGENT,
      to: TextRoleType.CLIENT,
      type: TextMessageType.TASK_STATUS,
      message: TaskStatus(status: TaskStatusType.DONE, taskId: sessionMessage.taskId)
    );
    Command clientCommand = Command(toClient,clientMessage);
    dispatcherMap.dispatch(clientCommand);
    List<AgentMessage> taskDoneMessageList = dispatcherMap.getTaskMessageList(sessionMessage.taskId);
    agentSession.addTaskDoneAgentMessageList(taskDoneMessageList);
    timeout.start(clear);
  }

  List<AgentMessage> prepareAgentLLMMessageList(AgentMessage agentMessage) {
    List<AgentMessage> agentLLMMessageList = [];
    List<AgentMessage> sessionMessageList = List<AgentMessage>.from(agentSession.taskDoneAgentMessageList);
    List<AgentMessage> taskMessageList = dispatcherMap.getTaskMessageList(agentMessage.taskId);
    sessionMessageList.addAll(taskMessageList);
    sessionMessageList.forEach((sessionMessage){
      if(sessionMessage.from == TextRoleType.SYSTEM || sessionMessage.from == TextRoleType.LLM || sessionMessage.to == TextRoleType.LLM) {
        agentLLMMessageList.add(sessionMessage);
      }
    });
    return agentLLMMessageList;
  }

  Future<void> toLLM(AgentMessage agentMessage) async {
    agentSession.addListenAgentMessage(agentMessage);

    List<AgentMessage> agentLLMMessageList = prepareAgentLLMMessageList(agentMessage);
    try {
      AgentMessage newAgentMessage = await OpenAIExecutor(llmConfig).request(agentMessageList: agentLLMMessageList);
      Command nextCommand = Command(toAgent, newAgentMessage);
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

  void pushException(String sessionId, String taskId, ExceptionMessage exceptionMessage) {
    AgentMessage agentMessage = AgentMessage(
        sessionId: sessionId,
        taskId: taskId,
        from: TextRoleType.AGENT,
        to: TextRoleType.CLIENT,
        type: TextMessageType.TASK_STATUS,
        message: TaskStatus(status:TaskStatusType.STOP, taskId: taskId, description: exceptionMessage.toJson()));
    Command exceptionCommand = Command(toClient, agentMessage);
    dispatcherMap.stop(agentMessage.taskId, exceptionCommand);
  }
}