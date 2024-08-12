import 'dart:convert';
import '../llm/exception.dart';
import '../model.dart';
import '../llm/llm_executor.dart';
import '../session_agent/dispatcher.dart';
import '../session_agent/model.dart';
import '../session_agent/session_agent.dart';
import 'model.dart';

class TextAgent extends SessionAgent {
  LLMExecutor llmExecutor;

  TextAgent({
    required this.llmExecutor,
    required super.agentSession,
    String? super.systemPrompt,
    super.timeoutSeconds = 600
  });

  @override
  Future<void> toAgent(AgentMessage agentMessage) async {
    agentSession.addListenAgentMessage(agentMessage);
    Command? nextCommand = handleTextMessage(agentMessage);
    if (nextCommand != null) dispatcherMap.dispatch(nextCommand);
  }

  Command? handleTextMessage(AgentMessage agentMessage) {
    Command? nextCommand;
    if (agentMessage.from == TextRoleType.USER) {
      AgentMessage newAgentMessage = AgentMessage(
          taskId: agentMessage.taskId,
          from: TextRoleType.AGENT,
          to: TextRoleType.LLM,
          type: TextMessageType.CONTENT_LIST,
          message: agentMessage.message as List<Content>
      );
      nextCommand = Command(toLLM, newAgentMessage); // Forward USER messages request to LLM.
    } else if (agentMessage.from == TextRoleType.LLM) {
      if (agentMessage.type == TextMessageType.TEXT) {
        AgentMessage agentUserMessage = AgentMessage(
            taskId: agentMessage.taskId,
            from: TextRoleType.AGENT,
            to: TextRoleType.USER,
            type: TextMessageType.TEXT,
            message: agentMessage.message
        );
        nextCommand = Command(toUser, agentUserMessage); // If LLM return text, forward to USER.
      } else if (agentMessage.type == TextMessageType.IMAGE_URL) {
        AgentMessage agentUserMessage = AgentMessage(
            taskId: agentMessage.taskId,
            from: TextRoleType.AGENT,
            to: TextRoleType.USER,
            type: TextMessageType.IMAGE_URL,
            message: agentMessage.message);
        nextCommand = Command(toUser, agentUserMessage); // If LLM return image, forward to USER.
      }
    }
    return nextCommand;
  }

  Future<void> toUser(AgentMessage sessionMessage) async {
    agentSession.addListenAgentMessage(sessionMessage);
    Command clientCommand = Command(
        toClient,
        AgentMessage(
            taskId: sessionMessage.taskId,
            from: TextRoleType.AGENT,
            to: TextRoleType.CLIENT,
            type: TextMessageType.TEXT,
            message: TaskStatusType.DONE
        ));
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
      AgentMessage newAgentMessage = await llmExecutor.request(agentMessageList: agentLLMMessageList);
      Command nextCommand = Command(toAgent, newAgentMessage);
      dispatcherMap.dispatch(nextCommand);
    } on LLMException catch(e) {
      ExceptionMessage exceptionMessage = ExceptionMessage(code: e.code, message: e.message);
      pushException(agentMessage.taskId, exceptionMessage);
    }
  }

  void pushException(String taskId, ExceptionMessage exceptionMessage) {
    AgentMessage agentMessage = AgentMessage(
        taskId: taskId,
        from: TextRoleType.AGENT,
        to: TextRoleType.CLIENT,
        type: TextMessageType.TEXT,
        message: TaskStatusType.STOP + jsonEncode(exceptionMessage.toJson()));
    Command exceptionCommand = Command(toClient, agentMessage);
    dispatcherMap.stop(agentMessage.taskId, exceptionCommand);
  }
}