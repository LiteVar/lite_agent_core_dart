import '../agents/session_agent/session_agent.dart';
import '../agents/simple_agent.dart';

class NamedSimpleAgent {
  String name;
  String? description;
  SimpleAgent agent;

  NamedSimpleAgent({required this.name, this.description, required this.agent});
}

class NamedSessionAgent {
  String name;
  String? description;
  SessionAgent agent;

  NamedSessionAgent({required this.name, this.description, required this.agent});
}