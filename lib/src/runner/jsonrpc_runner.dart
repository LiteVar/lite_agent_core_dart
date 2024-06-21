import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/src/util/jsonrpc_http_util.dart';
import 'package:openrpc_dart/openrpc_dart.dart';

class JsonRPCRunner extends OpenRPCRunner {

  JsonRPCRunner(super.openRPC);

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {
    JsonRPCHttpRequestBody jsonRPCHttpRequestBody = JsonRPCHttpRequestBody(method: functionCall.name, params: functionCall.parameters, id: functionCall.id);
    JsonRPCHttpRequest jsonRPCHttpRequest = JsonRPCHttpRequest(url: openRPC.servers!.first.url, body: jsonRPCHttpRequestBody);
    JsonRPCHttpResponse jsonRPCHttpResponse = await requestJsonRPCHttpAPI(jsonRPCHttpRequest);
    return ToolReturn(id: functionCall.id, result: jsonRPCHttpResponse.toJson());
  }

  @override
  bool hasFunction(String functionName) {
    return openRPC.methods.any((Method method)=>method.name == functionName);
  }

}