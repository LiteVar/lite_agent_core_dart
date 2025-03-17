import 'dart:async';
import 'package:opentool_dart/opentool_dart.dart';

class ClientDriver extends OpenToolDriver {
  void Function(FunctionCall functionCall) listenClientFunctionCall;

  final Completer<ToolReturn> _toolReturnCompleter = Completer<ToolReturn>();

  ClientDriver(this.listenClientFunctionCall);

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {
    listenClientFunctionCall(functionCall);
    return _toolReturnCompleter.future;
  }

  void callback(ToolReturn toolReturn) {
    if (!_toolReturnCompleter.isCompleted) {
      _toolReturnCompleter.complete(toolReturn);
    }
  }

}