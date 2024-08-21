class LLMContentType {
  static const String TEXT = "text";
  static const String IMAGE_URL = "imageUrl";
}

class LLMContent {
  String type;
  String message;

  LLMContent({required this.type, required this.message});
}

class AgentRoleType {
  static const String SYSTEM = "system"; // system prompt
  static const String USER = "user"; // user
  static const String AGENT = "agent"; // agent
  static const String LLM = "llm"; // llm
  static const String TOOL = "tool"; // external tools
  static const String CLIENT = "client"; // external caller
}

class AgentMessageType {
  static const String TEXT = "text"; //String
  static const String IMAGE_URL = "imageUrl"; //String
  static const String FUNCTION_CALL_LIST = "functionCallList"; //List<FunctionCall>
  static const String TOOL_RETURN = "toolReturn"; //ToolReturn
  static const String CONTENT_LIST = "contentList"; //List<Content>
}

// class FunctionCall {
//   late String id;
//   late String name;
//   late Map<String, dynamic> parameters;
//
//   FunctionCall(
//       {required this.id, required this.name, required this.parameters});
//
//   factory FunctionCall.fromJson(Map<String, dynamic> json) {
//     return FunctionCall(
//         id: json['id'], name: json['name'], parameters: json['parameters']);
//   }
//
//   Map<String, dynamic> toJson() {
//     return {'id': id, 'name': name, 'parameters': parameters};
//   }
// }
//
// class ToolReturn {
//   late String id;
//   late Map<String, dynamic> result;
//
//   ToolReturn({required this.id, required this.result});
//
//   factory ToolReturn.fromJson(Map<String, dynamic> json) {
//     return ToolReturn(id: json['id'], result: json['result']);
//   }
//
//   Map<String, dynamic> toJson() {
//     return {'id': id, 'result': result};
//   }
// }