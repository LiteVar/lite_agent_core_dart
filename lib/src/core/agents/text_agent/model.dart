import '../llm/model.dart';
import '../reflection/model.dart';
import '../session_agent/model.dart';

class TextRoleType {
  static const String DEVELOPER = SessionRoleType.SYSTEM; // system prompt
  static const String USER = SessionRoleType.USER; // user
  static const String AGENT = SessionRoleType.AGENT; // agent
  static const String ASSISTANT = AgentRoleType.LLM; // llm
  static const String CLIENT = SessionRoleType.CLIENT; // external caller
  static const String REFLECTION = "reflection";
}

class TextMessageType {
  static String TEXT = SessionMessageType.TEXT; //String
  static String IMAGE_URL = SessionMessageType.IMAGE_URL; //String
  static String CONTENT_LIST = SessionMessageType.CONTENT_LIST; //List<Content>
  static String TASK_STATUS = SessionMessageType.TASK_STATUS; //TaskStatus
  static String EXCEPTION = "exception"; //Exception
  static String REFLECTION = "reflection";
}

class Reflection {
  final bool isPass;
  final MessageScore messageScore;
  final int passScore;
  final int count;
  final int maxCount;

  Reflection({
    required this.isPass,
    required this.messageScore,
    required this.passScore,
    required this.count,
    required this.maxCount,
  });
}

class TextStatusType {
  static const String CHUNK_DONE = "chunkDone";
}

// class Reflection {
//   final ReflectResult result;
//   Completions? completions;
//
//   Reflection({
//     required this.result,
//     this.completions
//   });
// }