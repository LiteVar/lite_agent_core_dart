import 'package:opentool_dart/opentool_dart.dart';
import '../agents/llm/model.dart';

abstract class ToolDriver {
  List<FunctionModel> parse();
  bool hasFunction(String functionName);
  Future<ToolReturn> call(FunctionCall functionCall);
}
