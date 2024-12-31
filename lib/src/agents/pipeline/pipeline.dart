import 'dart:async';
import 'dart:collection';
import 'model.dart';

/// Support job for parallel, serial, reject strategy
class Pipeline<T> {
  final String pipelineStrategyType;
  final List<T> _jobList = [];
  final Queue<T> _jobQueue = Queue<T>();
  late Future<void> Function(T job) process;
  bool _isProcessing = false;

  Pipeline(this.pipelineStrategyType);

  void addJob(T job) {
    _jobList.add(job);
  }

  Future<AddStatus> run(Future<void> Function(T job) process, {Future<void> Function()? onComplete}) async {
    this.process = process;
    switch (pipelineStrategyType) {
      case PipelineStrategyType.PARALLEL: return _runParallel(onComplete);
      case PipelineStrategyType.SERIAL: return _runSerial(onComplete);
      case PipelineStrategyType.REJECT: return _runReject(onComplete);
      default: return AddStatus.ERROR_STRATEGY;
    }

  }

  Future<AddStatus> _runParallel(Future<void> Function()? onComplete) async {
    final List<Future<void>> futures = [];
    for (var job in _jobList) {
      futures.add(process(job));
    }
    _jobList.clear();
    Future(() async {
      await Future.wait(futures);
      if (onComplete != null) onComplete();
    });

    return AddStatus.SUCCESS;
  }

  Future<AddStatus> _runSerial(Future<void> Function()? onComplete) async {
    for (var job in _jobList) {
      _jobQueue.add(job);
    }
    _jobList.clear();
    Future(() async {
      await _processQueue();
      if (onComplete != null) onComplete();
    });
    return AddStatus.SUCCESS;
  }

  Future<AddStatus> _runReject(Future<void> Function()? onComplete) async {
    if(_isProcessing) return AddStatus.REJECT;
    _isProcessing = true;
    for (var job in _jobList) {
      _jobQueue.add(job);
    }
    _jobList.clear();
    Future(() async {
      await _processQueue();
      _isProcessing = false;
      if (onComplete != null) onComplete();
    });
    return AddStatus.SUCCESS;
  }

  Future<void> _processQueue() async {
    while (_jobQueue.isNotEmpty) {
      final job = _jobQueue.removeFirst();
      await process(job);
    }
  }

}

/// DEMO for pineline
// Future<void> main() async {
//
//   Future<void> Function(String job) process = (String job) async {
//     print("Processing job: $job");
//     await Future.delayed(Duration(seconds: 2));
//     print("Finished job: $job");
//   };
//
//   Pipeline<String> pipeline = Pipeline(PipelineStrategyType.REJECT); // PARALLEL, SERIAL, REJECT
//
//   Future(() async {
//     pipeline.addJob("job1");
//
//     AddStatus addStatus = await pipeline.run(process, onComplete: () async {
//       print("job1  done");
//     });
//     print(addStatus);
//   });
//
//   Future(() async {
//     pipeline.addJob("job2");
//     pipeline.addJob("job3");
//
//     AddStatus addStatus = await pipeline.run(process, onComplete: () async {
//       print("job2&3 done");
//     });
//     print(addStatus);
//   });
//
//   await Future.delayed(Duration(seconds: 10));
//
// }