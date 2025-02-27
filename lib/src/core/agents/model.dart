import '../llm/model.dart';

class Message {
  String sessionId;
  String role;
  String to;
  String type;
  DateTime createTime = DateTime.now();
  Message({
    required this.sessionId,
    required this.role,
    required this.to,
    required this.type
  });
}

class AgentMessageBase extends Message {
  dynamic message;
  AgentMessageBase({
    required super.sessionId,
    required super.role,
    required super.to,
    required super.type,
    required this.message
  });
}

class AgentMessage extends AgentMessageBase {
  String taskId;
  Completions? completions;
  AgentMessage({
    required super.sessionId,
    required this.taskId,
    required super.role,
    required super.to,
    required super.type,
    required super.message,
    this.completions
  });
}

class TaskStatus {
  String status;  // Follow TaskStatusType
  String taskId;
  Map<String, dynamic>? description;

  TaskStatus({required this.status, required this.taskId, this.description});

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if(description != null)'description': description
    };
  }
}

class AgentMessageChunk extends Message {
  String taskId;
  dynamic part;

  AgentMessageChunk({required super.sessionId, required this.taskId, required super.role, required super.to, required super.type, required this.part});
}

