import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:openapi_dart/openapi_dart.dart';
import 'package:openmodbus_dart/openmodbus_dart.dart';
import 'package:openrpc_dart/openrpc_dart.dart';
import '../agents/model.dart';
import '../agents/llm/llm_executor.dart';
import '../agents/llm/openai_executor.dart';
import '../agents/session_agent/session.dart';
import '../agents/session_agent/model.dart';
import '../agents/tool_agent/tool_agent.dart';
import '../driver/http/openapi_driver.dart';
import '../driver/modbus/openmodbus_driver.dart';
import '../driver/tool_driver.dart';
import '../driver/jsonrpc/jsonrpc_driver.dart';
import '../llm/model.dart';
// import '../../trash/session.dart';
// import '../../trash/llm_executor3.dart';
// import '../model.dart';
import 'dto.dart';

class AgentService {
  Map<String, ToolAgent> agents = {};
  List<ToolDriver> toolDriverList = [];

  AgentService({List<ToolDriver>? customToolDriverList = null}) {
    if(customToolDriverList != null) toolDriverList.addAll(customToolDriverList);
  }

  Future<SessionDto> initChat(CapabilityDto capabilityDto, void Function(String sessionId, AgentMessage agentMessage) listen) async {
    String systemPrompt = capabilityDto.systemPrompt;
    List<OpenSpecDto> openSpecDtoList = capabilityDto.openSpecList;

    LLMConfig llmConfig = capabilityDto.llmConfig.toModel();

    String sessionId = Uuid().v4();

    ToolAgent toolAgent = ToolAgent(
        llmExecutor: _buildLLMExecutor(llmConfig),
        agentSession: _buildSession(sessionId, listen),
        toolDriverList: await buildToolDriverList(openSpecDtoList),
        systemPrompt: systemPrompt,
        timeoutSeconds: capabilityDto.timeoutSeconds
    );

    agents.addAll({sessionId: toolAgent});

    SessionDto sessionDto = SessionDto(id: sessionId);

    return sessionDto;
  }

  Future<void> startChat(String sessionId, UserTaskDto userTaskDto) async {
    ToolAgent toolAgent = agents[sessionId]!;
    List<Content> userMessageList = userTaskDto.contentList
        .map((userMessageDto) => _convertToContent(userMessageDto))
        .toList();
    toolAgent.userToAgent(taskId: userTaskDto.taskId, contentList: userMessageList);
  }

  Future<List<AgentMessageDto>> getHistory(String sessionId) async {
    return agents[sessionId]!
      .agentSession
      .listenAgentMessageList
      .map((AgentMessage agentMessage) {
        AgentMessageDto agentMessageDto = AgentMessageDto.fromModel(sessionId, agentMessage);
      return agentMessageDto;
    }).toList();
  }

  Future<void> stopChat(SessionTaskDto sessionTaskDto) async {
    ToolAgent toolAgent = agents[sessionTaskDto.id]!;
    toolAgent.stop(taskId: sessionTaskDto.taskId);
  }

  Future<void> clearChat(String sessionId) async {
    ToolAgent toolAgent = agents[sessionId]!;
    toolAgent.clear();
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

  AgentSession _buildSession(String sessionId,
      void Function(String sessionId, AgentMessage agentMessage) listen) {
    AgentSession agentSession = AgentSession();
    agentSession.addAgentMessageListener((AgentMessage agentMessage) {
      listen(sessionId, agentMessage);
    });
    return agentSession;
  }

  Future<List<ToolDriver>> buildToolDriverList(List<OpenSpecDto> openSpecDtoList) async {
    for (OpenSpecDto openSpecDto in openSpecDtoList) {
      if (openSpecDto.protocol == Protocol.openapi) {
        OpenAPI openAPI = await OpenAPILoader().load(openSpecDto.openSpec);
        String? authorization;
        if (openSpecDto.apiKey != null) {
          convertToAuthorization(openSpecDto.apiKey!.type, openSpecDto.apiKey!.apiKey);
        }
        ToolDriver openAPIRunner = OpenAPIDriver(openAPI, authorization: authorization);
        toolDriverList.add(openAPIRunner);
      } else if (openSpecDto.protocol == Protocol.openmodbus) {
        OpenModbus openModbus = await OpenModbusLoader().load(openSpecDto.openSpec);
        ToolDriver openModbusRunner = OpenModbusDriver(openModbus);
        toolDriverList.add(openModbusRunner);
      } else if (openSpecDto.protocol == Protocol.jsonrpcHttp) {
        OpenRPC openRPC = await OpenRPCLoader().load(openSpecDto.openSpec);
        ToolDriver jsonrpcHttpRunner = JsonRPCDriver(openRPC);
        toolDriverList.add(jsonrpcHttpRunner);
      }
    }
    return toolDriverList;
  }
}
