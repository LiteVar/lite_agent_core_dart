import 'tool_runner.dart';
import 'package:openrpc_dart/openrpc_dart.dart';
import 'package:opentool_dart/opentool_dart.dart';

abstract class OpenRPCParser extends ToolRunner{
  OpenRPC openRPC;

  OpenRPCParser(this.openRPC);

  @override
  List<FunctionModel> parse() {
    List<FunctionModel> functionModelList = [];
    openRPC.methods.map((Method method) {
      Map<String, Property> properties = {};
      method.params.map((ContentDescriptorRef contentDescriptorRef) {
        String key = contentDescriptorRef.contentDescriptor?.name??"";
        Property property = Property(type: contentDescriptorRef.contentDescriptor?.schema.schema?.schema["type"]??"", description: contentDescriptorRef.contentDescriptor?.description??"", required: contentDescriptorRef.contentDescriptor?.required??false);
        properties.addAll({key: property});
      });
      Parameters opentoolParameters= Parameters(type: "object", properties: properties);
      FunctionModel functionModel = FunctionModel(name: method.name, description: method.description??"", parameters: opentoolParameters);
      functionModelList.add(functionModel);
    });
    return functionModelList;
  }

}

abstract class OpenRPCRunner extends OpenRPCParser implements ToolRunner {

  OpenRPCRunner(super.openRPC);

}