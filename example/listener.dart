import 'dart:convert';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:opentool_dart/opentool_dart.dart';

void listen(String sessionId, AgentMessageDto agentMessageDto) {
  String system = "🖥SYSTEM";
  String user = "👤USER";
  String agent = "🤖AGENT";
  String llm = "💡LLM";
  String tool = "🔧TOOL";
  String client = "🔗CLIENT";

  String message = "";
  if (agentMessageDto.type == ToolMessageType.TEXT)
    message = agentMessageDto.message as String;
  if (agentMessageDto.type == ToolMessageType.IMAGE_URL)
    message = agentMessageDto.message as String;
  if (agentMessageDto.type == ToolMessageType.FUNCTION_CALL_LIST) {
    List<FunctionCall> functionCallList = agentMessageDto.message as List<FunctionCall>;
    message = jsonEncode(functionCallList);
  }
  if (agentMessageDto.type == AgentMessageType.TOOL_RETURN) {
    message = jsonEncode(agentMessageDto.message as ToolReturn);
  };
  if (agentMessageDto.type == AgentMessageType.CONTENT_LIST) {
    List<Content> contentList = agentMessageDto.message as List<Content>;
    message = jsonEncode(contentList);
  }

  String from = "";
  if (agentMessageDto.from == ToolRoleType.SYSTEM) {
    from = system;
    message = "\n$message";
  }
  if (agentMessageDto.from == ToolRoleType.USER) from = user;
  if (agentMessageDto.from == ToolRoleType.AGENT) from = agent;
  if (agentMessageDto.from == ToolRoleType.LLM) from = llm;
  if (agentMessageDto.from == ToolRoleType.TOOL) from = tool;
  if (agentMessageDto.from == ToolRoleType.CLIENT) from = client;

  String to = "";
  if (agentMessageDto.to == ToolRoleType.SYSTEM) to = system;
  if (agentMessageDto.to == ToolRoleType.USER) to = user;
  if (agentMessageDto.to == ToolRoleType.AGENT) to = agent;
  if (agentMessageDto.to == ToolRoleType.LLM) to = llm;
  if (agentMessageDto.to == ToolRoleType.TOOL) to = tool;
  if (agentMessageDto.to == ToolRoleType.CLIENT) to = client;

  if (from.isNotEmpty && to.isNotEmpty) {
    print("#${sessionId}::${agentMessageDto.taskId}# $from -> $to: [${agentMessageDto.type}] $message");
  }
}