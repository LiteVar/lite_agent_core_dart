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
    List<Content> userContentList = agentMessage.message as List<Content>;
    AgentMessage newAgentMessage = AgentMessage(
      sessionId: agentMessage.sessionId,
      taskId: agentMessage.taskId,
      from: TextRoleType.AGENT,
      to: TextRoleType.LLM,
      type: TextMessageType.CONTENT_LIST,
      message: userContentList
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

  LLMMessageHandler(this.reflectionManager, this.toReflection, this.toUser);

  @override
  Command? handle(AgentMessage agentMessage) {
    if (agentMessage.type == TextMessageType.TEXT) {
      if(reflectionManager.shouldReflect) {
        AgentMessage reflectionMessage = AgentMessage(
            sessionId: agentMessage.sessionId,
            taskId: agentMessage.taskId,
            from: TextRoleType.AGENT,
            to: TextRoleType.REFLECTION,
            type: TextMessageType.TEXT,
            message: agentMessage.message
        );
        return Command(toReflection, reflectionMessage); // If LLM return text, and should reflect, forward to REFLECTION.
      } else {
        AgentMessage agentUserMessage = AgentMessage(
            sessionId: agentMessage.sessionId,
            taskId: agentMessage.taskId,
            from: TextRoleType.AGENT,
            to: TextRoleType.USER,
            type: TextMessageType.TEXT,
            message: agentMessage.message
        );
        return Command(toUser, agentUserMessage); // If LLM return text and NOT reflect, forward to USER.
      }
    } else if (agentMessage.type == TextMessageType.IMAGE_URL) {
      AgentMessage agentUserMessage = AgentMessage(
          sessionId: agentMessage.sessionId,
          taskId: agentMessage.taskId,
          from: TextRoleType.AGENT,
          to: TextRoleType.USER,
          type: TextMessageType.IMAGE_URL,
          message: agentMessage.message);
      return Command(toUser, agentUserMessage); // If LLM return image, forward to USER.
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
    Reflection reflection = agentMessage.message as Reflection;
    if(reflection.result.isPass || reflection.result.count == reflection.result.maxCount) {
      AgentMessage agentUserMessage = AgentMessage(
        sessionId: agentMessage.sessionId,
        taskId: agentMessage.taskId,
        from: TextRoleType.AGENT,
        to: TextRoleType.USER,
        type: TextMessageType.TEXT,
        message: reflection.result.messageScore.message
      );
      return Command(toUser, agentUserMessage); // If Reflection pass or maxCount, forward to USER.
    } else {
      List<Content> userContentList = reflectionManager.userContentList;
      AgentMessage newAgentMessage = AgentMessage(
        sessionId: agentMessage.sessionId,
        taskId: agentMessage.taskId,
        from: TextRoleType.AGENT,
        to: TextRoleType.LLM,
        type: TextMessageType.CONTENT_LIST,
        message: userContentList
      );
      if(reflectionManager.shouldReflect) {
        if(onTextRetry != null) onTextRetry!(agentMessage);
        reflectionManager.retry();
      }
      return Command(toLLM, newAgentMessage); // Reset User messages request to LLM.
    }
  }
}