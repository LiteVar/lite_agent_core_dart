import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'exception.g.dart';

@JsonSerializable(createFactory: false)
class FunctionCallTimeoutException implements Exception {
  final int code = 408;
  late String message;

  FunctionCallTimeoutException({ required functionName }) {
    this.message = "Function `${functionName}` request timeout";
  }

  Map<String, dynamic> toJson() => _$FunctionCallTimeoutExceptionToJson(this);

  @override
  String toString() {
    return jsonEncode(this.toJson());
  }
}