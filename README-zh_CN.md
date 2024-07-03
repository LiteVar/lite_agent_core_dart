# lite_agent_core_dart

大模型`AI Agent`的多会话服务

## 功能

- 支持 OpenAPI/OpenRPC/OpenModbus/OpenTool 的JSON文本描述
- 支持 大模型的Function calling 到`HTTP API`/`json-rpc 2.0 over HTTP`/`Modbus`以及自定义工具的执行

## 使用

### 方法1（推荐）: 使用AgentService
- 例子：`/example/agent_service_example.dart`
- 支持多Agent会话，通过`session id`区分不同会话

```dart
Future<void> main() async {
  CapabilityDto capabilityDto = CapabilityDto(
      llmConfig: _buildLLMConfig(),       // 大模型相关配置
      systemPrompt: _buildSystemPrompt(), // 系统提示词
      openSpecList: await _buildOpenSpecList()  // OpenSpec的接口描述
  );
  SessionDto sessionDto = await agentService.initChat(
      capabilityDto, 
      listen        // 订阅Agent与用户、客户端、大模型、工具等角色的交互消息 AgentMessage
  ); // 获得Session Id
  await agentService.startChat(
      sessionDto.id, // 往此Session Id发起指令
      [UserMessageDto(type: UserMessageType.text, message: prompt)] // 用户指令，支持text/imageUrl
  );
}
```

### 方法2: 使用ToolAgent

- 例子：`/example/tool_agent_example.dart`
- 更底层的调用，自由度更大，仅单一会话
- [方法1的AgentService](#方法1推荐-使用agentservice)是对此本地调用的较为友好的封装

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