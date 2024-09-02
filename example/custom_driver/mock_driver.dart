import 'package:opentool_dart/opentool_dart.dart';

import 'mock_util.dart';

class MockDriver extends OpenToolDriver {
  MockUtil mockAPI = MockUtil();
  MockDriver(super.openTool);

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async{
    String functionName = functionCall.name;
    if(functionName == "count") {
      int count = mockAPI.count();
      return ToolReturn(id: functionCall.id, result: {"count": count});
    } else if(functionName == "create") {
      String text = functionCall.parameters["text"] as String;
      int id = mockAPI.create(text);
      return ToolReturn(id: functionCall.id, result: {"id": id});
    } else if(functionName == "read") {
      int id = functionCall.parameters["id"] as int;
      String text = mockAPI.read(id);
      return ToolReturn(id: functionCall.id, result: {"text": text});
    } else if(functionName == "update") {
      int id = functionCall.parameters["id"] as int;
      String text = functionCall.parameters["text"] as String;
      mockAPI.update(id, text);
      return ToolReturn(id: functionCall.id, result: {"result": "Update successfully."});
    } else if(functionName == "delete") {
      int id = functionCall.parameters["id"] as int;
      mockAPI.delete(id);
      return ToolReturn(id: functionCall.id, result: {"result": "Delete successfully."});
    } else {
      return ToolReturn(id: functionCall.id, result: {"error": "Not Support function"});
    }
  }
}