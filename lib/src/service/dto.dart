import 'package:json_annotation/json_annotation.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../../lite_agent_core.dart';
import 'exception.dart';

part 'dto.g.dart';

@JsonSerializable()
class SessionDto {
  String sessionId;

  SessionDto({required this.sessionId});

  factory SessionDto.fromJson(Map<String, dynamic> json) => _$SessionDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SessionDtoToJson(this);
}

@JsonSerializable()
class SessionNameDto extends SessionDto {
  @JsonKey(includeIfNull: false) String? name; // OpenAI: The name of the function to be called. Must be a-z, A-Z, 0-9, or contain underscores and dashes, with a maximum length of 64.
  @JsonKey(includeIfNull: false) String? description;

  SessionNameDto({required super.sessionId, String? name, this.description}) {
    final regex = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');
    if(name != null && !regex.hasMatch(name)) {
      throw AgentNameException(agentName: name);
    }
  }

  factory SessionNameDto.fromJson(Map<String, dynamic> json) => _$SessionNameDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SessionNameDtoToJson(this);
}

@JsonSerializable()
class SimpleCapabilityDto {
  LLMConfigDto llmConfig;
  String systemPrompt;

  SimpleCapabilityDto({
    required this.llmConfig,
    required this.systemPrompt
  });

  factory SimpleCapabilityDto.fromJson(Map<String, dynamic> json) => _$SimpleCapabilityDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SimpleCapabilityDtoToJson(this);
}

@JsonSerializable()
class CapabilityDto extends SimpleCapabilityDto {
  @JsonKey(includeIfNull: false) List<OpenSpecDto>? openSpecList;
  @JsonKey(includeIfNull: false) ClientOpenToolDto? clientOpenTool;
  @JsonKey(includeIfNull: false) List<SessionNameDto>? sessionList;
  @JsonKey(includeIfNull: false) List<ReflectPromptDto>? reflectPromptList;
  int timeoutSeconds;
  String taskPipelineStrategy;
  @JsonKey(includeIfNull: false) String? toolPipelineStrategy;

  CapabilityDto({
    required super.llmConfig,
    required super.systemPrompt,
    this.openSpecList,
    this.clientOpenTool,
    this.sessionList,
    this.reflectPromptList,
    this.timeoutSeconds = 3600,
    this.taskPipelineStrategy  = PipelineStrategyType.PARALLEL,
    this.toolPipelineStrategy
  });

  factory CapabilityDto.fromJson(Map<String, dynamic> json) => _$CapabilityDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CapabilityDtoToJson(this);
}

class Protocol {
  static const String OPENAPI = "openapi";
  static const String OPENMODBUS = "openmodbus";
  static const String JSONRPCHTTP = "jsonrpcHttp";
  static const String OPENTOOL = "opentool";
  static const String SERIALPORT = "serialport";
  static const String MCP_STDIO_TOOLS = "mcpStdioTools";
}

@JsonSerializable()
class OpenSpecDto {
  String openSpec;
  @JsonKey(includeIfNull: false) ApiKeyDto? apiKey;
  String protocol;
  @JsonKey(includeIfNull: false) String? openToolId; //When protocol is open tool, this is the tool id

  OpenSpecDto({required this.openSpec, this.apiKey, required this.protocol, this.openToolId});

  factory OpenSpecDto.fromJson(Map<String, dynamic> json) => _$OpenSpecDtoFromJson(json);

  Map<String, dynamic> toJson() => _$OpenSpecDtoToJson(this);
}

@JsonSerializable()
class LLMConfigDto {
  String baseUrl;
  String apiKey;
  String model;
  double temperature;
  int maxTokens;
  double topP;

  LLMConfigDto({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.temperature = 0.0,
    this.maxTokens = 4096,
    this.topP = 1.0
  });

  factory LLMConfigDto.fromJson(Map<String, dynamic> json) => _$LLMConfigDtoFromJson(json);

  Map<String, dynamic> toJson() => _$LLMConfigDtoToJson(this);

  factory LLMConfigDto.fromModel(LLMConfig llmConfig) => LLMConfigDto(
    baseUrl: llmConfig.baseUrl,
    apiKey: llmConfig.apiKey,
    model: llmConfig.model,
    temperature: llmConfig.temperature,
    maxTokens: llmConfig.maxTokens,
    topP: llmConfig.topP
  );

  LLMConfig toModel() => LLMConfig(
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    temperature: temperature,
    maxTokens: maxTokens,
    topP: topP
  );
}

@JsonSerializable(explicitToJson: true)
class AgentMessageDto {
  String sessionId;
  String taskId;
  String role;
  String to;
  String type;
  dynamic content;

  @JsonKey(includeIfNull: false)
  CompletionsDto? completions; //When role is llm, this is current llm calling token usage

  DateTime createTime;

  AgentMessageDto({
    required this.sessionId,
    required this.taskId,
    required this.role,
    required this.to,
    required this.type,
    required this.content,
    this.completions,
    required this.createTime
  });

  factory AgentMessageDto.fromJson(Map<String, dynamic> json) => _$AgentMessageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AgentMessageDtoToJson(this);

  factory AgentMessageDto.fromModel(AgentMessage agentMessage) {

    dynamic message;

    switch (agentMessage.type) {
      case AgentMessageType.CONTENT_LIST: message = (agentMessage.content as List<Content>).map((content) => ContentDto.fromModel(content)).toList();break;
      case AgentMessageType.FUNCTION_CALL: message = agentMessage.content as FunctionCall;break;
      case AgentMessageType.TOOL_CALLS: message = (agentMessage.content as List<FunctionCall>);break;
      case AgentMessageType.TOOL_RETURN: message = agentMessage.content as ToolReturn;break;
      case AgentMessageType.REFLECTION: message = ReflectionDto.fromModel(agentMessage.content as Reflection);break;
      case AgentMessageType.TASK_STATUS: message = TaskStatusDto.fromModel(agentMessage.content as TaskStatus);break;
      default: message = agentMessage.content;
    }

    return AgentMessageDto(
      sessionId: agentMessage.sessionId,
      taskId: agentMessage.taskId,
      role: agentMessage.role,
      to: agentMessage.to,
      type: agentMessage.type,
      content: message,
      completions: agentMessage.completions == null ? null : CompletionsDto.fromModel(agentMessage.completions!),
      createTime: agentMessage.createTime);
  }
}

// @JsonSerializable()
// class FunctionCallDto {
//   late String id;
//   late String name;
//   late Map<String, dynamic> parameters;
//
//   FunctionCallDto({required this.id, required this.name, required this.parameters});
//
//   // factory FunctionCallDto.fromModel(FunctionCall functionCall) => FunctionCallDto(
//   //   id: functionCall.id,
//   //   name: functionCall.name,
//   //   parameters: functionCall.parameters
//   // );
//
//   factory FunctionCallDto.fromJson(Map<String, dynamic> json) => _$FunctionCallDtoFromJson(json);
//
//   Map<String, dynamic> toJson() => _$FunctionCallDtoToJson(this);
// }

// @JsonSerializable()
// class ToolReturnDto {
//   late String id;
//   late Map<String, dynamic> result;
//
//   ToolReturnDto({required this.id, required this.result});
//
//   factory ToolReturnDto.fromModel(ToolReturn toolReturn) => ToolReturnDto(
//       id: toolReturn.id,
//       result: toolReturn.result
//   );
//
//   ToolReturn toModel() => ToolReturn(id: id, result: result);
//
//   factory ToolReturnDto.fromJson(Map<String, dynamic> json) => _$ToolReturnDtoFromJson(json);
//
//   Map<String, dynamic> toJson() => _$ToolReturnDtoToJson(this);
// }

@JsonSerializable()
class CompletionsDto {
  TokenUsageDto usage;

  /// When role is llm, this is current llm calling token usage
  String id;

  /// When role is llm, this is current /chat/completions return message id
  String model;

  CompletionsDto({required this.usage, required this.id, required this.model});

  factory CompletionsDto.fromJson(Map<String, dynamic> json) => _$CompletionsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CompletionsDtoToJson(this);

  factory CompletionsDto.fromModel(Completions completions) => CompletionsDto(
      usage: TokenUsageDto.fromModel(completions.tokenUsage),
      id: completions.id,
      model: completions.model
  );
}

@JsonSerializable()
class TokenUsageDto {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  TokenUsageDto({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens
  });

  factory TokenUsageDto.fromJson(Map<String, dynamic> json) => _$TokenUsageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$TokenUsageDtoToJson(this);

  factory TokenUsageDto.fromModel(TokenUsage tokenUsage) => TokenUsageDto(
    promptTokens: tokenUsage.promptTokens,
    completionTokens: tokenUsage.completionTokens,
    totalTokens: tokenUsage.totalTokens
  );
}

@JsonSerializable()
class ApiKeyDto {
  ApiKeyType type;
  String apiKey;

  ApiKeyDto({required this.type, required this.apiKey});

  factory ApiKeyDto.fromJson(Map<String, dynamic> json) => _$ApiKeyDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ApiKeyDtoToJson(this);
}

@JsonSerializable()
class UserTaskDto {
  @JsonKey(includeIfNull: false)
  String? taskId;
  List<ContentDto> contentList;
  bool? stream;

  UserTaskDto({this.taskId, required this.contentList, this.stream});

  factory UserTaskDto.fromJson(Map<String, dynamic> json) {
    if(json["taskId"] != null && (json["taskId"] as String).length > 36) {
      throw FormatException("taskId length should not more then 36");
    }
    return _$UserTaskDtoFromJson(json);
  }

  Map<String, dynamic> toJson() => _$UserTaskDtoToJson(this);
}

// enum UserMessageDtoType { text, imageUrl }

// @JsonSerializable()
// class UserMessageDto {
//   UserMessageDtoType type;
//   String message;
//
//   UserMessageDto({required this.type, required this.message});
//
//   factory UserMessageDto.fromJson(Map<String, dynamic> json) => _$UserMessageDtoFromJson(json);
//
//   Map<String, dynamic> toJson() => _$UserMessageDtoToJson(this);
// }

@JsonSerializable()
class SessionTaskDto {
  String sessionId;

  @JsonKey(includeIfNull: false)
  String? taskId;

  SessionTaskDto({required this.sessionId, this.taskId});

  factory SessionTaskDto.fromJson(Map<String, dynamic> json) => _$SessionTaskDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SessionTaskDtoToJson(this);
}

@JsonSerializable()
class ReflectScoreDto {
  int score;

  @JsonKey(includeIfNull: false)
  String? description;
  ReflectScoreDto({required this.score, this.description});

  factory ReflectScoreDto.fromModel(ReflectScore reflectScore) => ReflectScoreDto(
      score: reflectScore.score,
      description: reflectScore.description
  );

  factory ReflectScoreDto.fromJson(Map<String, dynamic> json) => _$ReflectScoreDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ReflectScoreDtoToJson(this);
}

@JsonSerializable()
class MessageScoreDto {
  List<ContentDto> contentList;
  String messageType; //Follow AgentMessage.type
  String message;
  List<ReflectScoreDto> reflectScoreList;
  MessageScoreDto({required this.contentList, required this.messageType, required this.message, required this.reflectScoreList});

  factory MessageScoreDto.fromModel(MessageScore messageScore) => MessageScoreDto(
    contentList: messageScore.contentList.map((content)=>ContentDto(type: content.type, message: content.message)).toList(),
    messageType: messageScore.messageType,
    message: messageScore.message,
    reflectScoreList: messageScore.reflectScoreList.map((reflectScore)=>ReflectScoreDto(score: reflectScore.score, description: reflectScore.description)).toList()
  );

  factory MessageScoreDto.fromJson(Map<String, dynamic> json) => _$MessageScoreDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MessageScoreDtoToJson(this);
}

@JsonSerializable()
class ReflectionDto {
  final bool isPass;
  final MessageScoreDto messageScore;
  final int passScore;
  final int count;
  final int maxCount;

  ReflectionDto({
    required this.isPass,
    required this.messageScore,
    required this.passScore,
    required this.count,
    required this.maxCount,
  });

  factory ReflectionDto.fromModel(Reflection result) => ReflectionDto(
    isPass: result.isPass,
    messageScore: MessageScoreDto.fromModel(result.messageScore),
    passScore: result.passScore,
    count: result.count,
    maxCount: result.maxCount
  );

  factory ReflectionDto.fromJson(Map<String, dynamic> json) => _$ReflectionDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ReflectionDtoToJson(this);
}

@JsonSerializable()
class TaskStatusDto {
  String status;
  String taskId;

  @JsonKey(includeIfNull: false)
  Map<String, dynamic>? description;

  TaskStatusDto({required this.status, required this.taskId, this.description});

  factory TaskStatusDto.fromModel(TaskStatus taskStatus) => TaskStatusDto(
    status: taskStatus.status,
    taskId: taskStatus.taskId,
    description: taskStatus.description
  );

  factory TaskStatusDto.fromJson(Map<String, dynamic> json) => _$TaskStatusDtoFromJson(json);

  Map<String, dynamic> toJson() => _$TaskStatusDtoToJson(this);
}

@JsonSerializable()
class ContentDto {
  String type; /// ContentType.TEXT ContentType.IMAGE_URL
  String message;

  ContentDto({required this.type, required this.message});

  factory ContentDto.fromModel(Content content) => ContentDto(
    type: content.type,
    message: content.message
  );

  factory ContentDto.fromJson(Map<String, dynamic> json) => _$ContentDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ContentDtoToJson(this);
}

@JsonSerializable()
class ReflectPromptDto {
  LLMConfigDto llmConfig;
  String prompt;

  ReflectPromptDto({required this.llmConfig, required this.prompt});

  factory ReflectPromptDto.fromJson(Map<String, dynamic> json) => _$ReflectPromptDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ReflectPromptDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AgentMessageChunkDto {
  String sessionId;
  String taskId;
  String role;
  String to;
  String type;
  dynamic part;
  DateTime createTime;

  AgentMessageChunkDto({
    required this.sessionId,
    required this.taskId,
    required this.role,
    required this.to,
    required this.type,
    required this.part,
    required this.createTime
  });

  factory AgentMessageChunkDto.fromJson(Map<String, dynamic> json) => _$AgentMessageChunkDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AgentMessageChunkDtoToJson(this);

  factory AgentMessageChunkDto.fromModel(AgentMessageChunk agentMessageChunk) {
    dynamic part;

    switch (agentMessageChunk.type) {
      case AgentMessageType.TASK_STATUS: part = TaskStatusDto.fromModel(agentMessageChunk.part as TaskStatus);break;
      default: part = agentMessageChunk.part;
    }

    return AgentMessageChunkDto(
      sessionId: agentMessageChunk.sessionId,
      taskId: agentMessageChunk.taskId,
      role: agentMessageChunk.role,
      to: agentMessageChunk.to,
      type: agentMessageChunk.type,
      part: part,
      createTime: agentMessageChunk.createTime
    );
  }
}

@JsonSerializable()
class AgentIdDto {
  String agentId;
  AgentIdDto({required this.agentId});

  factory AgentIdDto.fromJson(Map<String, dynamic> json) => _$AgentIdDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AgentIdDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AgentDto {
  String name;
  CapabilityDto capability;
  AgentDto({required this.name, required this.capability});

  factory AgentDto.fromJson(Map<String, dynamic> json) => _$AgentDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AgentDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AgentInfoDto extends AgentIdDto {
  String name;
  CapabilityDto capability;
  AgentInfoDto({required super.agentId, required this.name, required this.capability});

  factory AgentInfoDto.fromJson(Map<String, dynamic> json) => _$AgentInfoDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AgentInfoDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SessionAgentMessageDto {
  String sessionId;
  AgentMessageDto agentMessageDto;
  SessionAgentMessageDto({required this.sessionId, required this.agentMessageDto});

  factory SessionAgentMessageDto.fromJson(Map<String, dynamic> json) => _$SessionAgentMessageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SessionAgentMessageDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ClientOpenToolDto {
  String opentool;
  int? timeout;

  ClientOpenToolDto({required this.opentool, this.timeout});

  factory ClientOpenToolDto.fromJson(Map<String, dynamic> json) => _$ClientOpenToolDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ClientOpenToolDtoToJson(this);
}