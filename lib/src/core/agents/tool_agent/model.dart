import 'package:opentool_dart/opentool_dart.dart';
import '../../driver/client_driver.dart';
import '../llm/model.dart';
import '../text_agent/model.dart';

class ToolRoleType {
  static const String DEVELOPER = TextRoleType.DEVELOPER; // system prompt
  static const String USER = TextRoleType.USER; // user
  static const String AGENT = TextRoleType.AGENT; // agent
  static const String ASSISTANT = TextRoleType.ASSISTANT; // llm
  static const String TOOL = AgentRoleType.TOOL; // external tools
  static const String CLIENT = TextRoleType.CLIENT; // external caller
  static const String REFLECTION = TextRoleType.REFLECTION; // reflection
}

class ToolMessageType {
  static String TEXT = TextMessageType.TEXT; //String
  static String IMAGE_URL = TextMessageType.IMAGE_URL; //String
  static String CONTENT_LIST = TextMessageType.CONTENT_LIST; //List<Content>
  static String FUNCTION_CALL_LIST = AgentMessageType.TOOL_CALLS; //List<FunctionCall>
  static String TOOL_RETURN = AgentMessageType.TOOL_RETURN; //ToolReturn
  static String TASK_STATUS = TextMessageType.TASK_STATUS; //TaskStatus
  static String FUNCTION_CALL = AgentMessageType.FUNCTION_CALL; //FunctionCall
}

class ToolStatusType {
  static const String START = "toolsStart";
  // static const String STOP = "toolStop";
  static const String DONE = "toolsDone";
  // static const String EXCEPTION = "toolException";
}

class ToolStatusDescription {
  List<String> functionCallIdList;

  ToolStatusDescription({this.functionCallIdList = const []});

  Map<String, dynamic> toJson() => {
    'functionCallIdList': functionCallIdList,
  };
}

class FunctionCallParam {
  String sessionId;
  String taskId;
  FunctionCall functionCall;
  FunctionCallParam({required this.sessionId, required this.taskId, required this.functionCall});
}

class ClientOpenTool {
  String opentool;
  int? timeout;
  void Function(String sessionId, ClientDriver clientDriver)? fetchClientDriver;

  ClientOpenTool({required this.opentool, this.timeout, this.fetchClientDriver});
}