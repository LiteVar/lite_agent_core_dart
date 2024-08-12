import 'dart:async';
import '../model.dart';
import 'model.dart';

class Command {
  final Future<void> Function(AgentMessage) func;
  final AgentMessage agentMessage;

  Command(this.func, this.agentMessage);

  Future<void> execute() => func(agentMessage);
}

class DispatcherMap {
  Map<String, Dispatcher> _dispatcherMap = {};
  void create(String taskId) {
    _dispatcherMap[taskId] = Dispatcher();
  }

  void dispatch(Command command) {
    _dispatcherMap[command.agentMessage.taskId]!.dispatch(command);
  }

  List<AgentMessage> getTaskMessageList(String taskId) {
    return _dispatcherMap[taskId]!._taskMessageList;
  }

  void stopAll(Future<void> Function(AgentMessage) stopFunc, Message message) {
    _dispatcherMap.forEach((taskId, dispatcher){
      if(dispatcher.isListening()) {
        AgentMessage currAgentMessage = AgentMessage(
            taskId: taskId,
            from: message.from,
            to: message.to,
            type: message.type,
            message: message.message
        );
        Command currStopCommand = Command(stopFunc, currAgentMessage);
        stop(taskId, currStopCommand);
      }
    });
  }

  void stop(String taskId, Command stopCommand) {
    stopCommand.execute();
    _dispatcherMap[taskId]!.stop();
  }

  void clear(Future<void> Function(AgentMessage) stopFunc, Message message) {
    stopAll(stopFunc, message);
    _dispatcherMap.clear();
  }
}

class Dispatcher {
  final StreamController<Command> _streamController = StreamController<Command>();
  late StreamSubscription<Command> _subscription;
  bool _isListening = false;
  late List<AgentMessage> _taskMessageList = [];
  bool _isTaskDone = false;

  Dispatcher() {
    if (!_streamController.hasListener) {
      _isListening = true;
      _subscription = _streamController.stream.listen((command) async => await command.execute());
    }
  }

  void dispatch(Command command) {
    _addTaskMessage(command.agentMessage);
    _streamController.add(command);
  }

  void _addTaskMessage(AgentMessage sessionMessage) {
    if(
        sessionMessage.to == SessionRoleType.AGENT &&
        sessionMessage.type == SessionMessageType.TEXT &&
        (sessionMessage.message as String) == TaskStatusType.DONE
    ) {
      _isTaskDone = true;
    }
    _taskMessageList.add(sessionMessage);
  }

  bool isTaskDone() => _isTaskDone;

  List<AgentMessage> getTaskMessageList() {
    return _taskMessageList;
  }

  void stop() {
    _subscription.cancel();
    _taskMessageList = [];
    _isListening = false;
  }

  bool isListening() => _isListening;
}