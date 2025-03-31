import 'dart:convert';

import 'package:opentool_dart/opentool_dart.dart';
import '../model.dart';
import '../reflection/reflector_manager.dart';
import '../session_agent/agent_message_handler.dart';
import '../session_agent/dispatcher.dart';
import '../session_agent/model.dart';
import '../text_agent/model.dart';
import 'model.dart';

class LLMFunctionCallingMessageHandler extends AgentMessageHandler {
  final ReflectorManager reflectionManager;
  final Future<void> Function(AgentMessage) toReflection;
  final Future<void> Function(AgentMessage) toUser;
  final Future<void> Function(AgentMessage) toTool;
  String chunkAccumulation = "";

  LLMFunctionCallingMessageHandler(this.reflectionManager, this.toReflection, this.toUser, this.toTool);

  @override
  Command? handle(AgentMessage agentMessage) {
    if (agentMessage.type == ToolMessageType.FUNCTION_CALL_LIST) {
      List<FunctionCall> functionCallList = agentMessage.content as List<FunctionCall>;
      if(reflectionManager.shouldReflect) {
        AgentMessage reflectionMessage = AgentMessage(
            sessionId: agentMessage.sessionId,
            taskId: agentMessage.taskId,
            role: ToolRoleType.AGENT,
            to: ToolRoleType.REFLECTION,
            type: ToolMessageType.FUNCTION_CALL_LIST,
            content: functionCallList
        );
        return Command(toReflection, reflectionMessage); // If LLM return function call, and should reflect, forward to REFLECTION.
      } else {
          AgentMessage agentToolMessage = AgentMessage(
            sessionId: agentMessage.sessionId,
            taskId: agentMessage.taskId,
            role: ToolRoleType.AGENT,
            to: ToolRoleType.TOOL,
            type: ToolMessageType.FUNCTION_CALL_LIST,
            content: agentMessage.content
          );
          return Command(toTool, agentToolMessage); // If LLM call function, forward to TOOL.
      }
    } else if (agentMessage.type == ToolMessageType.TEXT || agentMessage.type == ToolMessageType.IMAGE_URL) {
      AgentMessage agentUserMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          role: ToolRoleType.AGENT,
          to: ToolRoleType.USER,
          type: agentMessage.type,
          content: agentMessage.content);
      return Command(toUser, agentUserMessage); // If LLM return image, forward to USER.
    }
    return null;
  }
}

class ToolMessageHandler extends AgentMessageHandler {

  final ReflectorManager reflectionManager;
  final Future<void> Function(AgentMessage) toLLM;
  final void Function(AgentMessage)? onToolReturn;

  ToolMessageHandler(this.reflectionManager, this.toLLM, {this.onToolReturn});

  @override
  Command? handle(AgentMessage agentMessage) {
    if (agentMessage.type == ToolMessageType.TOOL_RETURN) {
      // If TOOL return result, add the result message
      AgentMessage agentLLMMessage = AgentMessage(
        sessionId: agentMessage.sessionId,
        taskId: agentMessage.taskId,
        role: ToolRoleType.AGENT,
        to: ToolRoleType.ASSISTANT,
        type: ToolMessageType.TOOL_RETURN,
        content: agentMessage.content
      );
      // nextCommand = Command(toLLM, agentLLMMessage);
      // Only push to listener, NOT forward to LLM until ToolsStatus.DONE
      if(onToolReturn != null ) onToolReturn!(agentLLMMessage);
    } else if (agentMessage.type == ToolMessageType.TASK_STATUS) {
      // If TOOL return DONE status, forward to LLM
      TaskStatus taskStatus = agentMessage.content as TaskStatus;
      if (taskStatus.status == ToolStatusType.DONE) {
        AgentMessage agentToolMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          role: ToolRoleType.AGENT,
          to: ToolRoleType.CLIENT,
          type: ToolMessageType.TASK_STATUS,
          content: agentMessage.content
        );
        return Command(toLLM, agentToolMessage);
      }
    }
    return null;
  }

}

class ToolReflectionMessageHandler extends AgentMessageHandler {

  final ReflectorManager toolReflectionManager;
  final Future<void> Function(AgentMessage) toLLM;
  final Future<void> Function(AgentMessage) toTool;
  final Function(AgentMessage)? onToolRetry;

  ToolReflectionMessageHandler(this.toolReflectionManager, this.toLLM, this.toTool, {this.onToolRetry});

  @override
  Command? handle(AgentMessage agentMessage) {
    Reflection reflection = agentMessage.content as Reflection;
    if(reflection.isPass || reflection.count == reflection.maxCount) {
      List<dynamic> jsonList = jsonDecode(reflection.messageScore.message);
      List<FunctionCall> functionCallList = jsonList.map((json)=>FunctionCall.fromJson(json)).toList();
      AgentMessage agentUserMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          role: ToolRoleType.AGENT,
          to: ToolRoleType.TOOL,
          type: ToolMessageType.FUNCTION_CALL_LIST,
          content: functionCallList
      );
      return Command(toTool, agentUserMessage); // If Reflection pass or maxCount, forward to TOOL.
    } else {
      List<Content> userContentList = toolReflectionManager.userContentList;
      AgentMessage newAgentMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          role: ToolRoleType.AGENT,
          to: ToolRoleType.ASSISTANT,
          type: ToolMessageType.CONTENT_LIST,
          content: userContentList
      );
      if(toolReflectionManager.shouldReflect) {
        if(onToolRetry != null) onToolRetry!(agentMessage);
        toolReflectionManager.retry();
      }
      return Command(toLLM, newAgentMessage); // Reset User messages request to LLM.
    }
  }
}