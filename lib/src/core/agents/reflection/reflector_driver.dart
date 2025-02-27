import 'package:opentool_dart/opentool_dart.dart';

class ReflectorDriver extends ToolDriver {

  static const String reflectFunction = "reflect";
  static const String scoreKey = "score";
  static const String descriptionKey = "description";

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
      description: "set reflect score, and add description.",
      parameters: [
        Parameter(name: scoreKey, description: "Reflect score between 0-10 in integer type.", schema: Schema(type: "integer"), required: true),
        Parameter(name: descriptionKey, description: "Describe the basis for the reflection score.", schema: Schema(type: "string"), required: false)
      ]
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