import 'dart:async';
import 'dart:collection';
import 'model.dart';

class Pipeline<T> {
  final String pipelineStrategyType;
  final Queue<T> _jobQueue = Queue<T>();
  late Future<void> Function(T job) process;
  bool _isProcessing = false;

  Pipeline(this.pipelineStrategyType);

  void setProcess(Future<void> Function(T job) process) {
    this.process = process;
  }

  AddStatus addJob(T job) {
    switch (pipelineStrategyType) {
      case PipelineStrategyType.PARALLEL: return _processJobParallel(job);
      case PipelineStrategyType.SERIAL: return _processJobSerial(job);
      case PipelineStrategyType.REJECT: return _processJobReject(job);
      default: return AddStatus.ERROR_STRATEGY;
    }
  }

  AddStatus _processJobParallel(T job) {
      process(job);
      return AddStatus.SUCCESS;
  }

  AddStatus _processJobSerial(T job) {
    _jobQueue.add(job);
    if (!_isProcessing) {
      _processQueue();
    }
    return AddStatus.SUCCESS;
  }

  Future<void> _processQueue() async {
    _isProcessing = true;
    while (_jobQueue.isNotEmpty) {
      final job = _jobQueue.removeFirst();
      await process(job);
    }
    _isProcessing = false;
  }

  AddStatus _processJobReject(T job) {
    if(_isProcessing) return AddStatus.REJECT;
    _processJob(job);
    return AddStatus.SUCCESS;
  }

  Future<void> _processJob(T job) async {
    _isProcessing = true;
    await process(job);
    _isProcessing = false;
  }
}

// Future<void> main() async {
//
//   Future<void> Function(String job) process = (String job) async {
//     print("Processing job: $job");
//     await Future.delayed(Duration(seconds: 2)); // 模拟异步处理
//     print("Finished job: $job");
//   };
//
//   Pipeline<String> pipeline = Pipeline(PipelineStrategyType.SERIAL);
//   pipeline.setProcess(process);
//
//   print(pipeline.addJob("job1"));
//   print(pipeline.addJob("job2"));
//   print(pipeline.addJob("job3"));
//
//   await Future.delayed(Duration(seconds: 10));
//
// }