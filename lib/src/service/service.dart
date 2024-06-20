import 'dart:async';
import 'dart:convert';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:openapi_dart/openapi_dart.dart';
import 'package:openmodbus_dart/openmodbus_dart.dart';
import 'package:uuid/uuid.dart';
import 'dto.dart';

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

  Future<void> startChat(String sessionId, UserMessageDto userMessageDto) async {
    ToolAgent toolAgent = agents[sessionId]!;
    toolAgent.userToAgent(_convertToAgentMessageType(userMessageDto.type), userMessageDto.message);
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

  AgentMessageType _convertToAgentMessageType(UserMessageType userMessageType) {
    switch(userMessageType) {
      case UserMessageType.text: return AgentMessageType.text;
      case UserMessageType.imageUrl: return AgentMessageType.imageUrl;
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
      Map<String, dynamic> specJson = jsonDecode(openSpecDto.openSpec);
      if(specJson.containsKey("openapi")) {
        OpenAPI openAPI = await OpenAPILoader().load(openSpecDto.openSpec);
        String? authorization;
        if(openSpecDto.apiKey != null) { convertToAuthorization(openSpecDto.apiKey!.type, openSpecDto.apiKey!.apiKey); }
        ToolRunner openAPIRunner = OpenAPIRunner(openAPI,  authorization: authorization);
        toolRunnerList.add(openAPIRunner);
        // } else if(specJson.containsKey("openrpc")) {
        //   OpenRPC openRPC = await OpenRPCLoader().load(spec);
        //   ToolRunner openRPCRunner = OpenRPCRunner(openRPC);
        //   return openRPCRunner;
      } else {//if(specJson.containsKey("openmodbus")) {
        OpenModbus openModbus = await OpenModbusLoader().load(openSpecDto.openSpec);
        ToolRunner openModbusRunner = OpenModbusRunner(openModbus);
        toolRunnerList.add(openModbusRunner);
        // } else {
        //   OpenTool openTool = await OpenToolLoader().load(spec);
        //   ToolRunner openToolRunner = OpenToolRunner(openTool);
        //   return openToolRunner;
      }
    }
    return toolRunnerList;
  }

}