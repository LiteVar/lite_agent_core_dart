import 'package:dotenv/dotenv.dart';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/lite_agent_service.dart';
import '../listener.dart';

/// [IMPORTANT] Prepare:
/// 1. Some OpenSpec json file, according to `/example/json/open*/*.json`, which is callable.
/// 2. Run your tool server, which is described in json file.
/// 3. Add LLM baseUrl and apiKey to `.env` file
String prompt = "你好.";

AgentService agentService = AgentService();

Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(
    llmConfig: _buildLLMConfig(),
    systemPrompt: _buildSystemPrompt(),
    /// Add reflection prompt list here
    reflectPromptList: _buildTextReflectPromptList()
  );

  print("[CapabilityDto] " + capabilityDto.toJson().toString());

  SessionDto sessionDto = await agentService.initSession(capabilityDto, listen);

  print("[SessionDto] " + sessionDto.toJson().toString());

  String taskId = uniqueId();
  UserTaskDto userTaskDto = UserTaskDto(taskId: taskId, contentList: [ContentDto(type: ContentType.TEXT, message: prompt)]);
  await agentService.startSession(sessionDto.sessionId, userTaskDto);

  print("[prompt] " + prompt);

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

List<ReflectPromptDto> _buildTextReflectPromptList() {
  LLMConfigDto llmConfig = _buildLLMConfig();
  return [
    ReflectPromptDto(llmConfig: llmConfig, prompt: "You are a language reflector, you can reflect `LLM Response` language is English or not. If English, score is 10, else score is 0."),
  ];
}