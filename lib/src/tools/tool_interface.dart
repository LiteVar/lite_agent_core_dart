import 'package:lite_agent_core/lite_agent_core.dart';
import 'package:opentool_dart/opentool_dart.dart';

String TOOL_RETURN_FINISH = "tool_return_finish";

abstract class ToolRunner {
  List<FunctionModel> parse();
  String convertToFunctionName(String toolName) => toolName;
  String convertToToolName(String functionName) => functionName;
  bool hasFunction(String functionName);
  Future<ToolReturn> call(FunctionCall functionCall);
}