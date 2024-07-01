import 'dart:async';
import 'package:lite_agent_core_dart/src/runner/jsonrpc_runner.dart';
import 'package:openapi_dart/openapi_dart.dart';
import 'package:openmodbus_dart/openmodbus_dart.dart';
import 'package:openrpc_dart/openrpc_dart.dart';
import 'package:uuid/uuid.dart';
import '../agents/tool_agent.dart';
import '../runner/openapi_runner.dart';
import '../runner/openmodbus_runner.dart';
import '../runner/tool_runner.dart';
import '../session.dart';
import '../util/llm_util.dart';
import 'dto.dart';
import '../model.dart';

class AgentService {

  Map<String, ToolAgent> agents = {};

  Future<SessionDto> initChat(CapabilityDto capabilityDto, void Function(String sessionId, AgentMessage agentMessage) listen) async {
    String systemPrompt = capabilityDto.systemPrompt;
    List<OpenSpecDto> openSpecDtoList = capabilityDto.openSpecList;

    LLMConfig llmConfig = LLMConfig(
        baseUrl: capabilityDto.llmConfig.baseUrl,
        apiKey: capabilityDto.llmConfig.apiKey,
        model: capabilityDto.llmConfig.model,
        temperature: capabilityDto.llmConfig.temperature,
        maxTokens: capabilityDto.llmConfig.maxTokens,
        topP: capabilityDto.llmConfig.topP
    );

    String sessionId = Uuid().v4();

    ToolAgent toolAgent = ToolAgent(
        llmRunner: _buildLLMRunner(llmConfig),
        session: _buildSession(sessionId, listen),
        toolRunnerList: await _buildToolRunnerList(openSpecDtoList),
        systemPrompt: systemPrompt,
        timeoutSeconds: capabilityDto.timeoutSeconds
    );

    agents.addAll({sessionId: toolAgent});

    SessionDto sessionDto = SessionDto(id: sessionId);

    return sessionDto;
  }

  Future<void> startChat(String sessionId, List<UserMessageDto> userMessageDtoList) async {
    ToolAgent toolAgent = agents[sessionId]!;
    List<UserMessage> userMessageList = userMessageDtoList.map((userMessageDto) => _convertToUserMessage(userMessageDto)).toList();
    toolAgent.userToAgent(userMessageList);
  }

  Future<List<AgentMessageDto>> getHistory(String sessionId) async {
    return agents[sessionId]!.session.agentMessageList.map((AgentMessage agentMessage) {
      AgentMessageDto agentMessageDto = AgentMessageDto(
          sessionId: sessionId,
          from: agentMessage.from,
          to: agentMessage.to, type: agentMessage.type,
          message: agentMessage.message,
          createTime: agentMessage.createTime
      );
      return agentMessageDto;
    }).toList();
  }

  Future<void> stopChat(String sessionId) async {
    ToolAgent toolAgent = agents[sessionId]!;
    toolAgent.stop();
  }

  Future<void> clearChat(String sessionId) async {
    ToolAgent toolAgent = agents[sessionId]!;
    toolAgent.clear();
    agents.remove(sessionId);
  }

  UserMessage _convertToUserMessage(UserMessageDto userMessageDto) {
    switch(userMessageDto.type) {
      case UserMessageDtoType.text: return UserMessage(type: UserMessageType.text, message: userMessageDto.message as String);
      case UserMessageDtoType.imageUrl: return UserMessage(type: UserMessageType.imageUrl, message: userMessageDto.message as String);
    }
  }

  LLMRunner _buildLLMRunner(LLMConfig llmConfig) => LLMRunner(llmConfig);

  AgentSession _buildSession(String sessionId, void Function(String sessionId, AgentMessage agentMessage) listen) {
    AgentSession agentSession = AgentSession();
    agentSession.addAgentMessageListener((AgentMessage agentMessage){
      listen(sessionId, agentMessage);
    });
    return agentSession;
  }

  Future<List<ToolRunner>> _buildToolRunnerList(List<OpenSpecDto> openSpecDtoList) async {
    List<ToolRunner> toolRunnerList = [];
    for (OpenSpecDto openSpecDto in openSpecDtoList) {
      if(openSpecDto.protocol == Protocol.openapi) {
        OpenAPI openAPI = await OpenAPILoader().load(openSpecDto.openSpec);
        String? authorization;
        if(openSpecDto.apiKey != null) { convertToAuthorization(openSpecDto.apiKey!.type, openSpecDto.apiKey!.apiKey); }
        ToolRunner openAPIRunner = OpenAPIRunner(openAPI,  authorization: authorization);
        toolRunnerList.add(openAPIRunner);
      } else if(openSpecDto.protocol == Protocol.openmodbus) {
        OpenModbus openModbus = await OpenModbusLoader().load(openSpecDto.openSpec);
        ToolRunner openModbusRunner = OpenModbusRunner(openModbus);
        toolRunnerList.add(openModbusRunner);
      } else if(openSpecDto.protocol == Protocol.jsonrpcHttp) {
        OpenRPC openRPC = await OpenRPCLoader().load(openSpecDto.openSpec);
        ToolRunner jsonrpcHttpRunner = JsonRPCRunner(openRPC);
        toolRunnerList.add(jsonrpcHttpRunner);
      }
    }
    return toolRunnerList;
  }

}