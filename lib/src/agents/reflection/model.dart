import '../../llm/model.dart';
import '../session_agent/model.dart';

class ReflectionResultCalling {
  int score;
  ReflectionResultCalling({required this.score});

  factory ReflectionResultCalling.fromJson(Map<String, dynamic> json) => ReflectionResultCalling(
      score: json["score"]
  );
}

class MessageScore {
  List<Content> contentList;
  String messageType; //Follow AgentMessage.type
  String message;
  List<int> scoreList;
  MessageScore({required this.contentList, required this.messageType, required this.message, required this.scoreList});
}

class ReflectPrompt {
  LLMConfig llmConfig;
  String prompt;

  ReflectPrompt({required this.llmConfig, required this.prompt});
}