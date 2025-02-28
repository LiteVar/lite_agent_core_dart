import 'dto.dart';

abstract class SessionMessageManageService {
  Future<List<SessionAgentMessageDto>> getMessages();

  Future<void> addMessage(SessionAgentMessageDto agentMessageWithSessionId);
}

class AgentManageServiceByList implements SessionMessageManageService {
  List<SessionAgentMessageDto> agentMessageList = [];

  @override
  Future<void> addMessage(SessionAgentMessageDto AgentMessageWithSessionId) async {
    agentMessageList.add(AgentMessageWithSessionId);
  }

  @override
  Future<List<SessionAgentMessageDto>> getMessages() async {
    return agentMessageList;
  }
}