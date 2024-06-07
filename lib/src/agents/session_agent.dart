import 'dart:async';
import 'package:lite_agent_core/src/agents/simple_agent.dart';
import 'package:lite_agent_core/src/tools/tool_interface.dart';
import 'package:opentool_dart/opentool_dart.dart';

import '../model.dart';
import '../session.dart';

abstract class SessionAgent extends LLM {
  late Session session;
  final Dispatcher _dispatcher = Dispatcher();

  Future<String> buildSystemMessage();

  Future<List<FunctionModel>?> buildFunctionModelList();

  SessionAgent({required super.llmRunner, required this.session});

  void userToAgent(String message) {
    AgentMessage userAgentMessage = AgentMessage(from: AgentRole.USER, to: AgentRole.AGENT, type: AgentMessageType.TEXT, message: message);
    if(session.agentMessageList.isEmpty) {  // 如果会话为空，初始化会话
      Command initCommand = Command(_initSystemMessage, userAgentMessage);
      _dispatcher.dispatch(initCommand);
    } else {  // 否则直接分发消息
      toAgent(userAgentMessage);
    }
  }

  void toAgent(AgentMessage agentMessage) {
    session.addAgentMessage(agentMessage);

    Command? nextCommand;
    if(agentMessage.from == AgentRole.USER) {
      AgentMessage newAgentMessage = AgentMessage(from: AgentRole.AGENT, to: AgentRole.LLM, type: AgentMessageType.TEXT, message: agentMessage.message as String);
      nextCommand = Command(_toLLM, newAgentMessage); //转发用户请求给大模型
    } else if(agentMessage.from == AgentRole.LLM) {
      if(agentMessage.type == AgentMessageType.TEXT) {
        AgentMessage agentUserMessage = AgentMessage(from: AgentRole.AGENT, to: AgentRole.USER, type: AgentMessageType.TEXT, message: agentMessage.message);
        nextCommand = Command(_toUser, agentUserMessage); // 如果大模型返回的是文字，转发给用户
      } else if(agentMessage.type == AgentMessageType.IMAGE_URL) {
        AgentMessage agentUserMessage = AgentMessage(from: AgentRole.AGENT, to: AgentRole.USER, type: AgentMessageType.IMAGE_URL, message: agentMessage.message);
        nextCommand = Command(_toUser, agentUserMessage); // 如果大模型返回的是图片，转发给用户
      } else if(agentMessage.type == AgentMessageType.FUNCTION_CALL_LIST) {
        AgentMessage agentToolMessage = AgentMessage(from: AgentRole.AGENT, to: AgentRole.TOOL, type: AgentMessageType.FUNCTION_CALL_LIST, message: agentMessage.message);
        nextCommand = Command(_toTool, agentToolMessage); // 如果大模型返回的是调用参数，转发大模型的返回给工具
      }
    } else if(agentMessage.from == AgentRole.TOOL) {
      if(agentMessage.type == AgentMessageType.TOOL_RETURN) { // 如果工具返回的是结果，仅仅保留，先不处理
        AgentMessage agentLLMMessage = AgentMessage(from: AgentRole.AGENT, to: AgentRole.LLM, type: AgentMessageType.TOOL_RETURN, message: agentMessage.message);
        session.addAgentMessage(agentLLMMessage);
      } else if(agentMessage.type == AgentMessageType.TEXT) { // 如果工具返回执行结束，则通知LLM处理
        // AgentMessage agentLLMMessage = AgentMessage(from: AgentRole.AGENT, to: AgentRole.LLM, type: AgentMessageType.TOOL_RETURN_LIST, message: agentMessage.message);
        String toolAgentMessageText = agentMessage.message as String;
        if (toolAgentMessageText == TOOL_RETURN_FINISH) {
          AgentMessage agentToolMessage = AgentMessage(from: AgentRole.AGENT, to: AgentRole.TOOL, type: AgentMessageType.TEXT, message: agentMessage.message);
          nextCommand = Command(_toLLM, agentToolMessage);
        }
      }
    }

    if(nextCommand != null) _dispatcher.dispatch(nextCommand);
  }

  Future<void> _initSystemMessage(AgentMessage agentMessage) async {
    String systemMessage = await buildSystemMessage();
    if(systemMessage.isNotEmpty) {
      AgentMessage systemAgentMessage = AgentMessage(from: AgentRole.SYSTEM, to: AgentRole.AGENT, type: AgentMessageType.TEXT, message: systemMessage);
      toAgent(systemAgentMessage);
    }
    toAgent(agentMessage);
  }

  Future<void> _toUser(AgentMessage agentMessage) async {
    session.addAgentMessage(agentMessage);
  }

  Future<void> _toLLM(AgentMessage agentMessage) async {
    session.addAgentMessage(agentMessage);
    List<AgentMessage> agentLLMMessageList = session.agentMessageList.where((AgentMessage element) => element.from == AgentRole.SYSTEM || element.from == AgentRole.LLM || element.to == AgentRole.LLM).toList();
    List<FunctionModel>? functionModelList = await buildFunctionModelList();
    AgentMessage newAgentMessage = await llmRunner.requestLLM(agentMessageList: agentLLMMessageList, functionModelList: functionModelList);
    toAgent(newAgentMessage);
  }

  Future<void> _toTool(AgentMessage agentMessage) async {
    session.addAgentMessage(agentMessage);
    requestTools(agentMessage);
  }

  Future<void> requestTools(AgentMessage agentMessage);

  void reset() {
    _dispatcher.stop();
    session.resetMessage();
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

  Dispatcher() {
    if(!_streamController.hasListener) {
      _subscription = _streamController.stream.listen((command) async => await command.execute());
    }
  }

  void dispatch(Command command) => command.execute();

  void stop() => _subscription.cancel();
}