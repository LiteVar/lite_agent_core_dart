import 'tool_driver.dart';
import 'package:openrpc_dart/openrpc_dart.dart';
import 'package:opentool_dart/opentool_dart.dart';

abstract class OpenRPCDriver extends ToolDriver {
  OpenRPC openRPC;

  OpenRPCDriver(this.openRPC);

  @override
  List<FunctionModel> parse() {
    List<FunctionModel> functionModelList = [];
    openRPC.methods.forEach((Method method) {
      Map<String, Property> properties = {};
      method.params.forEach((ContentDescriptor contentDescriptor) {
        String name = contentDescriptor.name;
        properties[name] = _convertToProperty(contentDescriptor.name,
            contentDescriptor.schema, contentDescriptor.required);
      });
      Parameters opentoolParameters =
          Parameters(type: "object", properties: properties);
      FunctionModel functionModel = FunctionModel(
          name: method.name,
          description: method.description ?? "",
          parameters: opentoolParameters);
      functionModelList.add(functionModel);
    });
    return functionModelList;
  }

  Property _convertToProperty(String name, Schema schema, bool required) {
    String type = schema.type.toLowerCase();
    PropertyType propertyType = _PropertyTypeEnumMap[type]!;
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
}

const _PropertyTypeEnumMap = {
  'boolean': PropertyType.boolean,
  'integer': PropertyType.integer,
  'number': PropertyType.number,
  'string': PropertyType.string,
  'array': PropertyType.array,
  'object': PropertyType.object
};
