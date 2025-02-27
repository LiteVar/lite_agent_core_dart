import 'package:snowflaker/snowflaker.dart';
// import 'package:uuid/uuid.dart';

final snowflaker = Snowflaker(workerId: 1, datacenterId: 1);

String uniqueId() {
  return snowflaker.nextId().toString();
  // return Uuid().v4();
}