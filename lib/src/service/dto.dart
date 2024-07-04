import 'package:json_annotation/json_annotation.dart';
import '../model.dart';

part 'dto.g.dart';

@JsonSerializable()
class SessionDto {
  late String id;

  SessionDto({required this.id});

  factory SessionDto.fromJson(Map<String, dynamic> json) =>
      _$SessionDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SessionDtoToJson(this);
}

@JsonSerializable()
class CapabilityDto {
  late LLMConfigDto llmConfig;
  late String systemPrompt;
  late List<OpenSpecDto> openSpecList;
  int timeoutSeconds;

  CapabilityDto(
      {required this.llmConfig,
      required this.systemPrompt,
      required this.openSpecList,
      this.timeoutSeconds = 3600});

  factory CapabilityDto.fromJson(Map<String, dynamic> json) =>
      _$CapabilityDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CapabilityDtoToJson(this);
}

class Protocol {
  static String openapi = "openapi";
  static String openmodbus = "openmodbus";
  static String jsonrpcHttp = "jsonrpcHttp";
  static String opentool = "opentool";
}

@JsonSerializable()
class OpenSpecDto {
  late String openSpec;
  late ApiKeyDto? apiKey;
  late String protocol;

  OpenSpecDto({required this.openSpec, this.apiKey, required this.protocol});

  factory OpenSpecDto.fromJson(Map<String, dynamic> json) =>
      _$OpenSpecDtoFromJson(json);

  Map<String, dynamic> toJson() => _$OpenSpecDtoToJson(this);
}

@JsonSerializable()
class LLMConfigDto {
  late String baseUrl;
  late String apiKey;
  late String model;
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

  factory LLMConfigDto.fromJson(Map<String, dynamic> json) =>
      _$LLMConfigDtoFromJson(json);

  Map<String, dynamic> toJson() => _$LLMConfigDtoToJson(this);
}

@JsonSerializable()
class AgentMessageDto {
  late String sessionId;
  late String from;
  late String to;
  late AgentMessageType type;
  late dynamic message;
  CompletionsDto?
      completions; //When role is llm, this is current llm calling token usage
  late DateTime createTime;
  AgentMessageDto(
      {required this.sessionId,
      required this.from,
      required this.to,
      required this.type,
      required this.message,
      this.completions,
      required this.createTime});

  factory AgentMessageDto.fromJson(Map<String, dynamic> json) =>
      _$AgentMessageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AgentMessageDtoToJson(this);
}

@JsonSerializable()
class CompletionsDto {
  late TokenUsageDto
      tokenUsage; //When role is llm, this is current llm calling token usage
  late String
      id; //When role is llm, this is current /chat/completions return message id
  late String model;

  CompletionsDto(
      {required this.tokenUsage, required this.id, required this.model});

  factory CompletionsDto.fromJson(Map<String, dynamic> json) =>
      _$CompletionsDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CompletionsDtoToJson(this);

  factory CompletionsDto.fromModel(Completions completions) => CompletionsDto(
      tokenUsage: TokenUsageDto.fromModel(completions.tokenUsage),
      id: completions.id,
      model: completions.model);
}

@JsonSerializable()
class TokenUsageDto {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  TokenUsageDto(
      {required this.promptTokens,
      required this.completionTokens,
      required this.totalTokens});

  factory TokenUsageDto.fromJson(Map<String, dynamic> json) =>
      _$TokenUsageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$TokenUsageDtoToJson(this);

  factory TokenUsageDto.fromModel(TokenUsage tokenUsage) => TokenUsageDto(
      promptTokens: tokenUsage.promptTokens,
      completionTokens: tokenUsage.completionTokens,
      totalTokens: tokenUsage.totalTokens);
}

@JsonSerializable()
class ApiKeyDto {
  ApiKeyType type;
  String apiKey;

  ApiKeyDto({required this.type, required this.apiKey});

  factory ApiKeyDto.fromJson(Map<String, dynamic> json) =>
      _$ApiKeyDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ApiKeyDtoToJson(this);
}

enum UserMessageDtoType { text, imageUrl }

@JsonSerializable()
class UserMessageDto {
  UserMessageDtoType type;
  String message;

  UserMessageDto({required this.type, required this.message});

  factory UserMessageDto.fromJson(Map<String, dynamic> json) =>
      _$UserMessageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UserMessageDtoToJson(this);
}
