import '../agents/session_agent/session_agent.dart';
import '../agents/simple_agent.dart';

class NamedSimpleAgent {
  String name;
  SimpleAgent agent;

  NamedSimpleAgent({required this.name, required this.agent});//, required this.type, required this.capability});
}

class NamedSessionAgent {
  String name;
  SessionAgent agent;

  NamedSessionAgent({required this.name, required this.agent});//, required this.type, required this.capability});
}