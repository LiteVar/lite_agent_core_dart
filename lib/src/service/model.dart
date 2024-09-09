import '../agents/simple_agent.dart';
import '../agents/text_agent/text_agent.dart';

class NamedSimpleAgent {
  String name;
  SimpleAgent agent;

  NamedSimpleAgent({required this.name, required this.agent});//, required this.type, required this.capability});
}

class NamedTextAgent {
  String name;
  TextAgent agent;

  NamedTextAgent({required this.name, required this.agent});//, required this.type, required this.capability});
}

