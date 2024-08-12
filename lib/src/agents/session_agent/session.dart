import 'dart:async';
import '../model.dart';

class AgentSession {
  bool hasSystemMessage = false;
  List<AgentMessage> listenAgentMessageList = [];
  List<void Function(AgentMessage)> _agentMessageListenerList = [];
  List<AgentMessage> taskDoneAgentMessageList = [];

  void clearMessage() {
    hasSystemMessage = false;
    listenAgentMessageList = [];
    taskDoneAgentMessageList = [];
  }

  void resetListener() { _agentMessageListenerList = []; }

  void addAgentMessageListener(void Function(AgentMessage) agentMessageListener) {
    _agentMessageListenerList.add(agentMessageListener);
  }

  Future<void> addListenAgentMessage(AgentMessage agentMessage) async {
    listenAgentMessageList.add(agentMessage);
    _agentMessageListenerList.forEach((agentLLMMessageListener) async {
      agentLLMMessageListener(agentMessage);
    });
  }

  void addTaskDoneAgentMessageList(List<AgentMessage> agentMessageList) {
    this.taskDoneAgentMessageList.addAll(agentMessageList);
  }

}