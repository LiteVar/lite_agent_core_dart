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
  // late List<UserMessage> userMessageList;

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
            from: AgentRole.agent,
            to: AgentRole.client,
            type: AgentMessageType.text,
            message: TaskStatus.start));
    _dispatcher.dispatch(clientCommand);

    AgentMessage contentMessage = AgentMessage(
        from: AgentRole.user,
        to: AgentRole.agent,
        type: AgentMessageType.contentList,
        message: contentList);

    if (session.agentMessageList.isEmpty) {
      // 如果会话为空，初始化会话
      Command initCommand = Command(_initSystemMessage, contentMessage);
      _dispatcher.dispatch(initCommand);
    } else {
      // 否则直接分发消息
      toAgent(contentMessage);
    }
  }

  // AgentMessage _convertToAgentMessage(Content userMessage) {
  //   switch(userMessage.type) {
  //     case ContentType.text: return AgentMessage(from: AgentRole.USER, to: AgentRole.AGENT, type: AgentMessageType.text, message: userMessage.message);
  //     case ContentType.imageUrl: return AgentMessage(from: AgentRole.USER, to: AgentRole.AGENT, type: AgentMessageType.imageUrl, message: userMessage.message);
  //   }
  // }

  void toAgent(AgentMessage agentMessage) {
    session.addAgentMessage(agentMessage);

    Command? nextCommand;
    if (agentMessage.from == AgentRole.user) {
      AgentMessage newAgentMessage = AgentMessage(
          from: AgentRole.agent,
          to: AgentRole.llm,
          type: AgentMessageType.contentList,
          message: agentMessage.message as List<Content>);
      nextCommand = Command(_toLLM, newAgentMessage); //转发用户请求给大模型
    } else if (agentMessage.from == AgentRole.llm) {
      if (agentMessage.type == AgentMessageType.text) {
        AgentMessage agentUserMessage = AgentMessage(
            from: AgentRole.agent,
            to: AgentRole.user,
            type: AgentMessageType.text,
            message: agentMessage.message);
        nextCommand = Command(_toUser, agentUserMessage); // 如果大模型返回的是文字，转发给用户
      } else if (agentMessage.type == AgentMessageType.imageUrl) {
        AgentMessage agentUserMessage = AgentMessage(
            from: AgentRole.agent,
            to: AgentRole.user,
            type: AgentMessageType.imageUrl,
            message: agentMessage.message);
        nextCommand = Command(_toUser, agentUserMessage); // 如果大模型返回的是图片，转发给用户
      } else if (agentMessage.type == AgentMessageType.functionCallList) {
        AgentMessage agentToolMessage = AgentMessage(
            from: AgentRole.agent,
            to: AgentRole.tool,
            type: AgentMessageType.functionCallList,
            message: agentMessage.message);
        nextCommand =
            Command(_toTool, agentToolMessage); // 如果大模型返回的是调用参数，转发大模型的返回给工具
      }
    } else if (agentMessage.from == AgentRole.tool) {
      if (agentMessage.type == AgentMessageType.toolReturn) {
        // 如果工具返回的是结果，仅仅保留，先不处理
        AgentMessage agentLLMMessage = AgentMessage(
            from: AgentRole.agent,
            to: AgentRole.llm,
            type: AgentMessageType.toolReturn,
            message: agentMessage.message);
        session.addAgentMessage(agentLLMMessage);
      } else if (agentMessage.type == AgentMessageType.text) {
        // 如果工具返回执行结束，则通知LLM处理
        // AgentMessage agentLLMMessage = AgentMessage(from: AgentRole.AGENT, to: AgentRole.LLM, type: AgentMessageType.toolReturn_LIST, message: agentMessage.message);
        String toolAgentMessageText = agentMessage.message as String;
        if (toolAgentMessageText == ToolsStatus.done) {
          AgentMessage agentToolMessage = AgentMessage(
              from: AgentRole.agent,
              to: AgentRole.client,
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
          from: AgentRole.system,
          to: AgentRole.agent,
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
            from: AgentRole.agent,
            to: AgentRole.client,
            type: AgentMessageType.text,
            message: TaskStatus.done));
    _dispatcher.dispatch(clientCommand);
    startCountDown();
  }

  Future<void> _toLLM(AgentMessage agentMessage) async {
    session.addAgentMessage(agentMessage);
    List<AgentMessage> agentLLMMessageList = session.agentMessageList
        .where((AgentMessage element) =>
            element.from == AgentRole.system ||
            element.from == AgentRole.llm ||
            element.to == AgentRole.llm)
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
            from: AgentRole.agent,
            to: AgentRole.client,
            type: AgentMessageType.text,
            message: ToolsStatus.start));
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
            from: AgentRole.agent,
            to: AgentRole.client,
            type: AgentMessageType.text,
            message: TaskStatus.stop));
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
