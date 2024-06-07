import 'tool_interface.dart';
import 'package:opentool_dart/opentool_dart.dart';
import 'package:opentool_dart/src/model/function_model.dart';

abstract class OpenToolParser extends ToolRunner {
  OpenTool openTool;

  OpenToolParser(this.openTool);

  @override
  List<FunctionModel> parse() {
    return openTool.functions;
  }

}

abstract class OpenToolTool extends OpenToolParser implements ToolRunner {

  OpenToolTool(super.openTool);

}
