import 'dart:async';
import 'package:uuid/uuid.dart';
import '../model.dart';
import 'dispatcher.dart';
import 'model.dart';
import 'session.dart';
import 'timeout.dart';

abstract class SessionAgent {
  String sessionId;
  String? systemPrompt;
  AgentSession agentSession;
  DispatcherMap dispatcherMap = DispatcherMap();
  late Timeout timeout;

  SessionAgent({
    required this.sessionId,
    required AgentSession agentSession,
    String? systemPrompt,
    timeoutSeconds = 600
  }) :  agentSession = agentSession,
        systemPrompt = systemPrompt,
        timeout = Timeout(timeoutSeconds);

  void userToAgent({required List<Content> contentList, String? taskId}) {
    if(taskId == null) taskId = Uuid().v4();
    dispatcherMap.create(taskId);

    Command clientCommand = Command(
        toClient,
        AgentMessage(
          sessionId: sessionId,
          taskId: taskId,
          from: SessionRoleType.AGENT,
          to: SessionRoleType.CLIENT,
          type: SessionMessageType.TEXT,
          message: TaskStatusType.START
        ));
    dispatcherMap.dispatch(clientCommand);

    AgentMessage contentMessage = AgentMessage(
        sessionId: sessionId,
        taskId: taskId,
        from: SessionRoleType.USER,
        to: SessionRoleType.AGENT,
        type: SessionMessageType.CONTENT_LIST,
        message: contentList
    );

    if ( systemPrompt == null || agentSession.hasSystemMessage ) {
      dispatcherMap.dispatch(Command(toAgent, contentMessage));
    } else {
      dispatcherMap.dispatch(Command(_initSystemMessage, contentMessage));
    }
  }

  Future<void> toAgent(AgentMessage agentMessage);

  Future<void> _initSystemMessage(AgentMessage sessionMessage) async {
    if (systemPrompt != null && systemPrompt!.isNotEmpty) {
      AgentMessage systemMessage = AgentMessage(
        sessionId: sessionMessage.sessionId,
        taskId: sessionMessage.taskId,
        from: SessionRoleType.SYSTEM,
        to: SessionRoleType.AGENT,
        type: SessionMessageType.TEXT,
        message: systemPrompt
      );
      agentSession.addTaskDoneAgentMessageList([systemMessage]);
      agentSession.hasSystemMessage = true;
      await toAgent(systemMessage);
    }
    Command command = Command(toAgent, sessionMessage);
    dispatcherMap.dispatch(command);
  }

  Future<void> toClient(AgentMessage sessionMessage) async {
    agentSession.addListenAgentMessage(sessionMessage);
  }

  void stop({String? taskId = null}) {
    if(taskId == null) {
      Message stopMessage = Message(
        sessionId: sessionId,
        from: SessionRoleType.AGENT,
        to: SessionRoleType.CLIENT,
        type: SessionMessageType.TEXT,
        message: TaskStatusType.STOP
      );
      dispatcherMap.stopAll(toClient, stopMessage);
    } else {
      _stop(taskId);
    }
  }

  void _stop(String taskId) {
    Command clientCommand = Command(
        toClient,
        AgentMessage(
          sessionId: sessionId,
          taskId: taskId,
          from: SessionRoleType.AGENT,
          to: SessionRoleType.CLIENT,
          type: SessionMessageType.TEXT,
          message: TaskStatusType.STOP
        ));
    dispatcherMap.stop(taskId, clientCommand);
    timeout.start(clear);
  }

  void clear() {
    stop();
    agentSession.clearMessage();
    timeout.clear();
  }

}




