import 'dart:async';
import 'package:opentool_dart/opentool_dart.dart';
import 'package:openapi_dart/openapi_dart.dart';
import 'package:openmodbus_dart/openmodbus_dart.dart';
import 'package:openrpc_dart/openrpc_dart.dart';
import '../../lite_agent_core.dart';
import 'session_message_manage_service.dart';
import 'dto.dart';
import 'exception.dart';

class AgentService {
  Map<String, SessionAgent> sessionAgents = {};
  Map<String, SimpleAgent> simpleAgents = {};
  List<ToolDriver> globalDriverList = [];
  Map<String, OpenToolDriver> opentoolDriverMap = {};
  Map<String, ClientDriver> clientDriverMap= {};
  List<SessionMessageManageService> agentMessageManageServiceList = [];

  AgentService({List<ToolDriver> globalToolDriverList = const [], List<SessionMessageManageService> messageManageServiceList = const []}) {
    globalDriverList.addAll(globalToolDriverList);
    agentMessageManageServiceList.addAll(messageManageServiceList);
  }

  Future<bool> testLLMConfig(String baseUrl, String apiKey) async {
    return OpenAIUtil.checkLLMConfig(baseUrl, apiKey);
  }

  Future<SessionDto> initSimple(SimpleCapabilityDto simpleCapabilityDto) async {
    String sessionId = uniqueId();
    String systemPrompt = simpleCapabilityDto.systemPrompt;
    LLMConfig llmConfig = simpleCapabilityDto.llmConfig.toModel();

    SimpleAgent simpleAgent = SimpleAgent(
      llmConfig: llmConfig,
      systemPrompt: systemPrompt,
      responseFormat: ResponseFormat(type: ResponseFormatType.TEXT)
    );
    
    simpleAgents[sessionId] = simpleAgent;

    SessionDto sessionDto = SessionDto(sessionId: sessionId);
    return sessionDto;
  }
  
  Future<AgentMessageDto> startSimple(String sessionId, UserTaskDto userTaskDto) async {
    SimpleAgent? simpleAgent = simpleAgents[sessionId];
    if(simpleAgent == null) throw SessionAgentNotFoundException(sessionId: sessionId);
    List<Content> userMessageList = userTaskDto.contentList
        .map((userMessageDto) => _convertToContent(userMessageDto))
        .toList();
    AgentMessage agentMessage = await simpleAgent.userToAgent(contentList: userMessageList, taskId: userTaskDto.taskId);
    return AgentMessageDto.fromModel(agentMessage);
  }

  Future<SessionDto> initSession(
      CapabilityDto capabilityDto,
      void Function(String sessionId, AgentMessageDto agentMessageDto) listen, {
        Map<String, OpenToolDriver>? opentoolDriverMap, List<ToolDriver>? customToolDriverList,
        void Function(String sessionId, AgentMessageChunkDto agentMessageChunkDto)? listenChunk,
        void Function(String sessionId, FunctionCall functionCall)? listenClientFunctionCall
      }) async {
    String sessionId = uniqueId();
    String systemPrompt = capabilityDto.systemPrompt;
    LLMConfig llmConfig = capabilityDto.llmConfig.toModel();
    List<ReflectPrompt>? reflectPromptList = capabilityDto.reflectPromptList?.map((reflectPromptDto) => ReflectPrompt(llmConfig: reflectPromptDto.llmConfig.toModel(), prompt: reflectPromptDto.prompt)).toList();

    if(opentoolDriverMap != null) opentoolDriverMap.forEach((key, value) { this.opentoolDriverMap[key] = value;});
    if(capabilityDto.clientOpenTool != null && listenClientFunctionCall != null) {
      OpenTool clientOpenTool = await OpenToolLoader().load(capabilityDto.clientOpenTool!);

      void Function(FunctionCall functionCall) listenFunctionCall = (FunctionCall functionCall){
        listenClientFunctionCall(sessionId, functionCall);
      };

      clientDriverMap[sessionId] = ClientDriver(listenFunctionCall).bind(clientOpenTool) as ClientDriver;
    }

    List<ToolDriver> agentToolDriverList = [];
    agentToolDriverList.addAll(globalDriverList);
    agentToolDriverList.addAll(await _buildToolDriverList(capabilityDto.openSpecList));
    agentToolDriverList.addAll(await _buildAgentDriverList(capabilityDto.sessionList, sessionId, listen));
    if(customToolDriverList != null) agentToolDriverList.addAll(customToolDriverList);
    if(clientDriverMap[sessionId] != null) agentToolDriverList.add(clientDriverMap[sessionId]!);

    if(agentToolDriverList.isEmpty) {
      SessionAgent textAgent = TextAgent(
          sessionId: sessionId,
          llmConfig: llmConfig,
          agentSession: _buildSession(sessionId, listen, listenChunk: listenChunk),
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
          agentSession: _buildSession(sessionId, listen, listenChunk: listenChunk),
          toolDriverList: agentToolDriverList,
          systemPrompt: systemPrompt,
          toolReflectPromptList: reflectPromptList??[],
          timeoutSeconds: capabilityDto.timeoutSeconds,
          taskPipelineStrategy: capabilityDto.taskPipelineStrategy,
          toolPipelineStrategy: capabilityDto.toolPipelineStrategy??PipelineStrategyType.PARALLEL
      );
      sessionAgents[sessionId] = toolAgent;
    }

    SessionDto sessionDto = SessionDto(sessionId: sessionId);

    return sessionDto;
  }

  Future<void> startSession(String sessionId, UserTaskDto userTaskDto) async {
    SessionAgent? sessionAgent = sessionAgents[sessionId];
    if(sessionAgent == null) throw SessionAgentNotFoundException(sessionId: sessionId);
    List<Content> userMessageList = userTaskDto.contentList
      .map((contentDto) => _convertToContent(contentDto))
      .toList();
    await sessionAgent.userToAgent(taskId: userTaskDto.taskId, contentList: userMessageList, stream: userTaskDto.stream);
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
    SessionAgent? sessionAgent = sessionAgents[sessionTaskDto.sessionId];
    if(sessionAgent == null) throw SessionAgentNotFoundException(sessionId: sessionTaskDto.sessionId);
    sessionAgent.stop(taskId: sessionTaskDto.taskId);
  }

  Future<void> clearSession(String sessionId) async {
    SessionAgent? sessionAgent = sessionAgents[sessionId];
    if(sessionAgent == null) throw SessionAgentNotFoundException(sessionId: sessionId);
    sessionAgent.clear();
    sessionAgents.remove(sessionId);
  }

  Content _convertToContent(ContentDto contentDto) {
    return Content(type: contentDto.type, message: contentDto.message);
  }

  AgentSession _buildSession(String sessionId, void Function(String sessionId, AgentMessageDto agentMessageDto) listen, {void Function(String sessionId, AgentMessageChunkDto agentMessageChunkDto)? listenChunk}) {
    AgentSession agentSession = AgentSession();
    agentSession.addAgentMessageListener((AgentMessage agentMessage) {
      AgentMessageDto agentMessageDto = AgentMessageDto.fromModel(agentMessage);
      _recordAgentMessage(sessionId, agentMessageDto);
      listen(sessionId, agentMessageDto);
    });
    if(listenChunk != null) {
      agentSession.addAgentMessageChunkListener((AgentMessageChunk agentMessageChunk) {
        listenChunk(sessionId, AgentMessageChunkDto.fromModel(agentMessageChunk));
      });
    }
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
      } else if (openSpecDto.protocol == Protocol.OPENTOOL) {
        if(openSpecDto.openToolId == null) throw OpenToolIdNotFoundException(openToolId: "NULL");
        OpenToolDriver? opentoolDriver = await opentoolDriverMap[openSpecDto.openToolId!];
        if(opentoolDriver != null) {
          OpenTool openTool = await OpenToolLoader().load(openSpecDto.openSpec);
          toolDriverList.add(opentoolDriver.bind(openTool));
        } else {
          throw OpenToolIdNotFoundException(openToolId: openSpecDto.openToolId!);
        }
      } else if (openSpecDto.protocol == Protocol.SERIALPORT) {
        SerialPortDriver serialPortDriver = SerialPortDriver();
        toolDriverList.add(serialPortDriver);
      }
    }
    return toolDriverList;
  }

  Future<List<ToolDriver>> _buildAgentDriverList(List<SessionNameDto>? sessionList, String sessionId, void Function(String sessionId, AgentMessageDto agentMessageDto) listen) async {
    if( sessionList == null || sessionList.isEmpty ) return [];
    List<NamedSimpleAgent> namedSimpleAgentList = [];
    List<NamedSessionAgent> namedSessionAgentList = [];
    sessionList.forEach((session) {
      SimpleAgent? simpleAgent = simpleAgents[session.sessionId];
      SessionAgent? sessionAgent = sessionAgents[session.sessionId];
      if(simpleAgent == null && sessionAgent == null) throw SessionAgentNotFoundException(sessionId: session.sessionId);

      if(simpleAgent != null) {
        namedSimpleAgentList.add(NamedSimpleAgent(name: session.name??session.sessionId, agent: simpleAgent));
      } else {
        void Function(AgentMessage agentMessage) AgentListen = (AgentMessage agentMessage){
          AgentMessageDto agentMessageDto = AgentMessageDto.fromModel(agentMessage);
          _recordAgentMessage(session.sessionId, agentMessageDto);
          listen(session.sessionId, agentMessageDto);
        };
        sessionAgent!.agentSession.addAgentMessageListener(AgentListen);
        namedSessionAgentList.add(NamedSessionAgent(name: session.name??session.sessionId, agent: sessionAgent));
      }
    });

    SimpleAgentDriver simpleAgentDriver = SimpleAgentDriver(namedSimpleAgents: namedSimpleAgentList);
    SessionAgentDriver sessionAgentDriver = SessionAgentDriver(namedSessionAgents: namedSessionAgentList);

    List<ToolDriver> toolDriverList = [];
    toolDriverList.add(simpleAgentDriver);
    toolDriverList.add(sessionAgentDriver);
    return toolDriverList;
  }

  void _recordAgentMessage(String sessionId, AgentMessageDto agentMessageDto) {
    SessionAgentMessageDto sessionAgentMessageDto = SessionAgentMessageDto(sessionId: sessionId, agentMessageDto: agentMessageDto);
    agentMessageManageServiceList.forEach((service) {
      service.addMessage(sessionAgentMessageDto);
    });
  }

  void clientDriverCallback(String sessionId, ToolReturn toolReturn) {
    ClientDriver? clientDriver = clientDriverMap[sessionId];
    if(clientDriver == null) {
      throw SessionAgentNotFoundException(sessionId: sessionId);
    }
    clientDriver.callback(toolReturn);
  }

}
