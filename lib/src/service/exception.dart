import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'exception.g.dart';

@JsonSerializable(createFactory: false)
class SessionAgentNotFoundException implements Exception {
  final int code = 404;
  late String message;

  SessionAgentNotFoundException({ required String sessionId }) {
    this.message = "SessionId `${sessionId}` Agent Not Found";
  }

  Map<String, dynamic> toJson() => _$SessionAgentNotFoundExceptionToJson(this);

  @override
  String toString() {
    return jsonEncode(this.toJson());
  }
}

@JsonSerializable(createFactory: false)
class AgentNotFoundException implements Exception {
  final int code = 404;
  late String message;

  AgentNotFoundException({ required String agentId }) {
    this.message = "AgentId `${agentId}` Agent Not Found";
  }

  Map<String, dynamic> toJson() => _$AgentNotFoundExceptionToJson(this);

  @override
  String toString() {
    return jsonEncode(this.toJson());
  }
}

@JsonSerializable(createFactory: false)
class AgentNameException implements Exception {
  final int code = 500;
  late String message;

  AgentNameException({
    required String agentName,
  }){
    this.message = "Name exception: `$agentName`. Must be a-z, A-Z, 0-9, or contain underscores and dashes, with a maximum length of 64.";
  }

  Map<String, dynamic> toJson() => _$AgentNameExceptionToJson(this);

  @override
  String toString() {
    return jsonEncode(this.toJson());
  }
}

@JsonSerializable(createFactory: false)
class OpenToolIdNotFoundException implements Exception {
  final int code = 404;
  late String message;

  OpenToolIdNotFoundException({required String openToolId,}){
    this.message = "OpenToolId not found: `$openToolId`";
  }

  Map<String, dynamic> toJson() => _$OpenToolIdNotFoundExceptionToJson(this);

  @override
  String toString() => jsonEncode(this.toJson());
}