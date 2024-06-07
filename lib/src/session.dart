import 'dart:async';
import 'model.dart';

class Session {
  List<AgentMessage> agentMessageList = [];
  List<void Function(AgentMessage)> _agentMessageListenerList = [];

  void resetMessage() {
    agentMessageList = [];
  }

  void resetListener() {
    _agentMessageListenerList = [];
  }

  void addAgentMessageListener(void Function(AgentMessage) agentMessageListener) {
    _agentMessageListenerList.add(agentMessageListener);
  }

  Future<void> addAgentMessage(AgentMessage agentMessage) async {
    agentMessageList.add(agentMessage);
    _agentMessageListenerList.forEach((agentLlmMessageListener) async {
      agentLlmMessageListener(agentMessage);
    });
  }
}