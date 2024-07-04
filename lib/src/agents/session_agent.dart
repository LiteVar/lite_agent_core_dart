import 'dart:async';
import 'package:opentool_dart/opentool_dart.dart';

import '../model.dart';
import '../session.dart';
import 'simple_agent.dart';

abstract class SessionAgent extends LLM {
  late AgentSession session;
  final Dispatcher _dispatcher = Dispatcher();
  final int timeoutSeconds;
  Timer? timer;

  Future<String> buildSystemMessage();

  Future<List<FunctionModel>?> buildFunctionModelList();

  SessionAgent(
      {required super.llmExecutor,
      required this.session,
      required this.timeoutSeconds});

  void userToAgent(List<Content> contentList) {
    Command clientCommand = Command(
        _toClient,
        AgentMessage(
            from: AgentRole.AGENT,
            to: AgentRole.CLIENT,
            type: AgentMessageType.text,
            message: TaskStatus.START));
    _dispatcher.dispatch(clientCommand);

    AgentMessage contentMessage = AgentMessage(
        from: AgentRole.USER,
        to: AgentRole.AGENT,
        type: AgentMessageType.contentList,
        message: contentList);

    if (session.agentMessageList.isEmpty) {
      // If session is empty, initial session.
      Command initCommand = Command(_initSystemMessage, contentMessage);
      _dispatcher.dispatch(initCommand);
    } else {
      // If session is not empty, forward to agent directly.
      toAgent(contentMessage);
    }
  }

  void toAgent(AgentMessage agentMessage) {
    session.addAgentMessage(agentMessage);

    Command? nextCommand;
    if (agentMessage.from == AgentRole.USER) {
      AgentMessage newAgentMessage = AgentMessage(
          from: AgentRole.AGENT,
          to: AgentRole.LLM,
          type: AgentMessageType.contentList,
          message: agentMessage.message as List<Content>);
      nextCommand = Command(
          _toLLM, newAgentMessage); // Forward USER messages request to LLM.
    } else if (agentMessage.from == AgentRole.LLM) {
      if (agentMessage.type == AgentMessageType.text) {
        AgentMessage agentUserMessage = AgentMessage(
            from: AgentRole.AGENT,
            to: AgentRole.USER,
            type: AgentMessageType.text,
            message: agentMessage.message);
        nextCommand = Command(
            _toUser, agentUserMessage); // If LLM return text, forward to USER.
      } else if (agentMessage.type == AgentMessageType.imageUrl) {
        AgentMessage agentUserMessage = AgentMessage(
            from: AgentRole.AGENT,
            to: AgentRole.USER,
            type: AgentMessageType.imageUrl,
            message: agentMessage.message);
        nextCommand = Command(
            _toUser, agentUserMessage); // If LLM return image, forward to USER.
      } else if (agentMessage.type == AgentMessageType.functionCallList) {
        AgentMessage agentToolMessage = AgentMessage(
            from: AgentRole.AGENT,
            to: AgentRole.TOOL,
            type: AgentMessageType.functionCallList,
            message: agentMessage.message);
        nextCommand = Command(_toTool,
            agentToolMessage); // If LLM call function, forward to TOOL.
      }
    } else if (agentMessage.from == AgentRole.TOOL) {
      if (agentMessage.type == AgentMessageType.toolReturn) {
        // If TOOL return result, add the result message
        AgentMessage agentLLMMessage = AgentMessage(
            from: AgentRole.AGENT,
            to: AgentRole.LLM,
            type: AgentMessageType.toolReturn,
            message: agentMessage.message);
        session.addAgentMessage(agentLLMMessage);
      } else if (agentMessage.type == AgentMessageType.text) {
        // If TOOL return DONE status, forward to LLM
        String toolAgentMessageText = agentMessage.message as String;
        if (toolAgentMessageText == ToolsStatus.DONE) {
          AgentMessage agentToolMessage = AgentMessage(
              from: AgentRole.AGENT,
              to: AgentRole.CLIENT,
              type: AgentMessageType.text,
              message: agentMessage.message);
          nextCommand = Command(_toLLM, agentToolMessage);
        }
      }
    }

    if (nextCommand != null) _dispatcher.dispatch(nextCommand);
  }

  Future<void> _initSystemMessage(AgentMessage agentMessage) async {
    String systemMessage = await buildSystemMessage();
    if (systemMessage.isNotEmpty) {
      AgentMessage systemAgentMessage = AgentMessage(
          from: AgentRole.SYSTEM,
          to: AgentRole.AGENT,
          type: AgentMessageType.text,
          message: systemMessage);
      toAgent(systemAgentMessage);
    }
    toAgent(agentMessage);
  }

  Future<void> _toUser(AgentMessage agentMessage) async {
    session.addAgentMessage(agentMessage);
    Command clientCommand = Command(
        _toClient,
        AgentMessage(
            from: AgentRole.AGENT,
            to: AgentRole.CLIENT,
            type: AgentMessageType.text,
            message: TaskStatus.DONE));
    _dispatcher.dispatch(clientCommand);
    startCountDown();
  }

  Future<void> _toLLM(AgentMessage agentMessage) async {
    session.addAgentMessage(agentMessage);
    List<AgentMessage> agentLLMMessageList = session.agentMessageList
        .where((AgentMessage element) =>
            element.from == AgentRole.SYSTEM ||
            element.from == AgentRole.LLM ||
            element.to == AgentRole.LLM)
        .toList();
    List<FunctionModel>? functionModelList = await buildFunctionModelList();
    AgentMessage newAgentMessage = await llmExecutor.requestLLM(
        agentMessageList: agentLLMMessageList,
        functionModelList: functionModelList);
    toAgent(newAgentMessage);
  }

  Future<void> _toTool(AgentMessage agentMessage) async {
    session.addAgentMessage(agentMessage);
    Command clientCommand = Command(
        _toClient,
        AgentMessage(
            from: AgentRole.AGENT,
            to: AgentRole.CLIENT,
            type: AgentMessageType.text,
            message: ToolsStatus.START));
    _dispatcher.dispatch(clientCommand);
    requestTools(agentMessage);
  }

  Future<void> _toClient(AgentMessage agentMessage) async {
    session.addAgentMessage(agentMessage);
  }

  Future<void> requestTools(AgentMessage agentMessage);

  void stop() {
    Command clientCommand = Command(
        _toClient,
        AgentMessage(
            from: AgentRole.AGENT,
            to: AgentRole.CLIENT,
            type: AgentMessageType.text,
            message: TaskStatus.STOP));
    _dispatcher.dispatch(clientCommand);
    _dispatcher.stop();
    startCountDown();
  }

  void clear() {
    if (_dispatcher.isListening()) {
      stop();
    }
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
  final StreamController<Command> _streamController =
      StreamController<Command>();
  late StreamSubscription<Command> _subscription;
  bool _isListening = false;

  Dispatcher() {
    if (!_streamController.hasListener) {
      _isListening = true;
      _subscription = _streamController.stream
          .listen((command) async => await command.execute());
    }
  }

  void dispatch(Command command) => command.execute();

  void stop() {
    _subscription.cancel();
    _isListening = false;
  }

  bool isListening() => _isListening;
}
