import 'package:json_annotation/json_annotation.dart';

part 'exception.g.dart';

@JsonSerializable(createFactory: false)
class AgentNotFoundException implements Exception {
  final int code = 404;
  final String message;

  AgentNotFoundException({
    required this.message,
  });

  Map<String, dynamic> toJson() => _$AgentNotFoundExceptionToJson(this);
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
}