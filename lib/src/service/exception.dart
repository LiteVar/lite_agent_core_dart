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