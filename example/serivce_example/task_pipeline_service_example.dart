import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';
import '../listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenSpec json file, according to `/example/json/open*/*.json`, which is callable.
/// 2. Run your tool server, which is described in json file.
/// 3. Add LLM baseUrl and apiKey to `.env` file


AgentService agentService = AgentService();

Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(
      llmConfig: _buildLLMConfig(),
      systemPrompt: _buildSystemPrompt(),
      /// Add task pipeline strategy here
      taskPipelineStrategy: PipelineStrategyType.REJECT
  );

  print("[CapabilityDto] " + capabilityDto.toJson().toString());

  SessionDto sessionDto = await agentService.initSession(capabilityDto, listen);

  print("[SessionDto] " + sessionDto.toJson().toString());

  try {
    String prompt1 = "你是谁？";
    String taskId1 = uniqueId();
    print("taskId1: $taskId1, prompt1: $prompt1");
    UserTaskDto userTaskDto = UserTaskDto(taskId: taskId1, contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt1)]);
    await agentService.startSession(sessionDto.sessionId, userTaskDto);
  } on TaskRejectException catch (e) {
    print(e);
  }
  try {
    String prompt2 = "你从哪里来？";
    String taskId2 = uniqueId();
    print("taskId2: $taskId2, prompt1: $prompt2");
    UserTaskDto userTaskDto = UserTaskDto(taskId: taskId2, contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt2)]);
    await agentService.startSession(sessionDto.sessionId, userTaskDto);
  } on TaskRejectException catch (e) {
    print(e);
  }
  try {
    String prompt3 = "你要到哪里去？";
    String taskId3 = uniqueId();
    print("taskId3: $taskId3, prompt1: $prompt3");
    UserTaskDto userTaskDto = UserTaskDto(taskId: taskId3, contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt3)]);
    await agentService.startSession(sessionDto.sessionId, userTaskDto);
  } on TaskRejectException catch (e) {
    print(e);
  }

  await sleep(15);

  SessionTaskDto sessionTaskDto = SessionTaskDto(sessionId: sessionDto.sessionId);
  await agentService.stopSession(sessionTaskDto);
  print("[stopSession] ");

  await sleep(5);

  await agentService.clearSession(sessionDto.sessionId);
  print("[clearSession] ");
}

Future<void> sleep(int seconds) async {
  for (int i = seconds; i > 0; i--) {
    print(i);
    await Future.delayed(Duration(seconds: 1));
  }
}

LLMConfigDto _buildLLMConfig() {
  DotEnv env = DotEnv();
  env.load(['example/.env']);

  return LLMConfigDto(
    baseUrl: env["baseUrl"]!,
    apiKey: env["apiKey"]!,
    model: "gpt-4o-mini",
  );
}

/// Use Prompt engineering to design SystemPrompt
/// https://platform.openai.com/docs/guides/prompt-engineering
String _buildSystemPrompt() {
  return 'You are a translate robot. Translate any user content language to English. Reply sentence after translating, not chatting.';
}