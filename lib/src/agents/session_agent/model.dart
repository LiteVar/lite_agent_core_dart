import '../llm/model.dart';

class SessionMessageType {
  static String TEXT = AgentMessageType.TEXT; //String
  static String IMAGE_URL = AgentMessageType.IMAGE_URL; //String
  static String CONTENT_LIST = AgentMessageType.CONTENT_LIST; //List<Content>
}

class SessionRoleType {
  static const String SYSTEM = AgentRoleType.SYSTEM;
  static const String USER = AgentRoleType.USER;
  static const String AGENT = AgentRoleType.AGENT;
  static const String CLIENT = AgentRoleType.CLIENT;
}

class ContentType {
  static const String TEXT = LLMContentType.TEXT;
  static const String IMAGE_URL = LLMContentType.IMAGE_URL;
}

class Content extends LLMContent {
  Content({required super.type, required super.message});

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'message': message
    };
  }
}