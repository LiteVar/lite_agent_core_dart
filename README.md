# lite_agent_core_dart

A function calling agent for dart

## Features

- Support OpenAPI/OpenRPC/OpenTool json spec
- Function calling to HTTP API and Tool return

## Usage

### Method1(Recommend): Service Call
- According to `/example/agent_service_example.dart`
- Support multi agent via session id

```dart
Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(
      llmConfig: _buildLLMConfig(), 
      systemPrompt: _buildSystemPrompt(), 
      openSpecList: await _buildOpenSpecList());
  SessionDto sessionDto = await agentService.initChat(capabilityDto, listen);
  await agentService.startChat(sessionDto.id, [UserMessageDto(type: UserMessageType.text, message: prompt)]);
}
```

### Method2: Pure Native Call

- According to `/example/tool_agent_example.dart`

```dart
Future<void> main() async {
  ToolAgent toolAgent = ToolAgent(
      llmRunner: _buildLLMRunner(),
      session: _buildSession(),
      toolRunnerList: await _buildToolRunnerList(),
      systemPrompt: _buildSystemPrompt()
  );
  toolAgent.userToAgent([Content(type: ContentType.text, message: prompt)]);
}
```