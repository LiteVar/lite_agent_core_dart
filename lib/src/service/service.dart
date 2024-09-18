import 'dart:async';
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
import '../agents/session_agent/session_agent.dart';
import '../agents/simple_agent.dart';
import '../agents/text_agent/text_agent.dart';
import '../agents/tool_agent/tool_agent.dart';
import '../driver/model.dart';
import '../driver/simple_agent_driver.dart';
import '../driver/session_agent_driver.dart';
import '../llm/model.dart';
import 'dto.dart';
import 'exception.dart';

class AgentService {
  Map<String, SessionAgent> sessionAgents = {};
  Map<String, SimpleAgent> simpleAgents = {};
  List<ToolDriver> globalDriverList = [];

  AgentService({List<ToolDriver>? globalToolDriverList = null}) {
    if(globalToolDriverList != null) globalDriverList.addAll(globalToolDriverList);
  }

  Future<SessionDto> initSimple(SimpleCapabilityDto simpleCapabilityDto) async {
    String sessionId = Uuid().v4();
    String systemPrompt = simpleCapabilityDto.systemPrompt;
    LLMConfig llmConfig = simpleCapabilityDto.llmConfig.toModel();

    SimpleAgent simpleAgent = SimpleAgent(
      llmExecutor: _buildLLMExecutor(llmConfig),
      systemPrompt: systemPrompt,
      responseFormat: ResponseFormat(type: ResponseFormatType.TEXT)
    );
    
    simpleAgents[sessionId] = simpleAgent;

    SessionDto sessionDto = SessionDto(id: sessionId);
    return sessionDto;
  }
  
  Future<AgentMessageDto> startSimple(String sessionId, UserTaskDto userTaskDto) async {
    SimpleAgent? simpleAgent = simpleAgents[sessionId];
    if(simpleAgent == null) throw AgentNotFoundException(message: "SessionId `${sessionId}` Agent Not Found");
    List<Content> userMessageList = userTaskDto.contentList
        .map((userMessageDto) => _convertToContent(userMessageDto))
        .toList();
    AgentMessage agentMessage = await simpleAgent.userToAgent(contentList: userMessageList, taskId: userTaskDto.taskId);
    return AgentMessageDto.fromModel(agentMessage);
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
      sessionAgents[sessionId] = textAgent;
    } else {
      TextAgent toolAgent = ToolAgent(
        sessionId: sessionId,
        llmExecutor: _buildLLMExecutor(llmConfig),
        agentSession: _buildSession(sessionId, listen),
        toolDriverList: agentToolDriverList,
        systemPrompt: systemPrompt,
        timeoutSeconds: capabilityDto.timeoutSeconds
      );
      sessionAgents[sessionId] = toolAgent;
    }

    SessionDto sessionDto = SessionDto(id: sessionId);

    return sessionDto;
  }

  Future<void> startChat(String sessionId, UserTaskDto userTaskDto) async {
    SessionAgent? sessionAgent = sessionAgents[sessionId];
    if(sessionAgent == null) throw AgentNotFoundException(message: "SessionId `${sessionId}` Agent Not Found");
    List<Content> userMessageList = userTaskDto.contentList
      .map((userMessageDto) => _convertToContent(userMessageDto))
      .toList();
    sessionAgent.userToAgent(taskId: userTaskDto.taskId, contentList: userMessageList);
  }

  Future<List<AgentMessageDto>?> getHistory(String sessionId) async {
    SessionAgent? sessionAgent = sessionAgents[sessionId];
    if (sessionAgent == null) return null;
    return sessionAgent
      .agentSession
      .listenAgentMessageList
      .map((AgentMessage agentMessage) {
        AgentMessageDto agentMessageDto = AgentMessageDto.fromModel(agentMessage);
      return agentMessageDto;
    }).toList();
  }

  Future<void> stopChat(SessionTaskDto sessionTaskDto) async {
    SessionAgent? sessionAgent = sessionAgents[sessionTaskDto.id];
    if(sessionAgent == null) throw AgentNotFoundException(message: "SessionId `${sessionTaskDto.id}` Agent Not Found");
    sessionAgent.stop(taskId: sessionTaskDto.taskId);
  }

  Future<void> clearChat(String sessionId) async {
    SessionAgent? sessionAgent = sessionAgents[sessionId];
    if(sessionAgent == null) throw AgentNotFoundException(message: "SessionId `${sessionId}` Agent Not Found");
    sessionAgent.clear();
    sessionAgents.remove(sessionId);
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

  Future<List<ToolDriver>> buildAgentDriverList(List<SessionNameDto>? sessionList, String sessionId, void Function(String sessionId, AgentMessage agentMessage) listen) async {
    if( sessionList == null || sessionList.isEmpty ) return [];
    List<NamedSimpleAgent> namedSimpleAgentList = [];
    List<NamedSessionAgent> namedSessionAgentList = [];
    sessionList.forEach((session) {
      SimpleAgent? simpleAgent = simpleAgents[session.id];
      SessionAgent? sessionAgent = sessionAgents[session.id];
      if(simpleAgent == null && sessionAgent == null) throw AgentNotFoundException(message: "SessionId `${session.id}` Agent Not Found");

      if(simpleAgent != null) {
        namedSimpleAgentList.add(NamedSimpleAgent(name: session.name??session.id, agent: simpleAgent));
      } else {
        void Function(AgentMessage agentMessage) AgentListen = (AgentMessage agentMessage){
          listen(session.id, agentMessage);
        };
        sessionAgent!.agentSession.addAgentMessageListener(AgentListen);
        namedSessionAgentList.add(NamedSessionAgent(name: session.name??session.id, agent: sessionAgent));
      }
    });

    SimpleAgentDriver simpleAgentDriver = SimpleAgentDriver(namedSimpleAgents: namedSimpleAgentList);
    SessionAgentDriver sessionAgentDriver = SessionAgentDriver(namedSessionAgents: namedSessionAgentList);

    List<ToolDriver> toolDriverList = [];
    toolDriverList.add(simpleAgentDriver);
    toolDriverList.add(sessionAgentDriver);
    return toolDriverList;
  }
}
