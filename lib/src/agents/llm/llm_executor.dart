import 'package:opentool_dart/opentool_dart.dart';
import '../model.dart';

abstract class LLMExecutor {
  Future<AgentMessage> request({required List<AgentMessage> agentMessageList, List<FunctionModel>? functionModelList});
}
