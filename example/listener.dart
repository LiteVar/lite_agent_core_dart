import 'dart:convert';
import 'dart:io';
import 'package:lite_agent_core_dart/lite_agent_core.dart';

void listen(String sessionId, AgentMessageDto agentMessageDto) {
  String system = "🖥DEVEL ";
  String user = "👤USER  ";
  String agent = "🤖AGENT ";
  String llm = "💡ASSIST";
  String tool = "🔧TOOL  ";
  String client = "🔗CLIENT";
  String reflection = "🎯REFLEC";

  String message = "";
  if (agentMessageDto.type == ToolMessageType.TEXT)
    message = agentMessageDto.message as String;
  if (agentMessageDto.type == ToolMessageType.IMAGE_URL)
    message = agentMessageDto.message as String;
  if (agentMessageDto.type == ToolMessageType.FUNCTION_CALL_LIST) {
    List<FunctionCallDto> functionCallList = agentMessageDto.message as List<FunctionCallDto>;
    message = jsonEncode(functionCallList);
  }
  if (agentMessageDto.type == ToolMessageType.TOOL_RETURN) {
    message = jsonEncode(agentMessageDto.message as ToolReturnDto);
  };
  if (agentMessageDto.type == AgentMessageType.CONTENT_LIST) {
    List<ContentDto> contentList = agentMessageDto.message as List<ContentDto>;
    message = jsonEncode(contentList);
  }
  if (agentMessageDto.type == AgentMessageType.TASK_STATUS) {
    message = jsonEncode(agentMessageDto.message as TaskStatusDto);
  }
  if (agentMessageDto.type == TextMessageType.REFLECTION) {
    message = jsonEncode(agentMessageDto.message as ReflectionDto);
  } if (agentMessageDto.type == ToolMessageType.FUNCTION_CALL) {
    FunctionCallDto functionCall = agentMessageDto.message as FunctionCallDto;
    message = jsonEncode(functionCall);
  }

  String  role = "";
  if (agentMessageDto.role == ToolRoleType.DEVELOPER) {
     role = system;
    message = "\n$message";
  }
  if (agentMessageDto.role == ToolRoleType.USER)  role = user;
  if (agentMessageDto.role == ToolRoleType.AGENT)  role = agent;
  if (agentMessageDto.role == ToolRoleType.ASSISTANT)  role = llm;
  if (agentMessageDto.role == ToolRoleType.TOOL)  role = tool;
  if (agentMessageDto.role == ToolRoleType.CLIENT)  role = client;
  if (agentMessageDto.role == ToolRoleType.REFLECTION)  role = reflection;

  String to = "";
  if (agentMessageDto.to == ToolRoleType.DEVELOPER) to = system;
  if (agentMessageDto.to == ToolRoleType.USER) to = user;
  if (agentMessageDto.to == ToolRoleType.AGENT) to = agent;
  if (agentMessageDto.to == ToolRoleType.ASSISTANT) to = llm;
  if (agentMessageDto.to == ToolRoleType.TOOL) to = tool;
  if (agentMessageDto.to == ToolRoleType.CLIENT) to = client;
  if (agentMessageDto.to == ToolRoleType.REFLECTION) to = reflection;

  if (role.isNotEmpty && to.isNotEmpty) {
    print("#${sessionId}::${agentMessageDto.taskId}# $role -> $to: [${agentMessageDto.type}] $message");
  }
}

bool hasFirst = false;
void listenChunk(AgentMessageChunkDto agentMessageChunkDto) {
  String user = "🧩👤USER  ";
  String agent = "🧩🤖AGENT ";
  String client = "🧩🔗CLIENT";

  String part = "";
  if (agentMessageChunkDto.type == ToolMessageType.TEXT)
    part = agentMessageChunkDto.part as String;
  if (agentMessageChunkDto.type == AgentMessageType.TASK_STATUS) {
    part = jsonEncode(agentMessageChunkDto.part as TaskStatusDto);
  }

  String  role = "";
  if (agentMessageChunkDto.role == ToolRoleType.USER)  role = user;
  if (agentMessageChunkDto.role == ToolRoleType.AGENT)  role = agent;
  if (agentMessageChunkDto.role == ToolRoleType.CLIENT)  role = client;

  String to = "";
  if (agentMessageChunkDto.to == ToolRoleType.USER) to = user;
  if (agentMessageChunkDto.to == ToolRoleType.AGENT) to = agent;
  if (agentMessageChunkDto.to == ToolRoleType.CLIENT)  to = client;

  if(hasFirst == false && agentMessageChunkDto.type == TextMessageType.TEXT) {
    stdout.write(("#${agentMessageChunkDto.sessionId}::${agentMessageChunkDto.taskId}# $role -> $to: [${agentMessageChunkDto.type}] $part"));
    hasFirst = true;
  } else if(agentMessageChunkDto.type == TextMessageType.TASK_STATUS) {
    stdout.write("\n");
    print(("#${agentMessageChunkDto.sessionId}::${agentMessageChunkDto.taskId}# $role -> $to: [${agentMessageChunkDto.type}] $part"));
    hasFirst = false;
  } else {
    stdout.write(agentMessageChunkDto.part);
  }
}