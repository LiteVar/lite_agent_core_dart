import 'dart:async';
import 'package:opentool_dart/opentool_dart.dart';
import 'package:uuid/uuid.dart';
import '../model.dart';
import '../session.dart';
import 'simple_agent.dart';

abstract class SessionAgent extends LLM {
  late AgentSession session;
  final Map<String, Dispatcher> _dispatcherMap = {};
  final int timeoutSeconds;
  Timer? timer;

  Future<String> buildSystemMessage();

  Future<List<FunctionModel>?> buildFunctionModelList();

  SessionAgent({
    required super.llmExecutor,
    required this.session,
    required this.timeoutSeconds
  });

  void userToAgent({required List<Content> contentList, String? taskId}) {
    if(taskId == null) {
      taskId = Uuid().v4();
    }

    _dispatcherMap[taskId] = Dispatcher();  //Init dispatcher
    Command clientCommand = Command(
        _toClient,
        AgentMessage(
          taskId: taskId,
          from: AgentRole.AGENT,
          to: AgentRole.CLIENT,
          type: AgentMessageType.text,
          message: TaskStatus.START
        ));
    _dispatcherMap[taskId]!.dispatch(clientCommand);

    AgentMessage contentMessage = AgentMessage(
      taskId: taskId,
      from: AgentRole.USER,
      to: AgentRole.AGENT,
      type: AgentMessageType.contentList,
      message: contentList);

    bool hasSystemMessage = session.taskDoneAgentMessageList.any((agentMessage)=> agentMessage.from == AgentRole.SYSTEM);
    // if (session.listenAgentMessageList.isEmpty) {
    if (hasSystemMessage) {
      Command nextCommand = Command(toAgent, contentMessage);
      _dispatcherMap[taskId]!.dispatch(nextCommand);
    } else {
      Command initCommand = Command(_initSystemMessage, contentMessage);
      _dispatcherMap[taskId]!.dispatch(initCommand);
    }
  }

  Future<void> toAgent(AgentMessage agentMessage) async {
    session.addListenAgentMessage(agentMessage);

    Command? nextCommand;
    if (agentMessage.from == AgentRole.USER) {
      AgentMessage newAgentMessage = AgentMessage(
        taskId: agentMessage.taskId,
        from: AgentRole.AGENT,
        to: AgentRole.LLM,
        type: AgentMessageType.contentList,
        message: agentMessage.message as List<Content>
      );
      nextCommand = Command(_toLLM, newAgentMessage); // Forward USER messages request to LLM.
    } else if (agentMessage.from == AgentRole.LLM) {
      if (agentMessage.type == AgentMessageType.text) {
        AgentMessage agentUserMessage = AgentMessage(
          taskId: agentMessage.taskId,
          from: AgentRole.AGENT,
          to: AgentRole.USER,
          type: AgentMessageType.text,
          message: agentMessage.message
        );
        nextCommand = Command(_toUser, agentUserMessage); // If LLM return text, forward to USER.
      } else if (agentMessage.type == AgentMessageType.imageUrl) {
        AgentMessage agentUserMessage = AgentMessage(
          taskId: agentMessage.taskId,
          from: AgentRole.AGENT,
          to: AgentRole.USER,
          type: AgentMessageType.imageUrl,
          message: agentMessage.message);
        nextCommand = Command(_toUser, agentUserMessage); // If LLM return image, forward to USER.
      } else if (agentMessage.type == AgentMessageType.functionCallList) {
        AgentMessage agentToolMessage = AgentMessage(
          taskId: agentMessage.taskId,
          from: AgentRole.AGENT,
          to: AgentRole.TOOL,
          type: AgentMessageType.functionCallList,
          message: agentMessage.message
        );
        nextCommand = Command(_toTool, agentToolMessage); // If LLM call function, forward to TOOL.
      }
    } else if (agentMessage.from == AgentRole.TOOL) {
      if (agentMessage.type == AgentMessageType.toolReturn) {
        // If TOOL return result, add the result message
        AgentMessage agentLLMMessage = AgentMessage(
          taskId: agentMessage.taskId,
          from: AgentRole.AGENT,
          to: AgentRole.LLM,
          type: AgentMessageType.toolReturn,
          message: agentMessage.message);
        nextCommand = Command(_toLLM, agentLLMMessage);
        session.addListenAgentMessage(agentLLMMessage);
      } else if (agentMessage.type == AgentMessageType.text) {
        // If TOOL return DONE status, forward to LLM
        String toolAgentMessageText = agentMessage.message as String;
        if (toolAgentMessageText == ToolsStatus.DONE) {
          AgentMessage agentToolMessage = AgentMessage(
            taskId: agentMessage.taskId,
            from: AgentRole.AGENT,
            to: AgentRole.CLIENT,
            type: AgentMessageType.text,
            message: agentMessage.message
          );
          nextCommand = Command(_toClient, agentToolMessage);
        }
      }
    }

    if (nextCommand != null) _dispatcherMap[agentMessage.taskId]?.dispatch(nextCommand);
  }

  Future<void> _initSystemMessage(AgentMessage agentMessage) async {
    String systemMessage = await buildSystemMessage();
    if (systemMessage.isNotEmpty) {
      AgentMessage systemAgentMessage = AgentMessage(
        taskId: agentMessage.taskId,
        from: AgentRole.SYSTEM,
        to: AgentRole.AGENT,
        type: AgentMessageType.text,
        message: systemMessage
      );
      session.addTaskDoneAgentMessageList([systemAgentMessage]);
      // Command systemCommand = Command(toAgent, systemAgentMessage);
      // _dispatcherMap[agentMessage.taskId]!.dispatch(systemCommand);
      await toAgent(systemAgentMessage);
    }
    Command command = Command(toAgent, agentMessage);
    _dispatcherMap[agentMessage.taskId]!.dispatch(command);
    // toAgent(agentMessage);
  }

  Future<void> _toUser(AgentMessage agentMessage) async {
    session.addListenAgentMessage(agentMessage);
    Command clientCommand = Command(
        _toClient,
        AgentMessage(
          taskId: agentMessage.taskId,
          from: AgentRole.AGENT,
          to: AgentRole.CLIENT,
          type: AgentMessageType.text,
          message: TaskStatus.DONE
        ));
    _dispatcherMap[agentMessage.taskId]!.dispatch(clientCommand);
    List<AgentMessage> taskDoneMessageList = _dispatcherMap[agentMessage.taskId]!.getTaskMessageList();
    session.addTaskDoneAgentMessageList(taskDoneMessageList);
    startCountDown();
  }

  Future<void> _toLLM(AgentMessage agentMessage) async {
    session.addListenAgentMessage(agentMessage);

    List<AgentMessage> agentMessageList = List<AgentMessage>.from(session.taskDoneAgentMessageList);
    List<AgentMessage> taskMessageList = _dispatcherMap[agentMessage.taskId]!.getTaskMessageList();
    agentMessageList.addAll(taskMessageList);

    List<AgentMessage> agentLLMMessageList = [];
    agentMessageList.forEach((agentMessage){
      if(agentMessage.from == AgentRole.SYSTEM || agentMessage.from == AgentRole.LLM || agentMessage.to == AgentRole.LLM) {
        agentLLMMessageList.add(agentMessage);
      }
    });


    // // The 1st round, filter the LLM relative messages
    // session.listenAgentMessageList.forEach((agentMessage){
    //   if(agentMessage.from == AgentRole.SYSTEM || agentMessage.from == AgentRole.LLM || agentMessage.to == AgentRole.LLM) {
    //     agentLLMMessageList.add(agentMessage);
    //   }
    // });
    //
    // // The 2nd round, filter if the functionCall message all be return
    // int agentLLMMessageListSize = agentLLMMessageList.length;
    // List<AgentMessage> agentLLMMessageListWithFunctionCallBeReturn = [];
    //
    // for(int i=0; i< agentLLMMessageListSize; i++) {
    //     if(agentLLMMessageList[i].type == AgentMessageType.functionCallList) {
    //
    //       List<FunctionCall> functionCallList = agentLLMMessageList[i].message as List<FunctionCall>;
    //       List<String> functionCallIdList = functionCallList.map((functionCall)=>functionCall.id).toList();
    //
    //       // Check behind AgentMessage whether return functionCall
    //       for(int j = i+1; j< agentLLMMessageListSize; j++) {
    //         // If toolReturn id equal functionCallId, remove id from functionCallIdList, until functionCallIdList empty
    //         if(agentLLMMessageList[j].type == AgentMessageType.toolReturn) {
    //           ToolReturn toolReturn = agentLLMMessageList[j].message as ToolReturn;
    //           functionCallIdList.removeWhere((id)=> id == toolReturn.id);
    //
    //           //If functionCallIdList is Empty, the functionCallId should be return at all
    //           if(functionCallIdList.isEmpty) {
    //             agentLLMMessageListWithFunctionCallBeReturn.add(agentLLMMessageList[i]);
    //             break;
    //           }
    //         }
    //       }
    //
    //     } else {
    //       agentLLMMessageListWithFunctionCallBeReturn.add(agentLLMMessageList[i]);
    //   }
    // }

    List<FunctionModel>? functionModelList = await buildFunctionModelList();
    AgentMessage newAgentMessage = await llmExecutor.requestLLM(
      agentMessageList: agentLLMMessageList,
      functionModelList: functionModelList
    );
    Command nextCommand = Command(toAgent, newAgentMessage);
    _dispatcherMap[newAgentMessage.taskId]!.dispatch(nextCommand);
    // toAgent(newAgentMessage);
  }

  Future<void> _toTool(AgentMessage agentMessage) async {
    session.addListenAgentMessage(agentMessage);
    Command clientCommand = Command(
        _toClient,
        AgentMessage(
          taskId: agentMessage.taskId,
          from: AgentRole.AGENT,
          to: AgentRole.CLIENT,
          type: AgentMessageType.text,
          message: ToolsStatus.START
        ));
    _dispatcherMap[agentMessage.taskId]!.dispatch(clientCommand);
    requestTools(agentMessage);
  }

  Future<void> _toClient(AgentMessage agentMessage) async {
    session.addListenAgentMessage(agentMessage);
  }

  Future<void> requestTools(AgentMessage agentMessage);

  void stop(String? taskId) {
    if(taskId != null) {
      _stop(taskId);
    } else {
      _dispatcherMap.forEach((taskId, dispatcher){
        if(dispatcher.isListening()) {
          _stop(taskId);
        }
      });
    }
  }

  void _stop(String taskId) {
    Command clientCommand = Command(
        _toClient,
        AgentMessage(
            taskId: taskId,
            from: AgentRole.AGENT,
            to: AgentRole.CLIENT,
            type: AgentMessageType.text,
            message: TaskStatus.STOP
        ));
    _dispatcherMap[taskId]!.dispatch(clientCommand);
    _dispatcherMap[taskId]!.stop();
    startCountDown();
  }

  void clear() {
    _dispatcherMap.forEach((taskId, dispatcher){
      if(dispatcher.isListening()) {
        _stop(taskId);
      }
    });
    _dispatcherMap.clear();
    session.clearMessage();
    timer?.cancel();
  }

  void startCountDown() {
    timer = Timer(Duration(seconds: timeoutSeconds), () {
      clear();
    });
  }
}

class Command {
  final Future<void> Function(AgentMessage) func;
  final AgentMessage agentMessage;

  Command(this.func, this.agentMessage);

  Future<void> execute() => func(agentMessage);
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
    // command.execute();
  }

  void _addTaskMessage(AgentMessage agentMessage) {
    if(
      agentMessage.from == AgentRole.TOOL &&
      agentMessage.to == AgentRole.AGENT &&
      agentMessage.type == AgentMessageType.text &&
      (agentMessage.message as String) == TaskStatus.DONE
    ) {
      _isTaskDone = true;
    }
    _taskMessageList.add(agentMessage);
  }

  bool isTaskDone() => _isTaskDone;

  List<AgentMessage> getTaskMessageList() {
    return _taskMessageList;
  }

  void stop() {
    _subscription.cancel();
    _isListening = false;
  }

  bool isListening() => _isListening;
}
