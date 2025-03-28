import 'dart:io';
import 'package:opentool_dart/opentool_dart.dart';
import 'mock_driver.dart';

Future<void> main() async {
  Map<String, dynamic> createParams = {};
  FunctionCall functionCall = FunctionCall(id: "callId-0", name: "count", parameters: createParams);

  String jsonFileName = "mock-tool.json";
  String jsonPath = "${Directory.current.path}${Platform.pathSeparator}example${Platform.pathSeparator}custom_driver${Platform.pathSeparator}$jsonFileName";
  OpenTool openTool = await OpenToolLoader().loadFromFile(jsonPath);
  OpenToolDriver mockDriver = MockDriver().bind(openTool);

  ToolReturn toolReturn = await mockDriver.call(functionCall);
  print(toolReturn.toJson());
}