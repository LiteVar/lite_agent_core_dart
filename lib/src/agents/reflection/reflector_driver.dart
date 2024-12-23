import 'package:opentool_dart/opentool_dart.dart';

class ReflectorDriver extends ToolDriver {

  static const String reflectFunction = "reflect";
  static const String scoreKey = "score";

  @override
  bool hasFunction(String functionName) {
    switch(functionName) {
      case reflectFunction: return true;
      default: return false;
    }
  }

  @override
  List<FunctionModel> parse() {
    FunctionModel functionModel = FunctionModel(
      name: reflectFunction,
      description: "set reflect score",
      parameters: [Parameter(name: scoreKey, description: "reflect score between 0-10 in integer type.", schema: Schema(type: "integer"), required: true)]
    );
    return [functionModel];
  }

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {
    if(functionCall.name == reflectFunction) {
      return ToolReturn(id: functionCall.id, result: functionCall.parameters);
    } else {
      return ToolReturn(id: functionCall.id, result: FunctionNotSupportedException(functionName: functionCall.name).toJson());
    }
  }

}