// import 'package:opentool_dart/opentool_dart.dart';
// import '../../llm/model.dart';
import '../agents/text_agent/text_agent.dart';

// class AgentType {
//   static const SIMPLE = "simple";
//   static const TEXT = "text";
//   static const TOOL = "tool";
// }

// class Capability {
//   LLMConfig llmConfig;
//   String? systemPrompt;
//   List<ToolDriver>? openDriverList;
//   int timeoutSeconds;
//
//   Capability({required this.llmConfig, this.systemPrompt, this.openDriverList, required this.timeoutSeconds});
// }

class AgentModel {
  String name;
  // String type;
  // Capability capability;
  TextAgent agent;

  AgentModel({required this.name, required this.agent});//, required this.type, required this.capability});
}

