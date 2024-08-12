import 'dart:async';
import 'dart:convert';
import '../http/http_util.dart';

const String JSONRPC_VERSION = "2.0.0";

class JsonRPCHttpRequest {
  late String url;
  JsonRPCHttpRequestBody body;
  JsonRPCHttpRequest({required this.url, required this.body});
}

class JsonRPCHttpRequestBody {
  String jsonrpc = JSONRPC_VERSION;
  late String method;
  Map<String, dynamic>? params;
  late String id;

  JsonRPCHttpRequestBody(
      {required this.method, required this.params, required this.id});

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "jsonrpc": jsonrpc,
      "method": method,
      if (params != null) "params": params,
      "id": id
    };
  }
}

class JsonRPCHttpResponse {
  late int statusCode;
  late String body;
  JsonRPCHttpResponse({required this.statusCode, required this.body});

  Map<String, dynamic> toJson() => {'statusCode': statusCode, 'body': body};
}

class JsonRPCHttpResponseBody {
  late String jsonrpc;
  late dynamic result;
  late JsonRPCHttpResponseBodyError? error;
  late String id;
  JsonRPCHttpResponseBody(
      {required this.jsonrpc, this.result, this.error, required this.id});

  factory JsonRPCHttpResponseBody.fromJson(Map<String, dynamic> json) {
    return JsonRPCHttpResponseBody(
        jsonrpc: json["jsonrpc"],
        result: json["result"] == null ? null : jsonDecode(json["result"]),
        error: json["error"] == null
            ? null
            : JsonRPCHttpResponseBodyError.fromJson(json["error"]),
        id: json["id"]);
  }
}

class JsonRPCHttpResponseBodyError {
  late int code;
  late String message;

  JsonRPCHttpResponseBodyError({required this.code, required this.message});

  factory JsonRPCHttpResponseBodyError.fromJson(Map<String, dynamic> json) {
    return JsonRPCHttpResponseBodyError(
        code: json["code"], message: json["messge"]);
  }
}

Future<JsonRPCHttpResponse> requestJsonRPCHttpAPI(
    JsonRPCHttpRequest jsonRPCHttpRequest,
    {String? authorization}) async {
  HttpAPIRequest httpAPIRequest = HttpAPIRequest(
    method: HttpAPIMethodType.post,
    baseUrl: jsonRPCHttpRequest.url,
    path: "",
    params: jsonRPCHttpRequest.body.toJson(),
  );

  HttpAPIResponse httpAPIResponse = await requestHttpAPI(httpAPIRequest, authorization: authorization);

  if (httpAPIResponse.statusCode == 200) {
    Map<String, dynamic> bodyJson = jsonDecode(httpAPIResponse.body);
    JsonRPCHttpResponseBody jsonRPCHttpResponseBody =
        JsonRPCHttpResponseBody.fromJson(bodyJson);
    if (jsonRPCHttpResponseBody.error != null) {
      return JsonRPCHttpResponse(
          statusCode: jsonRPCHttpResponseBody.error!.code,
          body: jsonRPCHttpResponseBody.error!.message);
    } else {
      return JsonRPCHttpResponse(
          statusCode: httpAPIResponse.statusCode,
          body: jsonEncode(jsonRPCHttpResponseBody.result!));
    }
  } else {
    return JsonRPCHttpResponse(
        statusCode: httpAPIResponse.statusCode, body: httpAPIResponse.body);
  }
}
