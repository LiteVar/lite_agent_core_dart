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
import '../agents/text_agent/text_agent.dart';
import '../agents/tool_agent/tool_agent.dart';
import '../llm/model.dart';
import 'dto.dart';

class AgentService {
  Map<String, TextAgent> agents = {};
  List<ToolDriver> toolDriverList = [];

  AgentService({List<ToolDriver>? customToolDriverList = null}) {
    if(customToolDriverList != null) toolDriverList.addAll(customToolDriverList);
  }

  Future<SessionDto> initChat(CapabilityDto capabilityDto, void Function(String sessionId, AgentMessage agentMessage) listen) async {
    String sessionId = Uuid().v4();
    String systemPrompt = capabilityDto.systemPrompt;
    LLMConfig llmConfig = capabilityDto.llmConfig.toModel();

    List<ToolDriver> allToolDriverList = await buildToolDriverList(capabilityDto.openSpecList);

    if(allToolDriverList.isEmpty) {
      TextAgent toolAgent = TextAgent(
          llmExecutor: _buildLLMExecutor(llmConfig),
          agentSession: _buildSession(sessionId, listen),
          systemPrompt: systemPrompt,
          timeoutSeconds: capabilityDto.timeoutSeconds
      );
      agents.addAll({sessionId: toolAgent});
    } else {
      List<OpenSpecDto> openSpecDtoList = capabilityDto.openSpecList!;

      TextAgent toolAgent = ToolAgent(
          llmExecutor: _buildLLMExecutor(llmConfig),
          agentSession: _buildSession(sessionId, listen),
          toolDriverList: await buildToolDriverList(openSpecDtoList),
          systemPrompt: systemPrompt,
          timeoutSeconds: capabilityDto.timeoutSeconds
      );
      agents.addAll({sessionId: toolAgent});
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
        AgentMessageDto agentMessageDto = AgentMessageDto.fromModel(sessionId, agentMessage);
      return agentMessageDto;
    }).toList();
  }

  Future<void> stopChat(SessionTaskDto sessionTaskDto) async {
    TextAgent toolAgent = agents[sessionTaskDto.id]!;
    toolAgent.stop(taskId: sessionTaskDto.taskId);
  }

  Future<void> clearChat(String sessionId) async {
    TextAgent toolAgent = agents[sessionId]!;
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

  Future<List<ToolDriver>> buildToolDriverList(List<OpenSpecDto>? openSpecDtoList) async {
    if(openSpecDtoList == null) return toolDriverList;
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
