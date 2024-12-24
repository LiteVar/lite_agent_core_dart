import '../../llm/model.dart';
import '../session_agent/model.dart';

class ReflectScore {
  int score;
  String? description;
  ReflectScore({required this.score, this.description});

  factory ReflectScore.fromJson(Map<String, dynamic> json) => ReflectScore(
    score: json["score"],
    description: json["description"]
  );
}

class MessageScore {
  List<Content> contentList;
  String messageType; //Follow AgentMessage.type
  String message;
  List<ReflectScore> reflectScoreList;
  MessageScore({required this.contentList, required this.messageType, required this.message, required this.reflectScoreList});
}

class ReflectPrompt {
  LLMConfig llmConfig;
  String prompt;

  ReflectPrompt({required this.llmConfig, required this.prompt});
}