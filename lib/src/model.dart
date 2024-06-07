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
  static String TOOL = "tool";
}

// enum AgentMessageType {
//   TEXT,               // String
//   IMAGE_URL,          // URL String
//   FUNCTION_CALL_LIST, // List<FunctionCall>
//   TOOL_RETURN         // Map<String, dynamic>
// }

class AgentMessageType {
  static String TEXT = "text";
  static String IMAGE_URL = "image_url";
  static String FUNCTION_CALL_LIST = "function_call_list";
  static String TOOL_RETURN = "tool_return";
}

class FunctionCall {
  late String id;
  late String name;
  late Map<String, dynamic> parameters;

  FunctionCall({required this.id, required this.name, required this.parameters});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parameters': parameters
    };
  }
}

class ToolReturn {
  late String id;
  late Map<String, dynamic> result;

  ToolReturn({required this.id, required this.result});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'resutl': result
    };
  }
}

class AgentMessage {
  late String from;
  late String to;
  late String type;
  late dynamic message;
  int tokenUsage = 0; //When role is llm, this is current llm calling token usage
  AgentMessage({required this.from, required this.to,required this.type, required this.message, this.tokenUsage = 0});

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'type': type,
    'message': message,
    'tokenUsage': tokenUsage,
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