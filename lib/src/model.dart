
class HttpConfig {
  String host;
  String port;
  String pathPrefix;
  HttpConfig({required this.host, required this.port, required this.pathPrefix});
}

class LLMConfig {
  String baseUrl;
  String apiKey;
  String model;
  LLMConfig({required this.baseUrl, required this.apiKey, required this.model});
}

// 在Agent系统内的角色
// enum AgentRole {
//   SYSTEM, // 系统，用于存放预置的说明
//   USER,   // 用户
//   AGENT,  // Agent本身
//   LLM,    // 大模型
//   TOOL    //外部工具
// }

class AgentRole {
  static String SYSTEM = "system"; // 系统，用于存放预置的说明
  static String USER = "user";   // 用户
  static String AGENT = "agent";  // Agent本身
  static String LLM = "llm";    // 大模型
  static String TOOL = "tool";  // 外部工具
  static String CLIENT = "client";  // 调用的外部程序，承载当前操作状态，例如[START]、[STOP]、[DONE]
}

class TaskStatus {
  static String START = "[TASK_START]";
  static String STOP = "[TASK_STOP]";
  static String DONE = "[TASK_DONE]";
}

// enum AgentMessageType {
//   TEXT,               // String
//   IMAGE_URL,          // URL String
//   FUNCTION_CALL_LIST, // List<FunctionCall>
//   TOOL_RETURN         // Map<String, dynamic>
// }

// class AgentMessageType {
//   static String TEXT = "text";
//   static String IMAGE_URL = "image_url";
//   static String FUNCTION_CALL_LIST = "function_call_list";
//   static String TOOL_RETURN = "tool_return";
// }

enum AgentMessageType {
  text,
  imageUrl,
  functionCallList,
  toolReturn
}

class FunctionCall {
  late String id;
  late String name;
  late Map<String, dynamic> parameters;

  FunctionCall({required this.id, required this.name, required this.parameters});

  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
        id: json['id'],
        name: json['name'],
        parameters: json['parameters']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parameters': parameters
    };
  }
}

class ToolReturn {
  static String DONE = "[TOOL_RETURN_DONE]";

  late String id;
  late Map<String, dynamic> result;

  ToolReturn({required this.id, required this.result});

  factory ToolReturn.fromJson(Map<String, dynamic> json) {
    return ToolReturn(
        id: json['id'],
        result: json['result']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'result': result
    };
  }
}

class AgentMessage {
  late String from;
  late String to;
  late AgentMessageType type;
  late dynamic message;
  TokenUsage? tokenUsage; //When role is llm, this is current llm calling token usage
  DateTime createTime  = DateTime.now();
  AgentMessage({required this.from, required this.to,required this.type, required this.message, this.tokenUsage});

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'type': type,
    'message': message,
    'tokenUsage': tokenUsage == null ? null: tokenUsage!.toJson(),
    'createTime': createTime.toIso8601String()
  };
}

class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  TokenUsage({required this.promptTokens, required this.completionTokens, required this.totalTokens});

  Map<String, dynamic> toJson() => {
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens
  };

}

// enum UserAgentChatRole {
//   user,
//   agent,
// }

// class UserAgentChatMessage {
//   late UserAgentChatRole role;
//   late String text;
//   UserAgentChatMessage({required this.role, required this.text});
//
//   Map<String, dynamic> toJson() => {
//     'role': role,
//     'text': text
//   };
// }



class AgentPrompt {
  final String text;
  AgentPrompt({required this.text});

  Map<String, dynamic> toJson() => {
    'text': text
  };

  factory AgentPrompt.fromJson(Map<String, dynamic> json) {
    return AgentPrompt(
        text: json['text'] as String
    );
  }
}