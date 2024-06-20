import 'dart:async';
import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:lite_agent_core_dart/src/util/modbus_util.dart';
import 'package:openmodbus_dart/openmodbus_dart.dart';
import 'package:opentool_dart/opentool_dart.dart' as ot;
import 'package:modbus_client/modbus_client.dart';

class OpenModbusRunner extends ToolRunner {
  late OpenModbus openModbus;

  OpenModbusRunner(this.openModbus);

  @override
  List<ot.FunctionModel> parse() {
    List<ot.FunctionModel> functionModelList = openModbus.functions.map((FunctionModel function) {
      Map<String, ot.Property> properties = {};

      if(function.parameter != null) {
        String key = function.parameter!.name;
        ot.Property property = ot.Property(type: _convertToPropertyType(function.parameter!.type),
            description: function.parameter!.description??"",
            required: true);
        properties.addAll({key: property});
      }

      ot.Parameters opentoolParameters = ot.Parameters(type: "object", properties: properties);
      ot.FunctionModel functionModel = ot.FunctionModel(name: function.name, description: function.description??"", parameters: opentoolParameters);
      return functionModel;
    }).toList();
    return functionModelList;
  }

  @override
  Future<ToolReturn> call(FunctionCall functionCall) async {

    FunctionModel targetFunction = openModbus.functions.firstWhere((FunctionModel functionModel) => functionModel.name == functionCall.name);
    ModbusParams modbusParams = _convertToModbusParams(targetFunction);

    ModbusNet? modbusNet;
    ModbusSerial? modbusSerial;
    if(openModbus.server.type == ServerType.tcp || openModbus.server.type == ServerType.udp) {
      NetConfig netConfig = openModbus.server.config as NetConfig;
      modbusNet = ModbusNet(url: netConfig.url, port: netConfig.port);
    } else {
      SerialConfig serialConfig = openModbus.server.config as SerialConfig;
      modbusSerial = ModbusSerial(port: serialConfig.port, baudRate: serialConfig.baudRate);
    }

    ModbusResponse modbusResponse = await requestModbus(modbusParams, modbusNet: modbusNet, modbusSerial: modbusSerial);

    return ToolReturn(id: functionCall.id, result: modbusResponse.toJson());
  }

  @override
  bool hasFunction(String functionName) {
    return openModbus.functions.where((FunctionModel functionModel) => functionModel.name == functionName).isNotEmpty;
  }

  ModbusParams _convertToModbusParams(FunctionModel function) {

    ModbusElementType modbusElementType;
    switch(function.storage) {
      case StorageType.coils: modbusElementType = ModbusElementType.coil;
      case StorageType.discreteInput: modbusElementType = ModbusElementType.discreteInput;
      case StorageType.inputRegisters: modbusElementType = ModbusElementType.inputRegister;
      case StorageType.holdingRegisters: modbusElementType = ModbusElementType.holdingRegister;
    }

    ModbusElementParams modbusElementParams = ModbusElementParams(
        name: function.name,
        description: function.description??"",
        modbusElementType: modbusElementType,
        address: function.address,
        methodType: function.method == MethodType.read? ModbusMethodType.read : ModbusMethodType.write,
        modbusDataType: function.method == MethodType.read? _convertToModbusDataType(function.parameter!.type) : _convertToModbusDataType(function.result!.type)
    );

    ModbusParams modbusParams = ModbusParams(
        serverType: _convertToModbusServerType(openModbus.server.type),
        slaveId: function.slaveId,
        modbusElementParams: modbusElementParams
    );

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

  // ModbusElement _convertToModbusElement(FunctionModel function, Function(ModbusElement)? onUpdate) {
  //   ModbusElementType modbusElementType;
  //   switch(function.storage) {
  //     case StorageType.coils: modbusElementType = ModbusElementType.coil;
  //     case StorageType.discreteInput: modbusElementType = ModbusElementType.discreteInput;
  //     case StorageType.inputRegisters: modbusElementType = ModbusElementType.inputRegister;
  //     case StorageType.holdingRegisters: modbusElementType = ModbusElementType.holdingRegister;
  //   }
  //
  //   DataType dataType;
  //   String uom = "";
  //   double multiplier;
  //   if(function.parameter != null) {
  //     dataType = function.parameter!.type;
  //     uom = function.parameter!.uom??"";
  //     multiplier = function.parameter!.multiplier;
  //   } else {
  //     dataType = function.result!.type;
  //     uom = function.result!.uom??"";
  //     multiplier = function.result!.multiplier;
  //   }
  //
  //   switch(dataType) {
  //     case DataType.bool: return ModbusBitElement(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate);
  //     case DataType.int16: return ModbusInt16Register(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate, uom: uom, multiplier: multiplier);
  //     case DataType.int32: return ModbusInt32Register(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate, uom: uom, multiplier: multiplier);
  //     case DataType.uint16: return ModbusUint16Register(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate, uom: uom, multiplier: multiplier);
  //     case DataType.uint32: return ModbusUint32Register(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate, uom: uom, multiplier: multiplier);
  //     case DataType.string: return ModbusBytesRegister(name: function.name, description: function.description??"", address: function.address, byteCount: function.count, type: modbusElementType, onUpdate: onUpdate);
  //   }
  // }
  //
  // SerialBaudRate _convertToSerialBaudRate(BaudRateType baudRate) {
  //   switch(baudRate) {
  //     case BaudRateType.b200: return SerialBaudRate.b200;
  //     case BaudRateType.b300: return SerialBaudRate.b300;
  //     case BaudRateType.b600: return SerialBaudRate.b600;
  //     case BaudRateType.b1200: return SerialBaudRate.b1200;
  //     case BaudRateType.b1800: return SerialBaudRate.b1800;
  //     case BaudRateType.b2400: return SerialBaudRate.b2400;
  //     case BaudRateType.b4800: return SerialBaudRate.b4800;
  //     case BaudRateType.b9600: return SerialBaudRate.b9600;
  //     case BaudRateType.b19200: return SerialBaudRate.b19200;
  //     case BaudRateType.b28800: return SerialBaudRate.b28800;
  //     case BaudRateType.b38400: return SerialBaudRate.b38400;
  //     case BaudRateType.b57600: return SerialBaudRate.b57600;
  //     case BaudRateType.b76800: return SerialBaudRate.b76800;
  //     case BaudRateType.b115200: return SerialBaudRate.b115200;
  //     case BaudRateType.b230400: return SerialBaudRate.b230400;
  //     case BaudRateType.b460800: return SerialBaudRate.b460800;
  //     case BaudRateType.b576000: return SerialBaudRate.b576000;
  //     case BaudRateType.b921600: return SerialBaudRate.b921600;
  //   }
  // }

  ot.PropertyType _convertToPropertyType(DataType dataType) {
    switch(dataType) {
      case DataType.bool: return ot.PropertyType.boolean;
      case DataType.int16: return ot.PropertyType.integer;
      case DataType.int32: return ot.PropertyType.integer;
      case DataType.uint16: return ot.PropertyType.integer;
      case DataType.uint32: return ot.PropertyType.integer;
      case DataType.string: return ot.PropertyType.string;
    }
  }

}

class ModbusResponse {
  late int statusCode;
  late String body;
  ModbusResponse({required this.statusCode, required this.body});

  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'body': body
  };
}