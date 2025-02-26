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
  PipelineAsync<ContentsTask> pipeline;

  SessionAgent({
    required this.sessionId,
    required this.agentSession,
    this.systemPrompt,
    String taskPipelineStrategy = PipelineStrategyType.PARALLEL,
    timeoutSeconds = 600
  }) :  pipeline = PipelineAsync(taskPipelineStrategy),
        timeout = Timeout(timeoutSeconds);

  Future<void> userToAgent({required List<Content> contentList, String? taskId}) async {

    if(taskId == null) taskId = Uuid().v4();
    dispatcherMap.create(taskId);

    pipeline.addJob(ContentsTask(taskId: taskId, contentList: contentList));
    AddStatusAsync statusAsync = await pipeline.runAsync(_userToAgent, asyncId: taskId);

    switch(statusAsync.addStatus) {
      case AddStatus.REJECT: {
        pipeline.completeAsync(taskId);
        Command clientCommand = Command(
          toClient,
          AgentMessage(
              sessionId: sessionId,
              taskId: taskId,
              role: SessionRoleType.AGENT,
              to: SessionRoleType.CLIENT,
              type: SessionMessageType.TASK_STATUS,
              message: TaskStatus(status: TaskStatusType.START, taskId: taskId, description: TaskRejectException(taskId: taskId, strategy: pipeline.pipelineStrategyType).toJson())
          ));
        dispatcherMap.dispatch(clientCommand);
      };
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
        role: SessionRoleType.AGENT,
        to: SessionRoleType.CLIENT,
        type: SessionMessageType.TASK_STATUS,
        message: TaskStatus(status: TaskStatusType.START, taskId: contentsTask.taskId)
      ));
    dispatcherMap.dispatch(clientCommand);

    AgentMessage contentMessage = AgentMessage(
      sessionId: sessionId,
      taskId: contentsTask.taskId,
      role: SessionRoleType.USER,
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
        role: SessionRoleType.SYSTEM,
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
      AgentMessageBase stopMessage = AgentMessageBase(
        sessionId: sessionId,
        role: SessionRoleType.AGENT,
        to: SessionRoleType.CLIENT,
        type: SessionMessageType.TASK_STATUS,
        message: TaskStatus(status: TaskStatusType.STOP, taskId: taskId??"")
      );
      dispatcherMap.stopAll(toClient, stopMessage);
    } else {
      _stop(taskId);
    }
  }

  void _stop(String taskId) {
    pipeline.completeAsync(taskId);
    Command clientCommand = Command(
        toClient,
        AgentMessage(
          sessionId: sessionId,
          taskId: taskId,
          role: SessionRoleType.AGENT,
          to: SessionRoleType.CLIENT,
          type: SessionMessageType.TASK_STATUS,
          message: TaskStatus(status: TaskStatusType.STOP, taskId: taskId)
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




