import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:opentool_dart/opentool_dart.dart';
import 'package:openapi_dart/openapi_dart.dart';
import 'package:openmodbus_dart/openmodbus_dart.dart';
import 'package:openrpc_dart/openrpc_dart.dart';
import '../agents/model.dart';
import '../agents/pipeline/model.dart';
import '../agents/reflection/model.dart';
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
import '../llm/openai_util.dart';
import 'dto.dart';
import 'exception.dart';

class AgentService {
  Map<String, SessionAgent> sessionAgents = {};
  Map<String, SimpleAgent> simpleAgents = {};
  List<ToolDriver> globalDriverList = [];
  Map<String, OpenToolDriver> opentoolDriverMap = {};

  AgentService({List<ToolDriver> globalToolDriverList = const []}) {
    globalDriverList.addAll(globalToolDriverList);
  }

  Future<bool> testLLMConfig(String baseUrl, String apiKey) async {
    return OpenAIUtil.checkLLMConfig(baseUrl, apiKey);
  }

  Future<SessionDto> initSimple(SimpleCapabilityDto simpleCapabilityDto) async {
    String sessionId = Uuid().v4();
    String systemPrompt = simpleCapabilityDto.systemPrompt;
    LLMConfig llmConfig = simpleCapabilityDto.llmConfig.toModel();

    SimpleAgent simpleAgent = SimpleAgent(
      llmConfig: llmConfig,
      systemPrompt: systemPrompt,
      responseFormat: ResponseFormat(type: ResponseFormatType.TEXT)
    );
    
    simpleAgents[sessionId] = simpleAgent;

    SessionDto sessionDto = SessionDto(id: sessionId);
    return sessionDto;
  }
  
  Future<AgentMessageDto> startSimple(String sessionId, UserTaskDto userTaskDto) async {
    SimpleAgent? simpleAgent = simpleAgents[sessionId];
    if(simpleAgent == null) throw AgentNotFoundException(sessionId: sessionId);
    List<Content> userMessageList = userTaskDto.contentList
        .map((userMessageDto) => _convertToContent(userMessageDto))
        .toList();
    AgentMessage agentMessage = await simpleAgent.userToAgent(contentList: userMessageList, taskId: userTaskDto.taskId);
    return AgentMessageDto.fromModel(agentMessage);
  }

  Future<SessionDto> initSession(CapabilityDto capabilityDto, void Function(String sessionId, AgentMessageDto agentMessageDto) listen, {Map<String, OpenToolDriver>? opentoolDriverMap, List<ToolDriver>? customToolDriverList}) async {
    String sessionId = Uuid().v4();
    String systemPrompt = capabilityDto.systemPrompt;
    LLMConfig llmConfig = capabilityDto.llmConfig.toModel();
    List<ReflectPrompt>? reflectPromptList = capabilityDto.reflectPromptList?.map((reflectPromptDto) => ReflectPrompt(llmConfig: reflectPromptDto.llmConfig.toModel(), prompt: reflectPromptDto.prompt)).toList();

    if(opentoolDriverMap != null) opentoolDriverMap.forEach((key, value) { this.opentoolDriverMap[key] = value;});

    List<ToolDriver> agentToolDriverList = [];
    agentToolDriverList.addAll(globalDriverList);
    agentToolDriverList.addAll(await _buildToolDriverList(capabilityDto.openSpecList));
    agentToolDriverList.addAll(await _buildAgentDriverList(capabilityDto.sessionList, sessionId, listen));
    if(customToolDriverList != null) agentToolDriverList.addAll(customToolDriverList);

    if(agentToolDriverList.isEmpty) {
      SessionAgent textAgent = TextAgent(
        sessionId: sessionId,
        llmConfig: llmConfig,
        agentSession: _buildSession(sessionId, listen),
        systemPrompt: systemPrompt,
        textReflectPromptList: reflectPromptList??[],
        timeoutSeconds: capabilityDto.timeoutSeconds,
        taskPipelineStrategy: capabilityDto.taskPipelineStrategy
      );
      sessionAgents[sessionId] = textAgent;
    } else {
      SessionAgent toolAgent = ToolAgent(
        sessionId: sessionId,
        llmConfig: llmConfig,
        agentSession: _buildSession(sessionId, listen),
        toolDriverList: agentToolDriverList,
        systemPrompt: systemPrompt,
        toolReflectPromptList: reflectPromptList??[],
        timeoutSeconds: capabilityDto.timeoutSeconds,
        taskPipelineStrategy: capabilityDto.taskPipelineStrategy,
        toolPipelineStrategy: capabilityDto.toolPipelineStrategy??PipelineStrategyType.PARALLEL
      );
      sessionAgents[sessionId] = toolAgent;
    }

    SessionDto sessionDto = SessionDto(id: sessionId);

    return sessionDto;
  }

  Future<void> startSession(String sessionId, UserTaskDto userTaskDto) async {
    SessionAgent? sessionAgent = sessionAgents[sessionId];
    if(sessionAgent == null) throw AgentNotFoundException(sessionId: sessionId);
    List<Content> userMessageList = userTaskDto.contentList
      .map((userMessageDto) => _convertToContent(userMessageDto))
      .toList();
    await sessionAgent.userToAgent(taskId: userTaskDto.taskId, contentList: userMessageList);
  }

  Future<List<AgentMessageDto>?> getCacheHistory(String sessionId) async {
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

  Future<void> stopSession(SessionTaskDto sessionTaskDto) async {
    SessionAgent? sessionAgent = sessionAgents[sessionTaskDto.id];
    if(sessionAgent == null) throw AgentNotFoundException(sessionId: sessionTaskDto.id);
    sessionAgent.stop(taskId: sessionTaskDto.taskId);
  }

  Future<void> clearSession(String sessionId) async {
    SessionAgent? sessionAgent = sessionAgents[sessionId];
    if(sessionAgent == null) throw AgentNotFoundException(sessionId: sessionId);
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

  AgentSession _buildSession(String sessionId, void Function(String sessionId, AgentMessageDto agentMessageDto) listen) {
    AgentSession agentSession = AgentSession();
    agentSession.addAgentMessageListener((AgentMessage agentMessage) {
      listen(sessionId, AgentMessageDto.fromModel(agentMessage));
    });
    return agentSession;
  }

  Future<List<ToolDriver>> _buildToolDriverList(List<OpenSpecDto>? openSpecDtoList) async {
    if(openSpecDtoList == null) return [];
    List<ToolDriver> toolDriverList = [];
    for (OpenSpecDto openSpecDto in openSpecDtoList) {
      if (openSpecDto.protocol == Protocol.OPENAPI) {
        OpenAPI openAPI = await OpenAPILoader().load(openSpecDto.openSpec);
        String? authorization;
        if (openSpecDto.apiKey != null) {
          authorization = convertToAuthorization(openSpecDto.apiKey!.type, openSpecDto.apiKey!.apiKey);
        }
        ToolDriver openAPIDriver = OpenAPIDriver(openAPI, authorization: authorization);
        toolDriverList.add(openAPIDriver);
      } else if (openSpecDto.protocol == Protocol.OPENMODBUS) {
        OpenModbus openModbus = await OpenModbusLoader().load(openSpecDto.openSpec);
        ToolDriver openModbusDriver = OpenModbusDriver(openModbus);
        toolDriverList.add(openModbusDriver);
      } else if (openSpecDto.protocol == Protocol.JSONRPCHTTP) {
        OpenRPC openRPC = await OpenRPCLoader().load(openSpecDto.openSpec);
        ToolDriver jsonrpcHttpDriver = JsonRPCDriver(openRPC);
        toolDriverList.add(jsonrpcHttpDriver);
      }else if (openSpecDto.protocol == Protocol.OPENTOOL) {
        OpenToolDriver? opentoolDriver = await opentoolDriverMap[openSpecDto.openToolId];
        if(opentoolDriver != null) {
          OpenTool openTool = await OpenToolLoader().load(openSpecDto.openSpec);
          toolDriverList.add(opentoolDriver.bind(openTool));
        }
      }
    }
    return toolDriverList;
  }

  Future<List<ToolDriver>> _buildAgentDriverList(List<SessionNameDto>? sessionList, String sessionId, void Function(String sessionId, AgentMessageDto agentMessageDto) listen) async {
    if( sessionList == null || sessionList.isEmpty ) return [];
    List<NamedSimpleAgent> namedSimpleAgentList = [];
    List<NamedSessionAgent> namedSessionAgentList = [];
    sessionList.forEach((session) {
      SimpleAgent? simpleAgent = simpleAgents[session.id];
      SessionAgent? sessionAgent = sessionAgents[session.id];
      if(simpleAgent == null && sessionAgent == null) throw AgentNotFoundException(sessionId: session.id);

      if(simpleAgent != null) {
        namedSimpleAgentList.add(NamedSimpleAgent(name: session.name??session.id, agent: simpleAgent));
      } else {
        void Function(AgentMessage agentMessage) AgentListen = (AgentMessage agentMessage){
          listen(session.id, AgentMessageDto.fromModel(agentMessage));
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
