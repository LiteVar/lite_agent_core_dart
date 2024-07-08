import '../model.dart';
import '../util/http_util.dart';
import 'tool_runner.dart';
import 'package:openapi_dart/openapi_dart.dart';
import 'package:opentool_dart/opentool_dart.dart';

class OpenAPIRunner extends ToolRunner {
  OpenAPI openAPI;
  Map<String, String> functionToolNameMap = {};
  String? authorization;

  OpenAPIRunner(this.openAPI, {this.authorization});

  @override
  List<FunctionModel> parse() {
    List<FunctionModel> functionModelList = [];
    openAPI.paths?.paths?.forEach((String path, PathItem pathItem) {
      /// When use `GET` method, use `queryParams` as parameter in functional calling
      if (pathItem.get != null) {
        String method = HttpAPIMethodType.get;
        String functionName = convertToFunctionName("$method$path");
        List<Parameter>? openapiParameters = pathItem.get!.parameters;
        FunctionModel functionModel = _queryParamsConvertToFunctionModel(
            functionName, pathItem.get!.description ?? "", openapiParameters);
        functionModelList.add(functionModel);
      }

      /// When use `POST` method，use `requestBody` `application/json` as parameter in functional calling
      if (pathItem.post != null) {
        String method = HttpAPIMethodType.post;
        String functionName = convertToFunctionName("$method$path");
        FunctionModel functionModel = _requestBodyConvertToFunctionModel(
            functionName,
            pathItem.post!.description,
            pathItem.post!.requestBody);
        functionModelList.add(functionModel);
      }

      /// When use `PUT` method，use `requestBody` `application/json` as parameter in functional calling
      if (pathItem.put != null) {
        String method = HttpAPIMethodType.put;
        String functionName = convertToFunctionName("$method$path");
        FunctionModel functionModel = _requestBodyConvertToFunctionModel(
            functionName, pathItem.put!.description, pathItem.put!.requestBody);
        functionModelList.add(functionModel);
      }

      /// When use `DELETE` method, use `queryParams` as parameter in functional calling
      if (pathItem.delete != null) {
        String method = HttpAPIMethodType.delete;
        String functionName = convertToFunctionName("$method$path");
        List<Parameter>? openapiParameters = pathItem.delete!.parameters;
        FunctionModel functionModel = _queryParamsConvertToFunctionModel(
            functionName,
            pathItem.delete!.description ?? "",
            openapiParameters);
        functionModelList.add(functionModel);
      }
    });
    return functionModelList;
  }

  FunctionModel _requestBodyConvertToFunctionModel(
      String functionName, String? description, RequestBody? requestBody) {
    Map<String, Property> properties = {};
    List<String>? requiredList =
        requestBody?.content["application/json"]?.schema?.required;
    requestBody?.content["application/json"]?.schema?.properties
        ?.forEach((name, schema) {
      properties[name] = _convertToProperty(
          name, schema, requiredList?.contains(name) ?? false);
    });
    Parameters opentoolParameters =
        Parameters(type: "object", properties: properties);
    return FunctionModel(
        name: functionName,
        description: description ?? "",
        parameters: opentoolParameters);
  }

  Property _convertToProperty(String name, Schema schema, bool required) {
    PropertyType propertyType = _PropertyTypeEnumMap[schema.type]!;
    if (propertyType == PropertyType.array) {
      return Property(
          type: propertyType,
          description: schema.description ?? "",
          required: required,
          enum_: schema.enum_,
          items: _convertToProperty(
              name, schema.items!, schema.required?.contains(name) ?? false));
    } else if (propertyType == PropertyType.object) {
      Map<String, Property> properties = {};
      schema.properties?.forEach((String name, Schema schema0) {
        properties[name] = _convertToProperty(
            name, schema0, schema.required?.contains(name) ?? false);
      });

      return Property(
          type: propertyType,
          description: schema.description ?? "",
          required: required,
          enum_: schema.enum_,
          properties: properties);
    } else {
      return Property(
          type: propertyType,
          description: schema.description ?? "",
          required: required,
          enum_: schema.enum_);
    }
  }

  FunctionModel _queryParamsConvertToFunctionModel(
      String functionName, String? description, List<Parameter>? parameters) {
    Map<String, Property> properties = {};
    parameters?.forEach((Parameter parameter) {
      String key = parameter.name;
      Property property = Property(
          type: _PropertyTypeEnumMap[parameter.schema?.type ?? "string"]!,
          description: parameter.description ?? "",
          required: parameter.required ?? false,
          enum_: parameter.schema?.enum_);
      properties.addAll({key: property});
    });
    Parameters opentoolParameters =
        Parameters(type: "object", properties: properties);
    return FunctionModel(
        name: functionName,
        description: description ?? "",
        parameters: opentoolParameters);
  }

  @override
  String convertToFunctionName(String toolName) {
    String functionName = toolName.replaceAll("-", "--").replaceAll("/", "-");
    functionToolNameMap.addAll({functionName: toolName});
    return functionName;
  }

  @override
  String convertToToolName(String functionName) {
    return functionToolNameMap[functionName]!;
  }

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {
    String toolName = convertToToolName(functionCall.name);
    String method = toolName.split("/").first;
    String baseUrl = openAPI.servers!.first.url;
    String path = toolName.replaceFirst(method, "");
    HttpAPIRequest httpAPIRequest = HttpAPIRequest(
        method: method,
        baseUrl: baseUrl,
        path: path,
        params: functionCall.parameters);

    HttpAPIResponse httpAPIResponse =
        await requestHttpAPI(httpAPIRequest, authorization: authorization);
    return ToolReturn(id: functionCall.id, result: httpAPIResponse.toJson());
  }

  @override
  bool hasFunction(String functionName) {
    return functionToolNameMap.containsKey(functionName);
  }
}

const _PropertyTypeEnumMap = {
  'boolean': PropertyType.boolean,
  'integer': PropertyType.integer,
  'number': PropertyType.number,
  'string': PropertyType.string,
  'array': PropertyType.array,
  'object': PropertyType.object
};

String convertToAuthorization(ApiKeyType type, String apiKey) {
  switch (type) {
    case ApiKeyType.basic:
      return "Basic " + apiKey;
    case ApiKeyType.bearer:
      return "Bearer " + apiKey;
  }
}
