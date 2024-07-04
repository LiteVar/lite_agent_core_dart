import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpAPIMethodType {
  static String get = "GET";
  static String post = "POST";
  static String put = "PUT";
  static String delete = "DELETE";
}

class HttpAPIRequest {
  late String method;
  late String baseUrl;
  late String path;
  Map<String, dynamic>? params;
  HttpAPIRequest(
      {required this.method,
      required this.baseUrl,
      required this.path,
      this.params});
}

class HttpAPIResponse {
  late int statusCode;
  late String body;
  HttpAPIResponse({required this.statusCode, required this.body});

  Map<String, dynamic> toJson() => {'statusCode': statusCode, 'body': body};
}

Future<HttpAPIResponse> requestHttpAPI(HttpAPIRequest httpAPIRequest,
    {String? authorization}) async {
  Map<String, String> headers = {'Content-Type': 'application/json'};
  if (authorization != null) headers.addAll({'Authorization': authorization});

  Uri fullUrl;
  http.Response response;
  // GET和DELETE，parameters使用queryParams承载
  if (httpAPIRequest.method == HttpAPIMethodType.get ||
      httpAPIRequest.method == HttpAPIMethodType.delete) {
    fullUrl = Uri.parse(httpAPIRequest.baseUrl + httpAPIRequest.path)
        .replace(queryParameters: httpAPIRequest.params);
    try {
      response = await http.get(fullUrl, headers: headers);
    } on TimeoutException catch (e) {
      return HttpAPIResponse(statusCode: 504, body: e.toString());
    } catch (e) {
      return HttpAPIResponse(statusCode: 500, body: e.toString());
    }
  } else {
    // POST和PUT，parameters使用requestBody承载
    fullUrl = Uri.parse(httpAPIRequest.baseUrl + httpAPIRequest.path);
    http.Request request = http.Request(httpAPIRequest.method, fullUrl);
    request.headers.addAll(headers);
    request.body = json.encode(httpAPIRequest.params);
    try {
      http.StreamedResponse streamedResponse = await request.send();
      response = await http.Response.fromStream(streamedResponse);
    } on TimeoutException catch (e) {
      return HttpAPIResponse(statusCode: 504, body: e.toString());
    } catch (e) {
      return HttpAPIResponse(statusCode: 500, body: e.toString());
    }
  }

  return HttpAPIResponse(statusCode: response.statusCode, body: response.body);
}
