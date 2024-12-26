import 'dart:async';
import 'package:uuid/uuid.dart';
import '../model.dart';
import '../pipeline/model.dart';
import '../pipeline/pipeline.dart';
import 'dispatcher.dart';
import 'exception.dart';
import 'model.dart';
import 'session.dart';
import 'timeout.dart';

abstract class SessionAgent {
  String sessionId;
  String? systemPrompt;
  AgentSession agentSession;
  DispatcherMap dispatcherMap = DispatcherMap();
  late Timeout timeout;
  Pipeline<ContentsTask> pipeline;

  SessionAgent({
    required this.sessionId,
    required this.agentSession,
    this.systemPrompt,
    String taskPipelineStrategy = PipelineStrategyType.PARALLEL,
    timeoutSeconds = 600
  }) :  pipeline = Pipeline(taskPipelineStrategy),
        timeout = Timeout(timeoutSeconds);

  Future<void> userToAgent({required List<Content> contentList, String? taskId}) async {

    // pipeline.setProcess(_userToAgent, onComplete: onPipelineComplete);

    if(taskId == null) taskId = Uuid().v4();
    dispatcherMap.create(taskId);

    pipeline.addJob(ContentsTask(taskId: taskId, contentList: contentList));
    AddStatus status = await pipeline.run(_userToAgent);

    switch(status) {
      case AddStatus.REJECT: throw TaskRejectException(taskId: taskId, strategy: pipeline.pipelineStrategyType);
      case AddStatus.ERROR_STRATEGY: throw StrategyNotExistException(source: "task: $taskId", strategy: pipeline.pipelineStrategyType);
      case AddStatus.SUCCESS: break;
    }
  }

  Future<void> _userToAgent(ContentsTask contentsTask) async {
    Command clientCommand = Command(
      toClient,
      AgentMessage(
        sessionId: sessionId,
        taskId: contentsTask.taskId,
        from: SessionRoleType.AGENT,
        to: SessionRoleType.CLIENT,
        type: SessionMessageType.TASK_STATUS,
        message: TaskStatus(status: TaskStatusType.START)
      ));
    dispatcherMap.dispatch(clientCommand);

    AgentMessage contentMessage = AgentMessage(
      sessionId: sessionId,
      taskId: contentsTask.taskId,
      from: SessionRoleType.USER,
      to: SessionRoleType.AGENT,
      type: SessionMessageType.CONTENT_LIST,
      message: contentsTask.contentList
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
        type: SessionMessageType.TASK_STATUS,
        message: TaskStatus(status: TaskStatusType.STOP)
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
          type: SessionMessageType.TASK_STATUS,
          message: TaskStatus(status: TaskStatusType.STOP)
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




