import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'exception.g.dart';

@JsonSerializable(createFactory: false)
class StrategyNotExistException implements Exception {
  final int code = 422;
  late String message;

  StrategyNotExistException({required String source, required String strategy}){
    this.message = "Strategy: `$source`-`$strategy` Not Exist.";
  }

  Map<String, dynamic> toJson() => _$StrategyNotExistExceptionToJson(this);

  @override
  String toString() {
    return jsonEncode(this.toJson());
  }
}

@JsonSerializable(createFactory: false)
class TaskRejectException implements Exception {
  final int code = 409;
  late String message;

  TaskRejectException({required String taskId, required String strategy}){
    this.message = "Task `$taskId` reject for strategy: $strategy";
  }

  Map<String, dynamic> toJson() => _$TaskRejectExceptionToJson(this);

  @override
  String toString() {
    return jsonEncode(this.toJson());
  }
}