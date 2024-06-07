import 'package:lite_agent_core/src/model.dart';
import 'package:lite_agent_core/src/util/http_util.dart';
import 'tool_interface.dart';
import 'package:openapi_dart/openapi_dart.dart';
import 'package:opentool_dart/opentool_dart.dart';

class OpenAPIRunner extends ToolRunner {
  OpenAPI openAPI;
  Map<String, String> functionToolNameMap = {};

  OpenAPIRunner(this.openAPI);

  @override
  List<FunctionModel> parse() {
    List<FunctionModel> functionModelList = [];
    openAPI.paths?.paths?.forEach((String path, PathItem pathItem) {

      // 使用GET方法时，取queryParams作为functional calling的parameter
      if(pathItem.get != null) {
        String method = HttpAPIMethodType.get;
        String functionName = convertToFunctionName("$method$path");
        List<Parameter>? openapiParameters = pathItem.get!.parameters;
        Map<String, Property> properties = {};
        openapiParameters?.forEach((Parameter parameter) {
          String key = parameter.name;
          Property property = Property(type: parameter.schema?.type??"", description: parameter.schema?.description??"", required: parameter.required??false);
          properties.addAll({key: property});
        });
        Parameters opentoolParameters= Parameters(type: "object", properties: properties);
        FunctionModel functionModel = FunctionModel(name: functionName, description: pathItem.description??"", parameters: opentoolParameters);
        functionModelList.add(functionModel);
      }

      // 使用POST方法时，取requestBody的application/json作为functional calling的parameter
      if(pathItem.post != null) {
        String method = HttpAPIMethodType.post;
        String functionName = convertToFunctionName("$method$path");
        FunctionModel functionModel = _requestBodyConvertToFunctionModel(functionName, pathItem.post!.description, pathItem.post!.requestBody);
        functionModelList.add(functionModel);
      }

      // 使用PUT方法时，取requestBody的application/json作为functional calling的parameter
      if(pathItem.put != null){
        String method = HttpAPIMethodType.put;
        String functionName = convertToFunctionName("$method$path");
        FunctionModel functionModel = _requestBodyConvertToFunctionModel(functionName, pathItem.put!.description, pathItem.put!.requestBody);
        functionModelList.add(functionModel);
      }

      // 使用DELETE方法时，取queryParams作为functional calling的parameter
      if(pathItem.delete != null) {
        String method = HttpAPIMethodType.delete;
        String functionName = convertToFunctionName("$method$path");
        List<Parameter>? openapiParameters  = pathItem.delete!.parameters;
        FunctionModel functionModel = _queryParamsConvertToFunctionModel(functionName, pathItem.description??"", openapiParameters);
        functionModelList.add(functionModel);
      }
    });
    return functionModelList;
  }

  FunctionModel _requestBodyConvertToFunctionModel(String functionName, String? description, RequestBody? requestBody) {
    Map<String, Property> properties = {};
    List<String>? requiredList = requestBody?.content["application/json"]?.schema?.required;
    requestBody?.content["application/json"]?.schema?.properties?.forEach((name, property) {
      String key = name;
      Property value = Property(type: property.type, description: property.description??"", required: requiredList?.contains(name)??false, enum_: property.enum_);
      properties.addAll({key: value});
    });
    Parameters opentoolParameters= Parameters(type: "object", properties: properties);
    return FunctionModel(name: functionName, description: description??"", parameters: opentoolParameters);
  }

  FunctionModel _queryParamsConvertToFunctionModel(String functionName, String? description, List<Parameter>? parameters) {
    Map<String, Property> properties = {};
    parameters?.forEach((Parameter parameter) {
      String key = parameter.name;
      Property property = Property(type: parameter.schema?.type??"", description: parameter.schema?.description??"", required: parameter.required??false, enum_: parameter.schema?.enum_);
      properties.addAll({key: property});
    });
    Parameters opentoolParameters= Parameters(type: "object", properties: properties);
    return FunctionModel(name: functionName, description: description??"", parameters: opentoolParameters);
  }

  @override
  String convertToFunctionName(String toolName) {
    String functionName = toolName.replaceAll("-","--").replaceAll("/", "-");
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
    HttpAPIRequest httpAPIRequest = HttpAPIRequest(method: method, baseUrl: baseUrl, path: path, params: functionCall.parameters);

    HttpAPIResponse httpAPIResponse = await requestHttpAPI(httpAPIRequest);
    return ToolReturn(id: functionCall.id, result: httpAPIResponse.toJson());
  }

  @override
  bool hasFunction(String functionName) {
    return functionToolNameMap.containsKey(functionName);
  }

}
