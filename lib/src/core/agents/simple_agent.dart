import '../llm/model.dart';
import '../util/unique_id_generator.dart';
import 'llm/openai_executor.dart';
import 'session_agent/model.dart';
import 'text_agent/model.dart';
import 'model.dart';

class SimpleAgent {
  late String sessionId;
  LLMConfig llmConfig;
  String? systemPrompt;
  ResponseFormat? responseFormat;

  SimpleAgent({required this.llmConfig, this.systemPrompt, this.responseFormat, sessionId}){
    this.sessionId = sessionId??uniqueId();
  }

  Future<AgentMessage> userToAgent({required List<Content> contentList, String? taskId}) async {
    if(taskId == null) taskId = uniqueId();

    List<AgentMessage> agentLlmMessageList = [];

    if(systemPrompt != null && systemPrompt!.isNotEmpty) {
      AgentMessage systemMessage = AgentMessage(
        sessionId: sessionId,
        taskId: taskId,
        role: TextRoleType.DEVELOPER,
        to: TextRoleType.AGENT,
        type: TextMessageType.TEXT,
        message: systemPrompt
      );
      agentLlmMessageList.add(systemMessage);
    }

    AgentMessage userMessage = AgentMessage(
      sessionId: sessionId,
      taskId: taskId,
      role: TextRoleType.AGENT,
      to: TextRoleType.ASSISTANT,
      type: TextMessageType.CONTENT_LIST,
      message: contentList
    );
    agentLlmMessageList.add(userMessage);

    return await OpenAIExecutor(llmConfig).request(agentMessageList: agentLlmMessageList, responseFormat: responseFormat);
  }
}
