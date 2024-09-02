import 'dart:async';
import 'package:lite_agent_core_dart/src/service/model.dart';
import 'package:lite_agent_core_dart/src/service/exception.dart';
import 'package:uuid/uuid.dart';
import 'package:opentool_dart/opentool_dart.dart';
import 'package:openapi_dart/openapi_dart.dart';
import 'package:openmodbus_dart/openmodbus_dart.dart';
import 'package:openrpc_dart/openrpc_dart.dart';
import '../agents/model.dart';
import '../agents/llm/llm_executor.dart';
import '../agents/llm/openai_executor.dart';
import '../agents/session_agent/session.dart';
import '../agents/session_agent/model.dart';
import '../agents/text_agent/text_agent.dart';
import '../agents/tool_agent/tool_agent.dart';
import '../driver/agent_driver.dart';
import '../llm/model.dart';
import 'dto.dart';

class AgentService {
  Map<String, TextAgent> agents = {};
  List<ToolDriver> globalDriverList = [];

  AgentService({List<ToolDriver>? globalToolDriverList = null}) {
    if(globalToolDriverList != null) globalDriverList.addAll(globalToolDriverList);
  }

  Future<SessionDto> initChat(CapabilityDto capabilityDto, void Function(String sessionId, AgentMessage agentMessage) listen, {List<ToolDriver>? customToolDriverList}) async {
    String sessionId = Uuid().v4();
    String systemPrompt = capabilityDto.systemPrompt;
    LLMConfig llmConfig = capabilityDto.llmConfig.toModel();

    List<ToolDriver> agentToolDriverList = [];
    agentToolDriverList.addAll(globalDriverList);
    agentToolDriverList.addAll(await buildToolDriverList(capabilityDto.openSpecList));
    agentToolDriverList.addAll(await buildAgentDriverList(capabilityDto.sessionList, sessionId, listen));
    if(customToolDriverList != null) agentToolDriverList.addAll(customToolDriverList);

    if(agentToolDriverList.isEmpty) {
      TextAgent textAgent = TextAgent(
        sessionId: sessionId,
        llmExecutor: _buildLLMExecutor(llmConfig),
        agentSession: _buildSession(sessionId, listen),
        systemPrompt: systemPrompt,
        timeoutSeconds: capabilityDto.timeoutSeconds
      );
      agents[sessionId] = textAgent;
    } else {
      TextAgent toolAgent = ToolAgent(
        sessionId: sessionId,
        llmExecutor: _buildLLMExecutor(llmConfig),
        agentSession: _buildSession(sessionId, listen),
        toolDriverList: agentToolDriverList,
        systemPrompt: systemPrompt,
        timeoutSeconds: capabilityDto.timeoutSeconds
      );
      agents[sessionId] = toolAgent;
    }

    SessionDto sessionDto = SessionDto(id: sessionId);

    return sessionDto;
  }

  Future<void> startChat(String sessionId, UserTaskDto userTaskDto) async {
    TextAgent toolAgent = agents[sessionId]!;
    List<Content> userMessageList = userTaskDto.contentList
      .map((userMessageDto) => _convertToContent(userMessageDto))
      .toList();
    toolAgent.userToAgent(taskId: userTaskDto.taskId, contentList: userMessageList);
  }

  Future<List<AgentMessageDto>?> getHistory(String sessionId) async {
    TextAgent? toolAgent = agents[sessionId];
    if (toolAgent == null) return null;
    return toolAgent
      .agentSession
      .listenAgentMessageList
      .map((AgentMessage agentMessage) {
        AgentMessageDto agentMessageDto = AgentMessageDto.fromModel(agentMessage);
      return agentMessageDto;
    }).toList();
  }

  Future<void> stopChat(SessionTaskDto sessionTaskDto) async {
    TextAgent textAgent = agents[sessionTaskDto.id]!;
    textAgent.stop(taskId: sessionTaskDto.taskId);
  }

  Future<void> clearChat(String sessionId) async {
    TextAgent textAgent = agents[sessionId]!;
    textAgent.clear();
    agents.remove(sessionId);
  }

  Content _convertToContent(UserMessageDto userMessageDto) {
    switch (userMessageDto.type) {
      case UserMessageDtoType.text:
        return Content(type: ContentType.TEXT, message: userMessageDto.message);
      case UserMessageDtoType.imageUrl:
        return Content(
            type: ContentType.IMAGE_URL, message: userMessageDto.message);
    }
  }

  LLMExecutor _buildLLMExecutor(LLMConfig llmConfig) => OpenAIExecutor(llmConfig);

  AgentSession _buildSession(String sessionId, void Function(String sessionId, AgentMessage agentMessage) listen) {
    AgentSession agentSession = AgentSession();
    agentSession.addAgentMessageListener((AgentMessage agentMessage) {
      listen(sessionId, agentMessage);
    });
    return agentSession;
  }

  Future<List<ToolDriver>> buildToolDriverList(List<OpenSpecDto>? openSpecDtoList) async {
    if(openSpecDtoList == null) return [];
    List<ToolDriver> toolDriverList = [];
    for (OpenSpecDto openSpecDto in openSpecDtoList) {
      if (openSpecDto.protocol == Protocol.OPENAPI) {
        OpenAPI openAPI = await OpenAPILoader().load(openSpecDto.openSpec);
        String? authorization;
        if (openSpecDto.apiKey != null) {
          convertToAuthorization(openSpecDto.apiKey!.type, openSpecDto.apiKey!.apiKey);
        }
        ToolDriver openAPIRunner = OpenAPIDriver(openAPI, authorization: authorization);
        toolDriverList.add(openAPIRunner);
      } else if (openSpecDto.protocol == Protocol.OPENMODBUS) {
        OpenModbus openModbus = await OpenModbusLoader().load(openSpecDto.openSpec);
        ToolDriver openModbusRunner = OpenModbusDriver(openModbus);
        toolDriverList.add(openModbusRunner);
      } else if (openSpecDto.protocol == Protocol.JSONRPCHTTP) {
        OpenRPC openRPC = await OpenRPCLoader().load(openSpecDto.openSpec);
        ToolDriver jsonrpcHttpRunner = JsonRPCDriver(openRPC);
        toolDriverList.add(jsonrpcHttpRunner);
      }
    }
    return toolDriverList;
  }

  Future<List<ToolDriver>> buildAgentDriverList(List<SessionDto>? sessionList, String sessionId, void Function(String sessionId, AgentMessage agentMessage) listen) async {
    if(sessionList == null) return [];

    List<AgentModel> agentModelList = [];
    sessionList.forEach((session) {
      TextAgent? agent = agents[session.id];
      if(agent == null) throw AgentNotFoundException(message: "SessionId `${session.id}` Agent Not Found");
      void Function(AgentMessage agentMessage) AgentListen = (AgentMessage agentMessage){
        listen(session.id, agentMessage);
      };
      agent.agentSession.addAgentMessageListener(AgentListen);
      agentModelList.add(AgentModel(name: session.id, agent: agent));
    });

    AgentDriver agentDriver = AgentDriver(agents: agentModelList);
    return [agentDriver];
  }
}
