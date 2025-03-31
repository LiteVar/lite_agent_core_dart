import '../model.dart';
import '../reflection/reflector_manager.dart';
import '../session_agent/agent_message_handler.dart';
import '../session_agent/dispatcher.dart';
import '../session_agent/model.dart';
import 'model.dart';

class UserMessageHandler extends AgentMessageHandler {

  final ReflectorManager textReflectionManager;
  final Future<void> Function(AgentMessage) toLLM;

  UserMessageHandler(this.textReflectionManager, this.toLLM);

  @override
  Command? handle(AgentMessage agentMessage) {
    List<Content> userContentList = agentMessage.content as List<Content>;
    AgentMessage newAgentMessage = AgentMessage(
      sessionId: agentMessage.sessionId,
      taskId: agentMessage.taskId,
      role: TextRoleType.AGENT,
      to: TextRoleType.ASSISTANT,
      type: TextMessageType.CONTENT_LIST,
      content: userContentList
    );
    if(textReflectionManager.shouldReflect) { // if Reflection, reset reflectionManager
      textReflectionManager.retry();
      textReflectionManager.userContentList = userContentList;
    }
    return Command(toLLM, newAgentMessage); // Forward USER messages request to LLM.
  }

}

class LLMMessageHandler extends AgentMessageHandler {

  final ReflectorManager reflectionManager;
  final Future<void> Function(AgentMessage) toReflection;
  final Future<void> Function(AgentMessage) toUser;
  String chunkAccumulation = "";

  LLMMessageHandler(this.reflectionManager, this.toReflection, this.toUser);

  @override
  Command? handle(AgentMessage agentMessage) {
    if (agentMessage.type == TextMessageType.TEXT) {
      if(reflectionManager.shouldReflect) {
        AgentMessage reflectionMessage = AgentMessage(
            sessionId: agentMessage.sessionId,
            taskId: agentMessage.taskId,
            role: TextRoleType.AGENT,
            to: TextRoleType.REFLECTION,
            type: TextMessageType.TEXT,
            content: agentMessage.content
        );
        return Command(toReflection, reflectionMessage); // If LLM return text, and should reflect, forward to REFLECTION.
      } else {
        AgentMessage agentUserMessage = AgentMessage(
            sessionId: agentMessage.sessionId,
            taskId: agentMessage.taskId,
            role: TextRoleType.AGENT,
            to: TextRoleType.USER,
            type: TextMessageType.TEXT,
            content: agentMessage.content
        );
        return Command(toUser, agentUserMessage); // If LLM return text and NOT reflect, forward to USER.
      }
    } else if (agentMessage.type == TextMessageType.IMAGE_URL) {
      AgentMessage agentUserMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          role: TextRoleType.AGENT,
          to: TextRoleType.USER,
          type: TextMessageType.IMAGE_URL,
          content: agentMessage.content);
      return Command(toUser, agentUserMessage); // If LLM return image, forward to USER.
    } else if(agentMessage.type == TextMessageType.TASK_STATUS && agentMessage.content == TextStatusType.CHUNK_DONE) {
      if(reflectionManager.shouldReflect) {
        AgentMessage reflectionMessage = AgentMessage(
            sessionId: agentMessage.sessionId,
            taskId: agentMessage.taskId,
            role: TextRoleType.AGENT,
            to: TextRoleType.REFLECTION,
            type: TextMessageType.TEXT,
            content: chunkAccumulation
        );
        return Command(toReflection, reflectionMessage); // If LLM return text, and should reflect, forward to REFLECTION.
      } else {
        AgentMessage agentUserMessage = AgentMessage(
            sessionId: agentMessage.sessionId,
            taskId: agentMessage.taskId,
            role: TextRoleType.AGENT,
            to: TextRoleType.USER,
            type: TextMessageType.TEXT,
            content: chunkAccumulation
        );
        return Command(toUser, agentUserMessage); // If LLM return text and NOT reflect, forward to USER.
      }
    }
    return null;
  }
}

class TextReflectionMessageHandler extends AgentMessageHandler {

  final ReflectorManager reflectionManager;
  final Future<void> Function(AgentMessage) toLLM;
  final Future<void> Function(AgentMessage) toUser;
  final Function(AgentMessage)? onTextRetry;

  TextReflectionMessageHandler(this.reflectionManager, this.toLLM, this.toUser, {this.onTextRetry});

  @override
  Command? handle(AgentMessage agentMessage) {
    Reflection reflection = agentMessage.content as Reflection;
    if(reflection.isPass || reflection.count == reflection.maxCount) {
      AgentMessage agentUserMessage = AgentMessage(
        sessionId: agentMessage.sessionId,
        taskId: agentMessage.taskId,
        role: TextRoleType.AGENT,
        to: TextRoleType.USER,
        type: TextMessageType.TEXT,
        content: reflection.messageScore.message
      );
      return Command(toUser, agentUserMessage); // If Reflection pass or maxCount, forward to USER.
    } else {
      List<Content> userContentList = reflectionManager.userContentList;
      AgentMessage newAgentMessage = AgentMessage(
        sessionId: agentMessage.sessionId,
        taskId: agentMessage.taskId,
        role: TextRoleType.AGENT,
        to: TextRoleType.ASSISTANT,
        type: TextMessageType.CONTENT_LIST,
        content: userContentList
      );
      if(reflectionManager.shouldReflect) {
        if(onTextRetry != null) onTextRetry!(agentMessage);
        reflectionManager.retry();
      }
      return Command(toLLM, newAgentMessage); // Reset User messages request to LLM.
    }
  }
}