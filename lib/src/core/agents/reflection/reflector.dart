import '../../llm/model.dart';
import '../session_agent/model.dart';
import 'model.dart';
import 'reflector_agent.dart';

abstract class Reflector {
  //Evaluate message match request or not, return score 0-10 in int type;
  Future<ReflectScore> reflect(List<Content> contentList, String message);
}

class AgentReflector implements Reflector {
  ReflectorAgent agent;
  void Function(Completions? completions) subscribeCompletions;

  AgentReflector({required this.agent, required this.subscribeCompletions});

  @override
  Future<ReflectScore> reflect(List<Content> contentList, String message) async {
    return agent.evaluate(contentList, message, this.subscribeCompletions);
  }
}