import 'tool_runner.dart';
import 'package:opentool_dart/opentool_dart.dart';

abstract class OpenToolRunner extends ToolRunner {
  OpenTool openTool;

  OpenToolRunner(this.openTool);

  @override
  List<FunctionModel> parse() {
    return openTool.functions;
  }

}