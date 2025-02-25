import '../model.dart';
import 'dispatcher.dart';

class AgentMessageHandlerManager {
  final Map<String, AgentMessageHandler> _strategies = {};

  void registerHandler({required String from, required AgentMessageHandler handler}) {
    _strategies[from] = handler;
  }

  Command? handleMessage(AgentMessage agentMessage) {
    var strategy = _strategies[agentMessage.role];
    return strategy?.handle(agentMessage);
  }
}

abstract class AgentMessageHandler {
  Command? handle(AgentMessage agentMessage);
}