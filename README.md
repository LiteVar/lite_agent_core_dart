# LiteAgent core for dart

English · [中文](README-zh_CN.md)

LLM `AI Agent` multi sessions service.

## Features

- Support pure text agent without JSON Spec.
- Support  [OpenAPI](https://github.com/djbird2046/openapi_dart)/[OpenRPC](https://github.com/djbird2046/openrpc_dart)/[OpenModbus](https://github.com/LiteVar/openmodbus_dart)/[OpenTool](https://github.com/LiteVar/opentool_dart) JSON Spec.
- Support LLM Function calling to `HTTP API`/`json-rpc 2.0 over HTTP`/`Modbus` and more custom tools.

## Usage

### Prepare

1. Some OpenSpec json file, according to `/example/json/open*/*.json`, which is callable.
2. Run your tool server, which is described in json file.
3. Add `.env` file in the `example` folder, and add below content in the `.env` file：
     ```properties
     baseUrl = https://xxx.xxx.com         # LLM API BaseURL
     apiKey = sk-xxxxxxxxxxxxxxxxxxxx      # LLM API ApiKey
     ```
4. Use below method to run agent service.

### Method 1(Recommend): AgentService
- According to `/example/service_example`
- Support multi agent session via session id.
- Support multi task in the same agent, identify different tasks by `taskId`. After finishing task, task message could be added to session as new task context.

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
  
  String prompt = "<USER PROMPT, e.g. call any one tool>";
  UserTaskDto userTaskDto = UserTaskDto(taskId: "<Identify different tasks, NOT more than 36 chars>", contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt)]);  // User Content List, support type text/imageUrl
  await agentService.startChat(sessionDto.id, userTaskDto);
}
```

- MultiAgent support

```dart
Future<void> main() async {
  SessionDto sessionDto1 = await _buildTextAgent();
  SessionDto sessionDto2 = await _buildToolAgent();

  CapabilityDto capabilityDto = CapabilityDto(llmConfig: llmConfig, systemPrompt: systemPrompt,
      sessionList: [sessionDto1, sessionDto2]
  );

  SessionDto sessionDto = await agentService.initChat(capabilityDto, listen);

  UserTaskDto userTaskDto = UserTaskDto(contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt)]);
  await agentService.startChat(sessionDto.id, userTaskDto);
}
```

- Reflection support

```dart
Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(
      llmConfig: _buildLLMConfig(),
      systemPrompt: _buildSystemPrompt(),
      openSpecList: await _buildOpenSpecList(),
      /// Add reflection prompt list here
      toolReflectionList: await _buildToolReflectionList()
  );
  SessionDto sessionDto = await agentService.initChat(capabilityDto, listen);
  String prompt = "<USER PROMPT, e.g. call any one tool>";
  UserTaskDto userTaskDto = UserTaskDto(taskId: "<Identify different tasks, NOT more than 36 chars>", contentList: [UserMessageDto(type: UserMessageDtoType.text, message: prompt)]);
  await agentService.startChat(sessionDto.id, userTaskDto);
}
```

### Method 2: ToolAgent

- According to `/example/agent_example`
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
  String prompt = "<USER PROMPT, e.g. call any one tool>";
  toolAgent.userToAgent(taskId: "<Identify different tasks, NOT more than 36 chars>", [Content(type: ContentType.text, message: prompt)]);
}
```