# lite_agent_core_dart

English · [中文](README-zh_CN.md)

LLM `AI Agent` multi sessions service.

## Features

- Support  [OpenAPI](https://github.com/djbird2046/openapi_dart)/[OpenRPC](https://github.com/djbird2046/openrpc_dart)/[OpenModbus](https://github.com/djbird2046/openmodbus_dart)/[OpenTool](https://github.com/djbird2046/opentool_dart) JSON Spec.
- Support LLM Function calling to `HTTP API`/`json-rpc 2.0 over HTTP`/`Modbus` and more custom tools.

## Usage

### Prepare

1. Some OpenSpec json file, according to `/example/json/*.json`, which is callable.
2. Run your tool server, which is described in json file.
3. Add `.env` file in the `example` folder, and add below content in the `.env` file：
     ```properties
     baseUrl = https://xxx.xxx.com         # 大模型接口的BaseURL
     apiKey = sk-xxxxxxxxxxxxxxxxxxxx      # 大模型接口的ApiKey
     ```
4. Use below method to run agent service.

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
  
  String prompt = "<USER PROMPT, e.g. call any one tool>";
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
  String prompt = "<USER PROMPT, e.g. call any one tool>";
  toolAgent.userToAgent([Content(type: ContentType.text, message: prompt)]);
}
```