class PipelineStrategyType {
  static const String PARALLEL = "parallel";
  static const String SERIAL = "serial";
  static const String REJECT = "reject";
}

class PipelineStrategy {
  String type;
  String? description;

  PipelineStrategy({this.type = PipelineStrategyType.PARALLEL, this.description});
}

// class JobStatusType {
//   static const String PENDING = "pending";
//   static const String PROCESSING = "processing";
//   static const String COMPLETED = "completed";
//   static const String TIMEOUT = "timeout";
//   static const String FAILED = "failed";
// }

// class AddStatusType {
//   static const String SUCCESS = "success";
//   static const String REJECT = "reject";
//   static const String ERROR_STRATEGY = "errorStrategy";
// }

enum AddStatus {
  SUCCESS,
  REJECT,
  ERROR_STRATEGY
}