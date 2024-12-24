import '../llm/model.dart';

class Message {
  String sessionId;
  String from;
  String to;
  String type;
  dynamic message;
  DateTime createTime = DateTime.now();
  Message({
    required this.sessionId,
    required this.from,
    required this.to,
    required this.type,
    required this.message
  });
}

class AgentMessage extends Message {
  String taskId;
  Completions? completions;
  AgentMessage({
    required super.sessionId,
    required this.taskId,
    required super.from,
    required super.to,
    required super.type,
    required super.message,
    this.completions
  });
}

class TaskStatusType {
  static const String START = "start";
  static const String STOP = "stop";
  static const String DONE = "done";
  static const String EXCEPTION = "exception";
}

class TaskStatus {
  String status;  // Follow TaskStatusType
  Map<String, dynamic>? description;

  TaskStatus({required this.status, this.description});

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if(description != null)'description': description
    };
  }
}