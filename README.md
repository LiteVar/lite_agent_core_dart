# lite_agent_core_dart

A function calling agent for dart

## Features

- Support OpenAPI/OpenRPC/OpenTool json spec
- Function calling to HTTP API and Tool return

## Usage

According to `/example/zhan_ting_agent_example.dart`

```dart
Future<void> main() async {
  ToolAgent zhanTingAgent = ToolAgent(llmRunner: _buildLLMRunner(), session: _buildSession(), toolRunnerList: await _buildToolRunnerList());
  zhanTingAgent.character = _buildCharacter();
  zhanTingAgent.userToAgent(prompt);
}
```