import 'dart:async';

import 'package:lite_agent_core_dart/lite_agent_core.dart';
import 'package:modbus_client_serial/modbus_client_serial.dart';
import 'package:openmodbus_dart/openmodbus_dart.dart';
import 'package:opentool_dart/opentool_dart.dart' as ot;
import 'package:modbus_client/modbus_client.dart';
import 'package:modbus_client_tcp/modbus_client_tcp.dart';

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

    ModbusClient modbusClient;
    if(openModbus.server.type == ServerType.tcp) {
      NetConfig tcpConfig = openModbus.server.config as NetConfig;
      modbusClient = ModbusClientTcp(tcpConfig.url, serverPort: tcpConfig.port, unitId: targetFunction.slaveId);
    } else if(openModbus.server.type == ServerType.rtu){
      SerialConfig serialConfig = openModbus.server.config as SerialConfig;
      modbusClient = ModbusClientSerialRtu(portName: serialConfig.port, baudRate: _convertToSerialBaudRate(serialConfig.baudRate));
    } else if(openModbus.server.type == ServerType.ascii){
      SerialConfig serialConfig = openModbus.server.config as SerialConfig;
      modbusClient = ModbusClientSerialAscii(portName: serialConfig.port, baudRate: _convertToSerialBaudRate(serialConfig.baudRate));
    } else {
      // TODO：增加替换UDP实现
      NetConfig tcpConfig = openModbus.server.config as NetConfig;
      modbusClient = ModbusClientTcp(tcpConfig.url, serverPort: tcpConfig.port, unitId: targetFunction.slaveId);
    }

    Completer<ToolReturn> completer = Completer();
    int? statusCode = null;
    String? message = null;

    Function(ModbusElement)? onUpdate;
    ModbusElement modbusElement;
    ModbusElementRequest modbusElementRequest;
    if(targetFunction.method == MethodType.read) {
      onUpdate = (ModbusElement modbusElement) {
        message = modbusElement.toString();
        if (statusCode != null && message != null) {
          completer.complete(ToolReturn(id: functionCall.id, result: ModbusResponse(statusCode: statusCode!, body: message!).toJson()));
        }
      };
      modbusElement = _convertToModbusElement(targetFunction, onUpdate);
      modbusElementRequest = modbusElement.getReadRequest();
    } else {
      modbusElement = _convertToModbusElement(targetFunction, onUpdate);
      dynamic value = functionCall.parameters[targetFunction.parameter!.name];
      modbusElementRequest = modbusElement.getWriteRequest(value);
    }

    modbusClient.send(modbusElementRequest).then((ModbusResponseCode modbusResponseCode) {
      statusCode = modbusResponseCode.code;
      if(targetFunction.method == MethodType.read) {  // 读取，需要message有内容
        if (statusCode != null && message != null) {
          completer.complete(ToolReturn(id: functionCall.id, result: ModbusResponse(statusCode: statusCode!, body: message!).toJson()));
        }
        if(statusCode != 0x00) {  // 如果读取失败，返回报错
          completer.complete(ToolReturn(id: functionCall.id, result: ModbusResponse(statusCode: statusCode!, body: modbusResponseCode.name).toJson()));
        }
      } else {  // 写入，成功直接返回即可
        completer.complete(ToolReturn(id: functionCall.id, result: ModbusResponse(statusCode: statusCode!, body: modbusResponseCode.name).toJson()));
      }
    });

    return completer.future;
  }

  @override
  bool hasFunction(String functionName) {
    return openModbus.functions.where((FunctionModel functionModel) => functionModel.name == functionName).isNotEmpty;
  }

  ModbusElement _convertToModbusElement(FunctionModel function, Function(ModbusElement)? onUpdate) {
    ModbusElementType modbusElementType;
    switch(function.storage) {
      case StorageType.coils: modbusElementType = ModbusElementType.coil;
      case StorageType.discreteInput: modbusElementType = ModbusElementType.discreteInput;
      case StorageType.inputRegisters: modbusElementType = ModbusElementType.inputRegister;
      case StorageType.holdingRegisters: modbusElementType = ModbusElementType.holdingRegister;
    }

    DataType dataType;
    String uom = "";
    double multiplier;
    if(function.parameter != null) {
      dataType = function.parameter!.type;
      uom = function.parameter!.uom??"";
      multiplier = function.parameter!.multiplier;
    } else {
      dataType = function.result!.type;
      uom = function.result!.uom??"";
      multiplier = function.result!.multiplier;
    }

    switch(dataType) {
      case DataType.bool: return ModbusBitElement(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate);
      case DataType.int16: return ModbusInt16Register(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate, uom: uom, multiplier: multiplier);
      case DataType.int32: return ModbusInt32Register(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate, uom: uom, multiplier: multiplier);
      case DataType.uint16: return ModbusUint16Register(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate, uom: uom, multiplier: multiplier);
      case DataType.uint32: return ModbusUint32Register(name: function.name, description: function.description??"", address: function.address, type: modbusElementType, onUpdate: onUpdate, uom: uom, multiplier: multiplier);
      case DataType.string: return ModbusBytesRegister(name: function.name, description: function.description??"", address: function.address, byteCount: function.count, type: modbusElementType, onUpdate: onUpdate);
    }
  }

  SerialBaudRate _convertToSerialBaudRate(BaudRateType baudRate) {
    switch(baudRate) {
      case BaudRateType.b200: return SerialBaudRate.b200;
      case BaudRateType.b300: return SerialBaudRate.b300;
      case BaudRateType.b600: return SerialBaudRate.b600;
      case BaudRateType.b1200: return SerialBaudRate.b1200;
      case BaudRateType.b1800: return SerialBaudRate.b1800;
      case BaudRateType.b2400: return SerialBaudRate.b2400;
      case BaudRateType.b4800: return SerialBaudRate.b4800;
      case BaudRateType.b9600: return SerialBaudRate.b9600;
      case BaudRateType.b19200: return SerialBaudRate.b19200;
      case BaudRateType.b28800: return SerialBaudRate.b28800;
      case BaudRateType.b38400: return SerialBaudRate.b38400;
      case BaudRateType.b57600: return SerialBaudRate.b57600;
      case BaudRateType.b76800: return SerialBaudRate.b76800;
      case BaudRateType.b115200: return SerialBaudRate.b115200;
      case BaudRateType.b230400: return SerialBaudRate.b230400;
      case BaudRateType.b460800: return SerialBaudRate.b460800;
      case BaudRateType.b576000: return SerialBaudRate.b576000;
      case BaudRateType.b921600: return SerialBaudRate.b921600;
    }
  }

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