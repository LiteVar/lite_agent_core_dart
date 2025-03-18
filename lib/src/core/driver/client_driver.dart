import 'dart:async';
import 'package:opentool_dart/opentool_dart.dart';

class ClientDriver extends OpenToolDriver {
  void Function(FunctionCall functionCall) listenClientFunctionCall;
  int timeout;
  Completer<ToolReturn>? _toolReturnCompleter;

  ClientDriver(this.listenClientFunctionCall, {this.timeout = 60});

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {
    _toolReturnCompleter = Completer<ToolReturn>();
    listenClientFunctionCall(functionCall);

    return await _toolReturnCompleter!.future.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        if (!_toolReturnCompleter!.isCompleted) {
          ToolReturn toolReturn = ToolReturn(id: functionCall.id, result: {"error": "Function `${functionCall.toJson()}` timeout after ${timeout}s."},);
          _toolReturnCompleter!.complete(toolReturn);
        }
        return _toolReturnCompleter!.future;
      },
    );
  }

  void callback(ToolReturn toolReturn) {
    if (_toolReturnCompleter != null && !_toolReturnCompleter!.isCompleted) {
      _toolReturnCompleter!.complete(toolReturn);
    }
  }
}