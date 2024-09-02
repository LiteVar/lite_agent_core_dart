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