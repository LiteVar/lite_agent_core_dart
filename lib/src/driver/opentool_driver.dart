import 'tool_driver.dart';
import 'package:opentool_dart/opentool_dart.dart';

abstract class OpenToolDriver extends ToolDriver {
  OpenTool openTool;

  OpenToolDriver(this.openTool);

  @override
  List<FunctionModel> parse() {
    return openTool.functions;
  }

  @override
  bool hasFunction(String functionName) => openTool.functions
      .where(
          (FunctionModel functionModel) => functionModel.name == functionName)
      .isNotEmpty;
}
