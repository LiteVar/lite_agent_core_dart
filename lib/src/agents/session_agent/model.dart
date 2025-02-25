import '../llm/model.dart';

class SessionMessageType {
  static String TEXT = AgentMessageType.TEXT; //String
  static String IMAGE_URL = AgentMessageType.IMAGE_URL; //String
  static String CHUNK = AgentMessageType.CHUNK; //String
  static String CONTENT_LIST = AgentMessageType.CONTENT_LIST; //List<Content>
  static String TASK_STATUS = AgentMessageType.TASK_STATUS; //TaskStatus
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

class TaskStatusType {
  static const String START = "start";
  static const String STOP = "stop";
  static const String DONE = "done";
  static const String EXCEPTION = "exception";
}

class Content extends LLMContent {
  Content({required super.type, required super.message});

  Map<String, dynamic> toJson() => {
    'type': type,
    'message': message
  };

  factory Content.fromJson(Map<String, dynamic> json) => Content(
      type: json["type"],
      message: json["message"]
  );
}

class ContentsTask {
  String taskId;
  List<Content> contentList;

  ContentsTask({required this.taskId, required this.contentList});
}

// class TaskStatusDescription {
//   String taskId;
//
//   TaskStatusDescription({required this.taskId});
//
//   Map<String, dynamic> toJson() => {
//     'taskId': taskId,
//   };
// }