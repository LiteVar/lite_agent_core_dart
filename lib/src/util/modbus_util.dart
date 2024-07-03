import 'dart:async';
import 'package:modbus_client_serial/modbus_client_serial.dart';
import 'package:modbus_client_udp/modbus_client_udp.dart';
import 'package:modbus_client/modbus_client.dart';
import 'package:modbus_client_tcp/modbus_client_tcp.dart';

import '../runner/openmodbus_runner.dart';

enum ModbusServerType {
  tcp, udp,
  rtu, ascii
}

enum ModbusDataType {
  bool,
  int16,
  int32,
  uint16,
  uint32,
  string
}

enum ModbusMethodType {
  read,
  write
}

class ModbusNet {
  late String url;
  late int port;
  ModbusNet({required this.url, required this.port});
}

class ModbusSerial {
  late String port;
  late int baudRate;
  ModbusSerial({required this.port, required this.baudRate});
}

class ModbusElementParams {
  String name;
  String description;
  ModbusElementType modbusElementType;
  int address;
  int? byteCount;
  ModbusMethodType methodType;
  dynamic value;
  ModbusDataType modbusDataType;
  String uom;
  double multiplier;

  ModbusElementParams({
    required this.name,
    required this.description,
    required this.modbusElementType,
    required this.address,
    this.byteCount,
    required this.methodType,
    this.value,
    required this.modbusDataType,
    this.uom = "",
    this.multiplier = 1
  });

}

class ModbusParams {
  ModbusServerType serverType;
  int slaveId;
  ModbusElementParams modbusElementParams;

  ModbusParams({
    required this.serverType,
    required this.slaveId,
    required this.modbusElementParams
  });
}

Future<ModbusResponse> requestModbus(ModbusParams modbusParams, {ModbusNet? modbusNet, ModbusSerial? modbusSerial}) {
  ModbusClient modbusClient;
  if(modbusParams.serverType == ModbusServerType.tcp) {;
    modbusClient = ModbusClientTcp(modbusNet!.url, serverPort: modbusNet.port, unitId: modbusParams.slaveId);
  } else if(modbusParams.serverType == ModbusServerType.rtu){
    modbusClient = ModbusClientSerialRtu(portName: modbusSerial!.port, baudRate: _convertToSerialBaudRate(modbusSerial.baudRate));
  } else if(modbusParams.serverType == ModbusServerType.ascii){
    modbusClient = ModbusClientSerialAscii(portName: modbusSerial!.port, baudRate: _convertToSerialBaudRate(modbusSerial.baudRate));
  } else {
    modbusClient = ModbusClientUdp(modbusNet!.url, serverPort: modbusNet.port, unitId: modbusParams.slaveId);
  }

  Completer<ModbusResponse> completer = Completer();
  int? statusCode = null;
  String? message = null;

  Function(ModbusElement)? onUpdate;
  ModbusElement modbusElement;
  ModbusElementRequest modbusElementRequest;
  if(modbusParams.modbusElementParams.methodType == ModbusMethodType.read) {
    onUpdate = (ModbusElement modbusElement) {
      message = modbusElement.toString();
      if (statusCode != null && message != null) {
        completer.complete(ModbusResponse(statusCode: statusCode!, body: message!));
      }
    };
    modbusElement = buildModbusElement(modbusParams.modbusElementParams, onUpdate);
    modbusElementRequest = modbusElement.getReadRequest();
  } else {
    modbusElement = buildModbusElement(modbusParams.modbusElementParams, onUpdate);
    modbusElementRequest = modbusElement.getWriteRequest(modbusParams.modbusElementParams.value);
  }

  modbusClient.send(modbusElementRequest).then((ModbusResponseCode modbusResponseCode) {
    statusCode = modbusResponseCode.code;
    if(modbusParams.modbusElementParams.methodType == ModbusMethodType.read) {  // 读取，需要message有内容
      if (statusCode != null && message != null) {
        completer.complete(ModbusResponse(statusCode: statusCode!, body: message!));
      }
      if(statusCode != 0x00) {  // 如果读取失败，返回报错
        completer.complete(ModbusResponse(statusCode: statusCode!, body: modbusResponseCode.name));
      }
    } else {  // 写入，成功直接返回即可
      completer.complete(ModbusResponse(statusCode: statusCode!, body: modbusResponseCode.name));
    }
  });

  return completer.future;
}

ModbusElement buildModbusElement(ModbusElementParams modbusElementParams, Function(ModbusElement)? onUpdate) {
  switch(modbusElementParams.modbusDataType) {
    case ModbusDataType.bool: return ModbusBitElement(name: modbusElementParams.name, description: modbusElementParams.description, address: modbusElementParams.address, type: modbusElementParams.modbusElementType, onUpdate: onUpdate);
    case ModbusDataType.int16: return ModbusInt16Register(name: modbusElementParams.name, description: modbusElementParams.description, address: modbusElementParams.address, type: modbusElementParams.modbusElementType, onUpdate: onUpdate, uom: modbusElementParams.uom, multiplier: modbusElementParams.multiplier);
    case ModbusDataType.int32: return ModbusInt32Register(name: modbusElementParams.name, description: modbusElementParams.description, address: modbusElementParams.address, type: modbusElementParams.modbusElementType, onUpdate: onUpdate, uom: modbusElementParams.uom, multiplier: modbusElementParams.multiplier);
    case ModbusDataType.uint16: return ModbusUint16Register(name: modbusElementParams.name, description: modbusElementParams.description, address: modbusElementParams.address, type: modbusElementParams.modbusElementType, onUpdate: onUpdate, uom: modbusElementParams.uom, multiplier: modbusElementParams.multiplier);
    case ModbusDataType.uint32: return ModbusUint32Register(name: modbusElementParams.name, description: modbusElementParams.description, address: modbusElementParams.address, type: modbusElementParams.modbusElementType, onUpdate: onUpdate, uom: modbusElementParams.uom, multiplier: modbusElementParams.multiplier);
    case ModbusDataType.string: return ModbusBytesRegister(name: modbusElementParams.name, description: modbusElementParams.description, address: modbusElementParams.address, byteCount: modbusElementParams.byteCount!, type: modbusElementParams.modbusElementType, onUpdate: onUpdate);
  }
}

SerialBaudRate _convertToSerialBaudRate(int number) {
  return SerialBaudRate.values.firstWhere(
          (e) => e.toString() == 'SerialBaudRate.b$number',
      orElse: () => throw ArgumentError('Unrecognized enum value: $number')
  );
}