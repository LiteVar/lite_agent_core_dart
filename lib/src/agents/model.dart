import '../llm/model.dart';

class Message {
  String from;
  String to;
  String type;
  dynamic message;
  DateTime createTime = DateTime.now();
  Message({
    required this.from,
    required this.to,
    required this.type,
    required this.message
  });
}

class AgentMessage extends Message{
  String taskId;
  Completions? completions;
  AgentMessage({
    required this.taskId,
    required super.from,
    required super.to,
    required super.type,
    required super.message,
    this.completions
  });
}

class TaskStatusType {
  static const String START = "[TASK_START]";
  static const String STOP = "[TASK_STOP]";
  static const String DONE = "[TASK_DONE]";
}
