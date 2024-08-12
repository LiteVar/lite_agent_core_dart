import '../llm/model.dart';
import '../session_agent/model.dart';

class TextRoleType {
  static const String SYSTEM = SessionRoleType.SYSTEM; // system prompt
  static const String USER = SessionRoleType.USER; // user
  static const String AGENT = SessionRoleType.AGENT; // agent
  static const String LLM = AgentRoleType.LLM; // llm
  static const String CLIENT = SessionRoleType.CLIENT; // external caller
}

class TextMessageType {
  static String TEXT = SessionMessageType.TEXT; //String
  static String IMAGE_URL = SessionMessageType.IMAGE_URL; //String
  static String CONTENT_LIST = SessionMessageType.CONTENT_LIST; //List<Content>
  static String EXCEPTION = "exception"; //Exception
}

class ExceptionMessage implements Exception {
  final int code;
  final String message;

  ExceptionMessage({
    required this.code,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message
    };
  }
}