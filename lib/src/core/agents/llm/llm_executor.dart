import 'package:opentool_dart/opentool_dart.dart';
import '../../llm/model.dart';
import '../model.dart';

abstract class LLMExecutor {
  Future<AgentMessage> request({required List<AgentMessage> agentMessageList, List<FunctionModel>? functionModelList, ResponseFormat? responseFormat});
  Future<Stream<AgentMessage>> requestByStream({required List<AgentMessage> agentMessageList, List<FunctionModel>? functionModelList, ResponseFormat? responseFormat});
}
