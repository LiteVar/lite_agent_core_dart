// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionDto _$SessionDtoFromJson(Map<String, dynamic> json) => SessionDto(
      sessionId: json['sessionId'] as String,
    );

Map<String, dynamic> _$SessionDtoToJson(SessionDto instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
    };

SessionNameDto _$SessionNameDtoFromJson(Map<String, dynamic> json) =>
    SessionNameDto(
      sessionId: json['sessionId'] as String,
      name: json['name'] as String?,
    );

Map<String, dynamic> _$SessionNameDtoToJson(SessionNameDto instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      if (instance.name case final value?) 'name': value,
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
      clientOpenTool: json['clientOpenTool'] as String?,
      sessionList: (json['sessionList'] as List<dynamic>?)
          ?.map((e) => SessionNameDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      reflectPromptList: (json['reflectPromptList'] as List<dynamic>?)
          ?.map((e) => ReflectPromptDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 3600,
      taskPipelineStrategy: json['taskPipelineStrategy'] as String? ??
          PipelineStrategyType.PARALLEL,
      toolPipelineStrategy: json['toolPipelineStrategy'] as String?,
    );

Map<String, dynamic> _$CapabilityDtoToJson(CapabilityDto instance) =>
    <String, dynamic>{
      'llmConfig': instance.llmConfig,
      'systemPrompt': instance.systemPrompt,
      if (instance.openSpecList case final value?) 'openSpecList': value,
      if (instance.clientOpenTool case final value?) 'clientOpenTool': value,
      if (instance.sessionList case final value?) 'sessionList': value,
      if (instance.reflectPromptList case final value?)
        'reflectPromptList': value,
      'timeoutSeconds': instance.timeoutSeconds,
      'taskPipelineStrategy': instance.taskPipelineStrategy,
      'toolPipelineStrategy': instance.toolPipelineStrategy,
    };

OpenSpecDto _$OpenSpecDtoFromJson(Map<String, dynamic> json) => OpenSpecDto(
      openSpec: json['openSpec'] as String,
      apiKey: json['apiKey'] == null
          ? null
          : ApiKeyDto.fromJson(json['apiKey'] as Map<String, dynamic>),
      protocol: json['protocol'] as String,
      openToolId: json['openToolId'] as String?,
    );

Map<String, dynamic> _$OpenSpecDtoToJson(OpenSpecDto instance) =>
    <String, dynamic>{
      'openSpec': instance.openSpec,
      if (instance.apiKey case final value?) 'apiKey': value,
      'protocol': instance.protocol,
      if (instance.openToolId case final value?) 'openToolId': value,
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
      role: json['role'] as String,
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
      'role': instance.role,
      'to': instance.to,
      'type': instance.type,
      'message': instance.message,
      if (instance.completions?.toJson() case final value?)
        'completions': value,
      'createTime': instance.createTime.toIso8601String(),
    };

FunctionCallDto _$FunctionCallDtoFromJson(Map<String, dynamic> json) =>
    FunctionCallDto(
      id: json['id'] as String,
      name: json['name'] as String,
      parameters: json['parameters'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$FunctionCallDtoToJson(FunctionCallDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'parameters': instance.parameters,
    };

CompletionsDto _$CompletionsDtoFromJson(Map<String, dynamic> json) =>
    CompletionsDto(
      usage: TokenUsageDto.fromJson(json['usage'] as Map<String, dynamic>),
      id: json['id'] as String,
      model: json['model'] as String,
    );

Map<String, dynamic> _$CompletionsDtoToJson(CompletionsDto instance) =>
    <String, dynamic>{
      'usage': instance.usage,
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
          .map((e) => ContentDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      stream: json['stream'] as bool?,
    );

Map<String, dynamic> _$UserTaskDtoToJson(UserTaskDto instance) =>
    <String, dynamic>{
      if (instance.taskId case final value?) 'taskId': value,
      'contentList': instance.contentList,
      'stream': instance.stream,
    };

SessionTaskDto _$SessionTaskDtoFromJson(Map<String, dynamic> json) =>
    SessionTaskDto(
      sessionId: json['sessionId'] as String,
      taskId: json['taskId'] as String?,
    );

Map<String, dynamic> _$SessionTaskDtoToJson(SessionTaskDto instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      if (instance.taskId case final value?) 'taskId': value,
    };

ReflectScoreDto _$ReflectScoreDtoFromJson(Map<String, dynamic> json) =>
    ReflectScoreDto(
      score: (json['score'] as num).toInt(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$ReflectScoreDtoToJson(ReflectScoreDto instance) =>
    <String, dynamic>{
      'score': instance.score,
      if (instance.description case final value?) 'description': value,
    };

MessageScoreDto _$MessageScoreDtoFromJson(Map<String, dynamic> json) =>
    MessageScoreDto(
      contentList: (json['contentList'] as List<dynamic>)
          .map((e) => ContentDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      messageType: json['messageType'] as String,
      message: json['message'] as String,
      reflectScoreList: (json['reflectScoreList'] as List<dynamic>)
          .map((e) => ReflectScoreDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MessageScoreDtoToJson(MessageScoreDto instance) =>
    <String, dynamic>{
      'contentList': instance.contentList,
      'messageType': instance.messageType,
      'message': instance.message,
      'reflectScoreList': instance.reflectScoreList,
    };

ReflectionDto _$ReflectionDtoFromJson(Map<String, dynamic> json) =>
    ReflectionDto(
      isPass: json['isPass'] as bool,
      messageScore: MessageScoreDto.fromJson(
          json['messageScore'] as Map<String, dynamic>),
      passScore: (json['passScore'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      maxCount: (json['maxCount'] as num).toInt(),
    );

Map<String, dynamic> _$ReflectionDtoToJson(ReflectionDto instance) =>
    <String, dynamic>{
      'isPass': instance.isPass,
      'messageScore': instance.messageScore,
      'passScore': instance.passScore,
      'count': instance.count,
      'maxCount': instance.maxCount,
    };

TaskStatusDto _$TaskStatusDtoFromJson(Map<String, dynamic> json) =>
    TaskStatusDto(
      status: json['status'] as String,
      taskId: json['taskId'] as String,
      description: json['description'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$TaskStatusDtoToJson(TaskStatusDto instance) =>
    <String, dynamic>{
      'status': instance.status,
      'taskId': instance.taskId,
      if (instance.description case final value?) 'description': value,
    };

ContentDto _$ContentDtoFromJson(Map<String, dynamic> json) => ContentDto(
      type: json['type'] as String,
      message: json['message'] as String,
    );

Map<String, dynamic> _$ContentDtoToJson(ContentDto instance) =>
    <String, dynamic>{
      'type': instance.type,
      'message': instance.message,
    };

ReflectPromptDto _$ReflectPromptDtoFromJson(Map<String, dynamic> json) =>
    ReflectPromptDto(
      llmConfig:
          LLMConfigDto.fromJson(json['llmConfig'] as Map<String, dynamic>),
      prompt: json['prompt'] as String,
    );

Map<String, dynamic> _$ReflectPromptDtoToJson(ReflectPromptDto instance) =>
    <String, dynamic>{
      'llmConfig': instance.llmConfig,
      'prompt': instance.prompt,
    };

AgentMessageChunkDto _$AgentMessageChunkDtoFromJson(
        Map<String, dynamic> json) =>
    AgentMessageChunkDto(
      sessionId: json['sessionId'] as String,
      taskId: json['taskId'] as String,
      role: json['role'] as String,
      to: json['to'] as String,
      type: json['type'] as String,
      part: json['part'],
      createTime: DateTime.parse(json['createTime'] as String),
    );

Map<String, dynamic> _$AgentMessageChunkDtoToJson(
        AgentMessageChunkDto instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'taskId': instance.taskId,
      'role': instance.role,
      'to': instance.to,
      'type': instance.type,
      'part': instance.part,
      'createTime': instance.createTime.toIso8601String(),
    };

AgentIdDto _$AgentIdDtoFromJson(Map<String, dynamic> json) => AgentIdDto(
      agentId: json['agentId'] as String,
    );

Map<String, dynamic> _$AgentIdDtoToJson(AgentIdDto instance) =>
    <String, dynamic>{
      'agentId': instance.agentId,
    };

AgentDto _$AgentDtoFromJson(Map<String, dynamic> json) => AgentDto(
      name: json['name'] as String,
      capability:
          CapabilityDto.fromJson(json['capability'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AgentDtoToJson(AgentDto instance) => <String, dynamic>{
      'name': instance.name,
      'capability': instance.capability.toJson(),
    };

AgentInfoDto _$AgentInfoDtoFromJson(Map<String, dynamic> json) => AgentInfoDto(
      agentId: json['agentId'] as String,
      name: json['name'] as String,
      capability:
          CapabilityDto.fromJson(json['capability'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AgentInfoDtoToJson(AgentInfoDto instance) =>
    <String, dynamic>{
      'agentId': instance.agentId,
      'name': instance.name,
      'capability': instance.capability.toJson(),
    };

SessionAgentMessageDto _$SessionAgentMessageDtoFromJson(
        Map<String, dynamic> json) =>
    SessionAgentMessageDto(
      sessionId: json['sessionId'] as String,
      agentMessageDto: AgentMessageDto.fromJson(
          json['agentMessageDto'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SessionAgentMessageDtoToJson(
        SessionAgentMessageDto instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'agentMessageDto': instance.agentMessageDto.toJson(),
    };
