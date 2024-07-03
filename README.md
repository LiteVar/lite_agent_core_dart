# lite_agent_core_dart

LLM `AI Agent` multi sessions service.

## Features

- Support OpenAPI/OpenRPC/OpenModbus/OpenTool JSON Spec.
- Support LLM Function calling to `HTTP API`/`json-rpc 2.0 over HTTP`/`Modbus` and more custom tools.

## Usage

### Method 1(Recommend): AgentService
- According to `/example/agent_service_example.dart`
- Support multi agent session via session id.

```dart
Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(
      llmConfig: _buildLLMConfig(),       // LLM Config
      systemPrompt: _buildSystemPrompt(), // System Prompt
      openSpecList: await _buildOpenSpecList()  // OpenSpec Description String List
  );
  SessionDto sessionDto = await agentService.initChat(
      capabilityDto,
      listen        // Subscribe AgentMessage, Agent chat with User/Client/LLM/Tools Role
  ); // Get Session Id
  await agentService.startChat(
      sessionDto.id, // Start chat with the Session Id
      [UserMessageDto(type: UserMessageType.text, message: prompt)] // User Content List, support type text/imageUrl
  );
}
```

### Method 2: ToolAgent

- According to `/example/tool_agent_example.dart`
- Pure native calling. Support single session.
- [Method 1 AgentService](#method-1recommend-agentservice) is friendly encapsulation for this.

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