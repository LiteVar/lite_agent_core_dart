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

  // Command? handleTextMessage(AgentMessage agentMessage) {
    // AgentMessageHandlerManager manager = AgentMessageHandlerManager();
    // manager.registerHandler(TextRoleType.USER, UserMessageHandler(reflectionManager, toLLM));
    // manager.registerHandler(TextRoleType.LLM, LLMMessageHandler(reflectionManager, toReflection, toUser));
    // manager.registerHandler(TextRoleType.REFLECTION, ReflectionMessageHandler(reflectionManager, toLLM, toUser, onRetry: ()=>dispatcherMap.clearTaskMessageList(agentMessage.taskId)));
    // return manager.handleMessage(agentMessage);
    // Command? nextCommand;
    // if (agentMessage.from == TextRoleType.USER) {
    //   List<Content> userContentList = agentMessage.message as List<Content>;
    //   AgentMessage newAgentMessage = AgentMessage(
    //     sessionId: agentMessage.sessionId,
    //     taskId: agentMessage.taskId,
    //     from: TextRoleType.AGENT,
    //     to: TextRoleType.LLM,
    //     type: TextMessageType.CONTENT_LIST,
    //     message: userContentList
    //   );
    //   if(reflectionManager.shouldReflect) { // if Reflection, reset reflectionManager
    //     reflectionManager.reset();
    //     reflectionManager.userContentList = userContentList;
    //   }
    //   nextCommand = Command(toLLM, newAgentMessage); // Forward USER messages request to LLM.
    // } else if (agentMessage.from == TextRoleType.LLM) {
    //   if (agentMessage.type == TextMessageType.TEXT) {
    //     if(reflectionManager.shouldReflect) {
    //       AgentMessage reflectionMessage = AgentMessage(
    //           sessionId: agentMessage.sessionId,
    //           taskId: agentMessage.taskId,
    //           from: TextRoleType.AGENT,
    //           to: TextRoleType.REFLECTION,
    //           type: TextMessageType.TEXT,
    //           message: agentMessage.message
    //       );
    //       nextCommand = Command(toReflection, reflectionMessage); // If LLM return text, and should reflect, forward to REFLECTION.
    //     } else {
    //       AgentMessage agentUserMessage = AgentMessage(
    //           sessionId: agentMessage.sessionId,
    //           taskId: agentMessage.taskId,
    //           from: TextRoleType.AGENT,
    //           to: TextRoleType.USER,
    //           type: TextMessageType.TEXT,
    //           message: agentMessage.message
    //       );
    //       nextCommand = Command(toUser, agentUserMessage); // If LLM return text and NOT reflect, forward to USER.
    //     }
    //   } else if (agentMessage.type == TextMessageType.IMAGE_URL) {
    //     AgentMessage agentUserMessage = AgentMessage(
    //       sessionId: agentMessage.sessionId,
    //       taskId: agentMessage.taskId,
    //       from: TextRoleType.AGENT,
    //       to: TextRoleType.USER,
    //       type: TextMessageType.IMAGE_URL,
    //       message: agentMessage.message);
    //     nextCommand = Command(toUser, agentUserMessage); // If LLM return image, forward to USER.
    //   } else if(agentMessage.type == TextMessageType.REFLECTION) {
    //     Reflection reflection = agentMessage.message as Reflection;
    //     if(reflection.result.isPass || reflection.result.count == reflection.result.maxCount) {
    //       AgentMessage agentUserMessage = AgentMessage(
    //           sessionId: agentMessage.sessionId,
    //           taskId: agentMessage.taskId,
    //           from: TextRoleType.AGENT,
    //           to: TextRoleType.USER,
    //           type: TextMessageType.TEXT,
    //           message: reflection.result.messageScore.message
    //       );
    //       nextCommand = Command(toUser, agentUserMessage); // If Reflection pass or maxCount, forward to USER.
    //     } else {
    //       List<Content> userContentList = reflectionManager.userContentList;
    //       AgentMessage newAgentMessage = AgentMessage(
    //           sessionId: agentMessage.sessionId,
    //           taskId: agentMessage.taskId,
    //           from: TextRoleType.AGENT,
    //           to: TextRoleType.LLM,
    //           type: TextMessageType.CONTENT_LIST,
    //           message: userContentList
    //       );
    //       if(reflectionManager.shouldReflect) {
    //         dispatcherMap.clearTaskMessageList(agentMessage.taskId);
    //         reflectionManager.reset();
    //         reflectionManager.userContentList = userContentList;
    //       }
    //       nextCommand = Command(toLLM, newAgentMessage); // Reset User messages request to LLM.
    //     }
    //   }
    // }
    // return nextCommand;
  // }

  Future<void> toUser(AgentMessage sessionMessage) async {
    agentSession.addListenAgentMessage(sessionMessage);
    AgentMessage clientMessage = AgentMessage(
      sessionId: sessionMessage.sessionId,
      taskId: sessionMessage.taskId,
      from: TextRoleType.AGENT,
      to: TextRoleType.CLIENT,
      type: TextMessageType.TASK_STATUS,
      message: TaskStatus(status: TaskStatusType.DONE)
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
        message: TaskStatus(status:TaskStatusType.STOP, description: exceptionMessage.toJson()));
    Command exceptionCommand = Command(toClient, agentMessage);
    dispatcherMap.stop(agentMessage.taskId, exceptionCommand);
  }
}