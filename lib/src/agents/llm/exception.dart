import 'package:json_annotation/json_annotation.dart';

part 'exception.g.dart';

@JsonSerializable(createFactory: false)
class LLMException implements Exception {
  final int code;
  final String message;

  LLMException({
    required this.code,
    required this.message,
  });

  Map<String, dynamic> toJson() => _$LLMExceptionToJson(this);
}