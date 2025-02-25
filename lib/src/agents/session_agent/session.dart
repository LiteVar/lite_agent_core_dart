import 'dart:async';
import 'package:lite_agent_core_dart/lite_agent_core.dart';

import '../model.dart';

class AgentSession {
  bool hasSystemMessage = false;
  List<AgentMessage> listenAgentMessageList = [];
  List<void Function(AgentMessage)> _agentMessageListenerList = [];
  List<AgentMessage> taskDoneAgentMessageList = [];
  bool isStream;
  AgentSession({this.isStream = false});

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
    if(isStream && agentMessage.type == AgentMessageType.CHUNK) {
      _broadcast(agentMessage);
    } else if (isStream && ((agentMessage.role == AgentRoleType.LLM && agentMessage.to == AgentRoleType.AGENT) || (agentMessage.role == AgentRoleType.AGENT && agentMessage.to == AgentRoleType.USER))&& agentMessage.type == AgentMessageType.TEXT) {
      _record(agentMessage);
    } else {
      _record(agentMessage);
      _broadcast(agentMessage);
    }
  }

  void addTaskDoneAgentMessageList(List<AgentMessage> agentMessageList) {
    this.taskDoneAgentMessageList.addAll(agentMessageList);
  }

  void _record(AgentMessage agentMessage) {
    listenAgentMessageList.add(agentMessage);
  }

  void _broadcast(AgentMessage agentMessage) {
    _agentMessageListenerList.forEach((agentLLMMessageListener) async {
      agentLLMMessageListener(agentMessage);
    });
  }

}