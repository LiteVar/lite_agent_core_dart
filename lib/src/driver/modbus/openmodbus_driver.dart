import 'dart:async';
import 'package:openmodbus_dart/openmodbus_dart.dart';
import 'package:opentool_dart/opentool_dart.dart' as ot;
import 'package:modbus_client/modbus_client.dart';
import '../../agents/llm/model.dart';
import 'modbus_util.dart';
import '../tool_driver.dart';

class OpenModbusDriver extends ToolDriver {
  late OpenModbus openModbus;

  OpenModbusDriver(this.openModbus);

  @override
  List<ot.FunctionModel> parse() {
    List<ot.FunctionModel> functionModelList =
        openModbus.functions.map((FunctionModel function) {
      Map<String, ot.Property> properties = {};

      if (function.parameter != null) {
        String key = function.parameter!.name;
        ot.Property property = ot.Property(
            type: _convertToPropertyType(function.parameter!.type),
            description: function.parameter!.description ?? "",
            required: true);
        properties.addAll({key: property});
      }

      ot.Parameters opentoolParameters =
          ot.Parameters(type: "object", properties: properties);
      ot.FunctionModel functionModel = ot.FunctionModel(
          name: function.name,
          description: function.description ?? "",
          parameters: opentoolParameters);
      return functionModel;
    }).toList();
    return functionModelList;
  }

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {
    FunctionModel targetFunction = openModbus.functions.firstWhere(
        (FunctionModel functionModel) =>
            functionModel.name == functionCall.name);
    ModbusParams modbusParams = _convertToModbusParams(targetFunction);

    ModbusNet? modbusNet;
    ModbusSerial? modbusSerial;
    if (openModbus.server.type == ServerType.tcp ||
        openModbus.server.type == ServerType.udp) {
      NetConfig netConfig = openModbus.server.config as NetConfig;
      modbusNet = ModbusNet(url: netConfig.url, port: netConfig.port);
    } else {
      SerialConfig serialConfig = openModbus.server.config as SerialConfig;
      modbusSerial = ModbusSerial(
          port: serialConfig.port, baudRate: serialConfig.baudRate);
    }

    ModbusResponse modbusResponse = await requestModbus(modbusParams,
        modbusNet: modbusNet, modbusSerial: modbusSerial);

    return ToolReturn(id: functionCall.id, result: modbusResponse.toJson());
  }

  @override
  bool hasFunction(String functionName) {
    return openModbus.functions
        .where(
            (FunctionModel functionModel) => functionModel.name == functionName)
        .isNotEmpty;
  }

  ModbusParams _convertToModbusParams(FunctionModel function) {
    ModbusElementType modbusElementType;
    switch (function.storage) {
      case StorageType.coils:
        modbusElementType = ModbusElementType.coil;
      case StorageType.discreteInput:
        modbusElementType = ModbusElementType.discreteInput;
      case StorageType.inputRegisters:
        modbusElementType = ModbusElementType.inputRegister;
      case StorageType.holdingRegisters:
        modbusElementType = ModbusElementType.holdingRegister;
    }

    ModbusElementParams modbusElementParams = ModbusElementParams(
        name: function.name,
        description: function.description ?? "",
        modbusElementType: modbusElementType,
        address: function.address,
        methodType: function.method == MethodType.read
            ? ModbusMethodType.read
            : ModbusMethodType.write,
        modbusDataType: function.method == MethodType.read
            ? _convertToModbusDataType(function.parameter!.type)
            : _convertToModbusDataType(function.result!.type));

    ModbusParams modbusParams = ModbusParams(
        serverType: _convertToModbusServerType(openModbus.server.type),
        slaveId: function.slaveId,
        modbusElementParams: modbusElementParams);

    return modbusParams;
  }

  ModbusServerType _convertToModbusServerType(ServerType serverType) {
    Map<ServerType, ModbusServerType> map = {
      ServerType.tcp: ModbusServerType.tcp,
      ServerType.udp: ModbusServerType.udp,
      ServerType.rtu: ModbusServerType.rtu,
      ServerType.ascii: ModbusServerType.ascii
    };
    return map[serverType]!;
  }

  ModbusDataType _convertToModbusDataType(DataType dataType) {
    Map<DataType, ModbusDataType> map = {
      DataType.bool: ModbusDataType.bool,
      DataType.int16: ModbusDataType.int16,
      DataType.int32: ModbusDataType.int32,
      DataType.uint16: ModbusDataType.uint16,
      DataType.uint32: ModbusDataType.uint32,
      DataType.string: ModbusDataType.string
    };
    return map[dataType]!;
  }

  ot.PropertyType _convertToPropertyType(DataType dataType) {
    switch (dataType) {
      case DataType.bool:
        return ot.PropertyType.boolean;
      case DataType.int16:
        return ot.PropertyType.integer;
      case DataType.int32:
        return ot.PropertyType.integer;
      case DataType.uint16:
        return ot.PropertyType.integer;
      case DataType.uint32:
        return ot.PropertyType.integer;
      case DataType.string:
        return ot.PropertyType.string;
    }
  }
}


