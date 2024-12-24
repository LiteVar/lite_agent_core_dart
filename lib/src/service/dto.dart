import 'package:json_annotation/json_annotation.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../agents/llm/model.dart';
import '../agents/model.dart';
import '../agents/reflection/model.dart';
import '../agents/session_agent/model.dart';
import '../agents/text_agent/model.dart';
import '../llm/model.dart';
import 'exception.dart';

part 'dto.g.dart';

@JsonSerializable()
class SessionDto {
  String id;

  SessionDto({required this.id});

  factory SessionDto.fromJson(Map<String, dynamic> json) => _$SessionDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SessionDtoToJson(this);
}

@JsonSerializable()
class SessionNameDto extends SessionDto {

  @JsonKey(includeIfNull: false)
  String? name; // OpenAI: The name of the function to be called. Must be a-z, A-Z, 0-9, or contain underscores and dashes, with a maximum length of 64.

  SessionNameDto({required super.id, String? name}) {
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
  @JsonKey(includeIfNull: false)
  List<OpenSpecDto>? openSpecList;

  @JsonKey(includeIfNull: false)
  List<SessionNameDto>? sessionList;

  @JsonKey(includeIfNull: false)
  List<ReflectPromptDto>? reflectPromptList;

  int timeoutSeconds;

  CapabilityDto({
    required super.llmConfig,
    required super.systemPrompt,
    this.openSpecList,
    this.sessionList,
    this.reflectPromptList,
    this.timeoutSeconds = 3600
  });

  factory CapabilityDto.fromJson(Map<String, dynamic> json) => _$CapabilityDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CapabilityDtoToJson(this);
}

class Protocol {
  static const String OPENAPI = "openapi";
  static const String OPENMODBUS = "openmodbus";
  static const String JSONRPCHTTP = "jsonrpcHttp";
  static const String OPENTOOL = "opentool";
}

@JsonSerializable()
class OpenSpecDto {
  String openSpec;

  @JsonKey(includeIfNull: false)
  ApiKeyDto? apiKey;
  String protocol;

  @JsonKey(includeIfNull: false)
  String? openToolId; //When protocol is open tool, this is the tool id

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

@JsonSerializable()
class AgentMessageDto {
  String sessionId;
  String taskId;
  String from;
  String to;
  String type;
  dynamic message;

  @JsonKey(includeIfNull: false)
  CompletionsDto? completions; //When role is llm, this is current llm calling token usage

  DateTime createTime;

  AgentMessageDto({
    required this.sessionId,
    required this.taskId,
    required this.from,
    required this.to,
    required this.type,
    required this.message,
    this.completions,
    required this.createTime
  });

  factory AgentMessageDto.fromJson(Map<String, dynamic> json) => _$AgentMessageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AgentMessageDtoToJson(this);

  factory AgentMessageDto.fromModel(AgentMessage agentMessage) {

    dynamic message;

    switch (agentMessage.type) {
      case AgentMessageType.CONTENT_LIST: message = (agentMessage.message as List<Content>).map((content) => ContentDto.fromModel(content)).toList();break;
      case AgentMessageType.FUNCTION_CALL_LIST: message = (agentMessage.message as List<FunctionCall>).map((functionCall) => FunctionCallDto.fromModel(functionCall)).toList();break;
      case AgentMessageType.TOOL_RETURN: message = ToolReturnDto.fromModel(agentMessage.message as ToolReturn);break;
      case AgentMessageType.REFLECTION: message = ReflectionDto.fromModel(agentMessage.message as Reflection);break;
      case AgentMessageType.TASK_STATUS: message = TaskStatusDto.fromModel(agentMessage.message as TaskStatus);break;
      default: message = agentMessage.message;
    }

    // if(agentMessage.type == AgentMessageType.CONTENT_LIST) {
    //   message = (agentMessage.message as List<Content>).map((content)=>ContentDto.fromModel(content)).toList();
    // } else if(agentMessage.type == AgentMessageType.FUNCTION_CALL_LIST) {
    //   message = (agentMessage.message as List<FunctionCall>).map((functionCall)=>FunctionCallDto.fromModel(functionCall)).toList();
    // } else if(agentMessage.type == AgentMessageType.TOOL_RETURN) {
    //   message = ToolReturnDto.fromModel(agentMessage.message as ToolReturn);
    // } else if(agentMessage.type == AgentMessageType.REFLECTION) {
    //   message = ReflectionDto.fromModel(agentMessage.message as Reflection);
    // } else if(agentMessage.type == AgentMessageType.TASK_STATUS) {
    //   message = TaskStatusDto.fromModel(agentMessage.message as TaskStatus);
    // }

    return AgentMessageDto(
      sessionId: agentMessage.sessionId,
      taskId: agentMessage.taskId,
      from: agentMessage.from,
      to: agentMessage.to,
      type: agentMessage.type,
      message: message,
      completions: agentMessage.completions == null ? null : CompletionsDto.fromModel(agentMessage.completions!),
      createTime: agentMessage.createTime);
  }
}

@JsonSerializable()
class FunctionCallDto {
  late String id;
  late String name;
  late Map<String, dynamic> parameters;

  FunctionCallDto({required this.id, required this.name, required this.parameters});

  factory FunctionCallDto.fromModel(FunctionCall functionCall) => FunctionCallDto(
    id: functionCall.id,
    name: functionCall.name,
    parameters: functionCall.parameters
  );

  factory FunctionCallDto.fromJson(Map<String, dynamic> json) => _$FunctionCallDtoFromJson(json);

  Map<String, dynamic> toJson() => _$FunctionCallDtoToJson(this);
}

@JsonSerializable()
class ToolReturnDto {
  late String id;
  late Map<String, dynamic> result;

  ToolReturnDto({required this.id, required this.result});

  factory ToolReturnDto.fromModel(ToolReturn toolReturn) => ToolReturnDto(
      id: toolReturn.id,
      result: toolReturn.result
  );

  factory ToolReturnDto.fromJson(Map<String, dynamic> json) => _$ToolReturnDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ToolReturnDtoToJson(this);
}

@JsonSerializable()
class CompletionsDto {
  TokenUsageDto tokenUsage;

  /// When role is llm, this is current llm calling token usage
  String id;

  /// When role is llm, this is current /chat/completions return message id
  String model;

  CompletionsDto({required this.tokenUsage, required this.id, required this.model});

  factory CompletionsDto.fromJson(Map<String, dynamic> json) => _$CompletionsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CompletionsDtoToJson(this);

  factory CompletionsDto.fromModel(Completions completions) => CompletionsDto(
      tokenUsage: TokenUsageDto.fromModel(completions.tokenUsage),
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
  List<UserMessageDto> contentList;

  UserTaskDto({this.taskId, required this.contentList});

  factory UserTaskDto.fromJson(Map<String, dynamic> json) {
    if(json["taskId"] != null && (json["taskId"] as String).length > 36) {
      throw FormatException("taskId length should not more then 36");
    }
    return _$UserTaskDtoFromJson(json);
  }

  Map<String, dynamic> toJson() => _$UserTaskDtoToJson(this);
}

enum UserMessageDtoType { text, imageUrl }

@JsonSerializable()
class UserMessageDto {
  UserMessageDtoType type;
  String message;

  UserMessageDto({required this.type, required this.message});

  factory UserMessageDto.fromJson(Map<String, dynamic> json) => _$UserMessageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UserMessageDtoToJson(this);
}

@JsonSerializable()
class SessionTaskDto {
  String id;

  @JsonKey(includeIfNull: false)
  String? taskId;

  SessionTaskDto({required this.id, this.taskId});

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
  List<Content> contentList;
  String messageType; //Follow AgentMessage.type
  String message;
  List<ReflectScoreDto> reflectScoreList;
  MessageScoreDto({required this.contentList, required this.messageType, required this.message, required this.reflectScoreList});

  factory MessageScoreDto.fromModel(MessageScore messageScore) => MessageScoreDto(
    contentList: messageScore.contentList,
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

  @JsonKey(includeIfNull: false)
  Map<String, dynamic>? description;

  TaskStatusDto({required this.status, this.description});

  factory TaskStatusDto.fromModel(TaskStatus taskStatus) => TaskStatusDto(
    status: taskStatus.status,
    description: taskStatus.description
  );

  factory TaskStatusDto.fromJson(Map<String, dynamic> json) => _$TaskStatusDtoFromJson(json);

  Map<String, dynamic> toJson() => _$TaskStatusDtoToJson(this);
}

@JsonSerializable()
class ContentDto {
  String type;
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