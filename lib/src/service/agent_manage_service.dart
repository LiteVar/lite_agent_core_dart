import 'package:lite_agent_core_dart/lite_agent_core.dart';

import 'dto.dart';
import 'exception.dart';

abstract class AgentManageService {
  Future<List<AgentInfoDto>> getAgents();

  Future<AgentDto> getAgent(String agentId);

  Future<String> addAgent(AgentDto agentDto);

  Future<String> removeAgent(String agentId);

  Future<String> updateAgent(String agentId, AgentDto agentDto);
}

class AgentManageServiceByMap implements AgentManageService {
  Map<String, AgentDto> agents = {};

  Future<List<AgentInfoDto>> getAgents() async {
    return agents.entries.map((entry) => AgentInfoDto(agentId: entry.key, name: entry.value.name, capability: entry.value.capability)).toList();
  }

  Future<AgentDto> getAgent(String agentId) async {
    AgentDto? agent = agents[agentId];
    if (agent == null) {
      throw AgentNotFoundException(agentId: agentId);
    } else {
      return agent;
    }
  }

  Future<String> addAgent(AgentDto agentDto) async {
    String agentId = uniqueId();
    agents[agentId] = agentDto;
    return agentId;
  }

  Future<String> removeAgent(String agentId) async {
    agents.removeWhere((key, value) => key == agentId);
    return agentId;
  }

  Future<String> updateAgent(String agentId, AgentDto agentDto) async {
    agents[agentId] = agentDto;
    return agentId;
  }
}