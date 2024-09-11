import 'package:json_annotation/json_annotation.dart';
import 'package:opentool_dart/opentool_dart.dart';
import '../agents/model.dart';
import '../llm/model.dart';

part 'dto.g.dart';

@JsonSerializable()
class SessionDto {
  String id;

  SessionDto({required this.id});

  factory SessionDto.fromJson(Map<String, dynamic> json) =>
      _$SessionDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SessionDtoToJson(this);
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
  List<OpenSpecDto>? openSpecList;
  List<SessionDto>? sessionList;
  int timeoutSeconds;

  CapabilityDto({
    required super.llmConfig,
    required super.systemPrompt,
    this.openSpecList,
    this.sessionList,
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
  ApiKeyDto? apiKey;
  String protocol;

  OpenSpecDto({required this.openSpec, this.apiKey, required this.protocol});

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

  LLMConfigDto(
      {required this.baseUrl,
      required this.apiKey,
      required this.model,
      this.temperature = 0.0,
      this.maxTokens = 4096,
      this.topP = 1.0});

  factory LLMConfigDto.fromJson(Map<String, dynamic> json) => _$LLMConfigDtoFromJson(json);

  Map<String, dynamic> toJson() => _$LLMConfigDtoToJson(this);

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
    return AgentMessageDto(
        sessionId: agentMessage.sessionId,
        taskId: agentMessage.taskId,
        from: agentMessage.from,
        to: agentMessage.to,
        type: agentMessage.type,
        message: agentMessage.message,
        completions: agentMessage.completions == null
            ? null
            : CompletionsDto.fromModel(agentMessage.completions!),
        createTime: agentMessage.createTime);
  }
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
  String? taskId;

  SessionTaskDto({required this.id, this.taskId});

  factory SessionTaskDto.fromJson(Map<String, dynamic> json) => _$SessionTaskDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SessionTaskDtoToJson(this);
}