class HttpConfig {
  String host;
  String port;
  String pathPrefix;
  HttpConfig(
      {required this.host, required this.port, required this.pathPrefix});
}

class LLMConfig {
  String baseUrl;
  String apiKey;
  String model;
  double temperature;
  int maxTokens;
  double topP;
  LLMConfig(
      {required this.baseUrl,
      required this.apiKey,
      required this.model,
      this.temperature = 0.0,
      this.maxTokens = 4096,
      this.topP = 1.0});
}

enum ApiKeyType { basic, bearer }

class AgentRole {
  static String SYSTEM = "system"; // 系统，用于存放预置的说明
  static String USER = "user"; // 用户
  static String AGENT = "agent"; // Agent本身
  static String LLM = "llm"; // 大模型
  static String TOOL = "tool"; // 外部工具
  static String CLIENT = "client"; // 调用的外部程序，承载当前操作状态，例如[START]、[STOP]、[DONE]
}

class TaskStatus {
  static String START = "[TASK_START]";
  static String STOP = "[TASK_STOP]";
  static String DONE = "[TASK_DONE]";
}

class FunctionCall {
  late String id;
  late String name;
  late Map<String, dynamic> parameters;

  FunctionCall(
      {required this.id, required this.name, required this.parameters});

  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
        id: json['id'], name: json['name'], parameters: json['parameters']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'parameters': parameters};
  }
}

class ToolsStatus {
  static String START = "[TOOLS_START]";
  static String DONE = "[TOOLS_DONE]";
}

class ToolReturn {
  late String id;
  late Map<String, dynamic> result;

  ToolReturn({required this.id, required this.result});

  factory ToolReturn.fromJson(Map<String, dynamic> json) {
    return ToolReturn(id: json['id'], result: json['result']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'result': result};
  }
}

enum ContentType { text, imageUrl }

class Content {
  late ContentType type;
  late String message;

  Content({required this.type, required this.message});

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'message': message,
      };
}

enum AgentMessageType {
  text, //String
  imageUrl, //String
  functionCallList, //List<FunctionCall>
  toolReturn, //ToolReturn
  contentList //List<Content>
}

class AgentMessage {
  late String from;
  late String to;
  late AgentMessageType type;
  late dynamic message;
  Completions? completions;
  DateTime createTime = DateTime.now();
  AgentMessage(
      {required this.from,
      required this.to,
      required this.type,
      required this.message,
      this.completions});

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'type': type,
        'message': message,
        if (completions != null) 'completions': completions!.toJson(),
        'createTime': createTime.toIso8601String()
      };
}

class Completions {
  TokenUsage
      tokenUsage; //When role is llm, this is current llm calling token usage
  String
      id; //When role is llm, this is current /chat/completions return message id
  String model;

  Completions(
      {required this.tokenUsage, required this.id, required this.model});

  Map<String, dynamic> toJson() =>
      {'id': id, 'tokenUsage': tokenUsage.toJson(), 'model': model};
}

class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  TokenUsage(
      {required this.promptTokens,
      required this.completionTokens,
      required this.totalTokens});

  Map<String, dynamic> toJson() => {
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
        'totalTokens': totalTokens
      };
}

class AgentPrompt {
  final String text;
  AgentPrompt({required this.text});

  Map<String, dynamic> toJson() => {'text': text};

  factory AgentPrompt.fromJson(Map<String, dynamic> json) {
    return AgentPrompt(text: json['text'] as String);
  }
}
