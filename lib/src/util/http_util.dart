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

  /// `GET` and `DELETE`， use `queryParams` as parameters
  if (httpAPIRequest.method == HttpAPIMethodType.get ||
      httpAPIRequest.method == HttpAPIMethodType.delete) {
    fullUrl = Uri.parse(httpAPIRequest.baseUrl + httpAPIRequest.path)
        .replace(queryParameters: httpAPIRequest.params);
    try {
      if(httpAPIRequest.method == HttpAPIMethodType.get) {
        response = await http.get(fullUrl, headers: headers);
      } else {
        response = await http.delete(fullUrl, headers: headers);
      }
    } on TimeoutException catch (e) {
      return HttpAPIResponse(statusCode: 504, body: e.toString());
    } catch (e) {
      return HttpAPIResponse(statusCode: 500, body: e.toString());
    }
  } else {
    /// `POST` and `PUT`， use `body` as parameters
    fullUrl = Uri.parse(httpAPIRequest.baseUrl + httpAPIRequest.path);
    try {
      if(httpAPIRequest.method == HttpAPIMethodType.post) {
        response = await http.post(fullUrl, headers: headers, body: json.encode(httpAPIRequest.params));
      } else {
        response = await http.put(fullUrl, headers: headers, body: json.encode(httpAPIRequest.params));
      }
    } on TimeoutException catch (e) {
      return HttpAPIResponse(statusCode: 504, body: e.toString());
    } catch (e) {
      return HttpAPIResponse(statusCode: 500, body: e.toString());
    }
  }
  String responseBody = utf8.decode(response.bodyBytes);
  return HttpAPIResponse(statusCode: response.statusCode, body: responseBody);
}
