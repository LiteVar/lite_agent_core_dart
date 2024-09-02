import 'dart:convert';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:opentool_dart/opentool_dart.dart';

void listen(String sessionId, AgentMessage agentMessage) {
  String system = "🖥SYSTEM";
  String user = "👤USER";
  String agent = "🤖AGENT";
  String llm = "💡LLM";
  String tool = "🔧TOOL";
  String client = "🔗CLIENT";

  String message = "";
  if (agentMessage.type == ToolMessageType.TEXT)
    message = agentMessage.message as String;
  if (agentMessage.type == ToolMessageType.IMAGE_URL)
    message = agentMessage.message as String;
  if (agentMessage.type == ToolMessageType.FUNCTION_CALL_LIST) {
    List<FunctionCall> functionCallList = agentMessage.message as List<FunctionCall>;
    message = jsonEncode(functionCallList);
  }
  if (agentMessage.type == AgentMessageType.TOOL_RETURN) {
    message = jsonEncode(agentMessage.message as ToolReturn);
  };
  if (agentMessage.type == AgentMessageType.CONTENT_LIST) {
    List<Content> contentList = agentMessage.message as List<Content>;
    message = jsonEncode(contentList);
  }

  String from = "";
  if (agentMessage.from == ToolRoleType.SYSTEM) {
    from = system;
    message = "\n$message";
  }
  if (agentMessage.from == ToolRoleType.USER) from = user;
  if (agentMessage.from == ToolRoleType.AGENT) from = agent;
  if (agentMessage.from == ToolRoleType.LLM) from = llm;
  if (agentMessage.from == ToolRoleType.TOOL) from = tool;
  if (agentMessage.from == ToolRoleType.CLIENT) from = client;

  String to = "";
  if (agentMessage.to == ToolRoleType.SYSTEM) to = system;
  if (agentMessage.to == ToolRoleType.USER) to = user;
  if (agentMessage.to == ToolRoleType.AGENT) to = agent;
  if (agentMessage.to == ToolRoleType.LLM) to = llm;
  if (agentMessage.to == ToolRoleType.TOOL) to = tool;
  if (agentMessage.to == ToolRoleType.CLIENT) to = client;

  if (from.isNotEmpty && to.isNotEmpty) {
    print("#${sessionId}::${agentMessage.taskId}# $from -> $to: [${agentMessage.type}] $message");
  }
}