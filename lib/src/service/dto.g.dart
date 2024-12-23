// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionDto _$SessionDtoFromJson(Map<String, dynamic> json) => SessionDto(
      id: json['id'] as String,
    );

Map<String, dynamic> _$SessionDtoToJson(SessionDto instance) =>
    <String, dynamic>{
      'id': instance.id,
    };

SessionNameDto _$SessionNameDtoFromJson(Map<String, dynamic> json) =>
    SessionNameDto(
      id: json['id'] as String,
      name: json['name'] as String?,
    );

Map<String, dynamic> _$SessionNameDtoToJson(SessionNameDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
    };

SimpleCapabilityDto _$SimpleCapabilityDtoFromJson(Map<String, dynamic> json) =>
    SimpleCapabilityDto(
      llmConfig:
          LLMConfigDto.fromJson(json['llmConfig'] as Map<String, dynamic>),
      systemPrompt: json['systemPrompt'] as String,
    );

Map<String, dynamic> _$SimpleCapabilityDtoToJson(
        SimpleCapabilityDto instance) =>
    <String, dynamic>{
      'llmConfig': instance.llmConfig,
      'systemPrompt': instance.systemPrompt,
    };

CapabilityDto _$CapabilityDtoFromJson(Map<String, dynamic> json) =>
    CapabilityDto(
      llmConfig:
          LLMConfigDto.fromJson(json['llmConfig'] as Map<String, dynamic>),
      systemPrompt: json['systemPrompt'] as String,
      openSpecList: (json['openSpecList'] as List<dynamic>?)
          ?.map((e) => OpenSpecDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      sessionList: (json['sessionList'] as List<dynamic>?)
          ?.map((e) => SessionNameDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 3600,
    );

Map<String, dynamic> _$CapabilityDtoToJson(CapabilityDto instance) =>
    <String, dynamic>{
      'llmConfig': instance.llmConfig,
      'systemPrompt': instance.systemPrompt,
      'openSpecList': instance.openSpecList,
      'sessionList': instance.sessionList,
      'timeoutSeconds': instance.timeoutSeconds,
    };

OpenSpecDto _$OpenSpecDtoFromJson(Map<String, dynamic> json) => OpenSpecDto(
      openSpec: json['openSpec'] as String,
      apiKey: json['apiKey'] == null
          ? null
          : ApiKeyDto.fromJson(json['apiKey'] as Map<String, dynamic>),
      protocol: json['protocol'] as String,
    );

Map<String, dynamic> _$OpenSpecDtoToJson(OpenSpecDto instance) =>
    <String, dynamic>{
      'openSpec': instance.openSpec,
      'apiKey': instance.apiKey,
      'protocol': instance.protocol,
    };

LLMConfigDto _$LLMConfigDtoFromJson(Map<String, dynamic> json) => LLMConfigDto(
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String,
      model: json['model'] as String,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 4096,
      topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$LLMConfigDtoToJson(LLMConfigDto instance) =>
    <String, dynamic>{
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
      'model': instance.model,
      'temperature': instance.temperature,
      'maxTokens': instance.maxTokens,
      'topP': instance.topP,
    };

AgentMessageDto _$AgentMessageDtoFromJson(Map<String, dynamic> json) =>
    AgentMessageDto(
      sessionId: json['sessionId'] as String,
      taskId: json['taskId'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      type: json['type'] as String,
      message: json['message'],
      completions: json['completions'] == null
          ? null
          : CompletionsDto.fromJson(
              json['completions'] as Map<String, dynamic>),
      createTime: DateTime.parse(json['createTime'] as String),
    );

Map<String, dynamic> _$AgentMessageDtoToJson(AgentMessageDto instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'taskId': instance.taskId,
      'from': instance.from,
      'to': instance.to,
      'type': instance.type,
      'message': instance.message,
      'completions': instance.completions,
      'createTime': instance.createTime.toIso8601String(),
    };

CompletionsDto _$CompletionsDtoFromJson(Map<String, dynamic> json) =>
    CompletionsDto(
      tokenUsage:
          TokenUsageDto.fromJson(json['tokenUsage'] as Map<String, dynamic>),
      id: json['id'] as String,
      model: json['model'] as String,
    );

Map<String, dynamic> _$CompletionsDtoToJson(CompletionsDto instance) =>
    <String, dynamic>{
      'tokenUsage': instance.tokenUsage,
      'id': instance.id,
      'model': instance.model,
    };

TokenUsageDto _$TokenUsageDtoFromJson(Map<String, dynamic> json) =>
    TokenUsageDto(
      promptTokens: (json['promptTokens'] as num).toInt(),
      completionTokens: (json['completionTokens'] as num).toInt(),
      totalTokens: (json['totalTokens'] as num).toInt(),
    );

Map<String, dynamic> _$TokenUsageDtoToJson(TokenUsageDto instance) =>
    <String, dynamic>{
      'promptTokens': instance.promptTokens,
      'completionTokens': instance.completionTokens,
      'totalTokens': instance.totalTokens,
    };

ApiKeyDto _$ApiKeyDtoFromJson(Map<String, dynamic> json) => ApiKeyDto(
      type: $enumDecode(_$ApiKeyTypeEnumMap, json['type']),
      apiKey: json['apiKey'] as String,
    );

Map<String, dynamic> _$ApiKeyDtoToJson(ApiKeyDto instance) => <String, dynamic>{
      'type': _$ApiKeyTypeEnumMap[instance.type]!,
      'apiKey': instance.apiKey,
    };

const _$ApiKeyTypeEnumMap = {
  ApiKeyType.basic: 'basic',
  ApiKeyType.bearer: 'bearer',
};

UserTaskDto _$UserTaskDtoFromJson(Map<String, dynamic> json) => UserTaskDto(
      taskId: json['taskId'] as String?,
      contentList: (json['contentList'] as List<dynamic>)
          .map((e) => UserMessageDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UserTaskDtoToJson(UserTaskDto instance) =>
    <String, dynamic>{
      'taskId': instance.taskId,
      'contentList': instance.contentList,
    };

UserMessageDto _$UserMessageDtoFromJson(Map<String, dynamic> json) =>
    UserMessageDto(
      type: $enumDecode(_$UserMessageDtoTypeEnumMap, json['type']),
      message: json['message'] as String,
    );

Map<String, dynamic> _$UserMessageDtoToJson(UserMessageDto instance) =>
    <String, dynamic>{
      'type': _$UserMessageDtoTypeEnumMap[instance.type]!,
      'message': instance.message,
    };

const _$UserMessageDtoTypeEnumMap = {
  UserMessageDtoType.text: 'text',
  UserMessageDtoType.imageUrl: 'imageUrl',
};

SessionTaskDto _$SessionTaskDtoFromJson(Map<String, dynamic> json) =>
    SessionTaskDto(
      id: json['id'] as String,
      taskId: json['taskId'] as String?,
    );

Map<String, dynamic> _$SessionTaskDtoToJson(SessionTaskDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'taskId': instance.taskId,
    };

MessageScoreDto _$MessageScoreDtoFromJson(Map<String, dynamic> json) =>
    MessageScoreDto(
      contentList: (json['contentList'] as List<dynamic>)
          .map((e) => Content.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String,
      scoreList: (json['scoreList'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$MessageScoreDtoToJson(MessageScoreDto instance) =>
    <String, dynamic>{
      'contentList': instance.contentList,
      'message': instance.message,
      'scoreList': instance.scoreList,
    };

ReflectResultDto _$ReflectResultDtoFromJson(Map<String, dynamic> json) =>
    ReflectResultDto(
      isPass: json['isPass'] as bool,
      messageScore: MessageScoreDto.fromJson(
          json['messageScore'] as Map<String, dynamic>),
      passScore: (json['passScore'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      maxCount: (json['maxCount'] as num).toInt(),
    );

Map<String, dynamic> _$ReflectResultDtoToJson(ReflectResultDto instance) =>
    <String, dynamic>{
      'isPass': instance.isPass,
      'messageScore': instance.messageScore,
      'passScore': instance.passScore,
      'count': instance.count,
      'maxCount': instance.maxCount,
    };

ReflectionDto _$ReflectionDtoFromJson(Map<String, dynamic> json) =>
    ReflectionDto(
      result: ReflectResultDto.fromJson(json['result'] as Map<String, dynamic>),
      completions: json['completions'] == null
          ? null
          : CompletionsDto.fromJson(
              json['completions'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ReflectionDtoToJson(ReflectionDto instance) =>
    <String, dynamic>{
      'result': instance.result,
      'completions': instance.completions,
    };
