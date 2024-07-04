import 'package:opentool_dart/opentool_dart.dart';
import '../model.dart';

abstract class ToolRunner {
  List<FunctionModel> parse();
  String convertToFunctionName(String toolName) => toolName;
  String convertToToolName(String functionName) => functionName;
  bool hasFunction(String functionName);
  Future<ToolReturn> call(FunctionCall functionCall);
}
