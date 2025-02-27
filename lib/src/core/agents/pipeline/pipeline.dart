import 'dart:async';
import 'dart:collection';
import '../../util/unique_id_generator.dart';
import 'model.dart';

/// Support job for parallel, serial, reject strategy
class Pipeline<T> {
  final String pipelineStrategyType;
  final List<T> _jobList = [];    // for parallel
  final Queue<T> _jobQueue = Queue<T>();   //for serial
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

class PipelineAsync<T> {
  final String pipelineStrategyType;
  final List<T> _jobList = [];    // for parallel
  final Queue<T> _jobQueue = Queue<T>();   //for serial
  late Future<void> Function(T job) process;
  bool _isProcessing = false;

  final Map<String, Completer<void>> _userCompleterMap = {};
  final Map<String, Completer<void>> _queueCompleterMap = {};

  PipelineAsync(this.pipelineStrategyType);

  void addJob(T job) {
    _jobList.add(job);
  }

  Future<AddStatusAsync> runAsync(Future<void> Function(T job) process, {String? asyncId, Future<void> Function()? onComplete}) async {
    this.process = process;
    if(asyncId == null) asyncId = uniqueId();
    var userCompleter = Completer<void>();
    var queueCompleter = Completer<void>();
    _userCompleterMap[asyncId] = userCompleter;
    _queueCompleterMap[asyncId] = queueCompleter;

    switch (pipelineStrategyType) {
      case PipelineStrategyType.PARALLEL: return _runParallelAsync(onComplete, asyncId);
      case PipelineStrategyType.SERIAL: return _runSerialAsync(onComplete, asyncId);
      case PipelineStrategyType.REJECT: return _runRejectAsync(onComplete, asyncId);
      default: return AddStatusAsync(addStatus: AddStatus.ERROR_STRATEGY, asyncId: asyncId);
    }
  }

  void completeAsync(String asyncId) {
    if (_userCompleterMap.containsKey(asyncId)) {
      _userCompleterMap[asyncId]!.complete();
      _userCompleterMap.remove(asyncId);
    }
    // if(pipelineStrategyType == PipelineStrategyType.PARALLEL) {
    //   Future<void> Function()? onComplete = _asyncCompleteMap[asyncId];
    //   if(onComplete != null) onComplete();
    //   Future(() async {
    //     await Future.wait(_futures);
    //     if (onComplete != null) onComplete();
    //   });
    // } else if(pipelineStrategyType == PipelineStrategyType.SERIAL) {
    //   Future<void> Function()? onComplete = _asyncCompleteMap[asyncId];
    //   if(onComplete != null) onComplete();
    //   Future(() async {
    //     await _processQueue();
    //     if (onComplete != null) onComplete();
    //   });
    // } else if(pipelineStrategyType == PipelineStrategyType.REJECT) {
    //   Future<void> Function()? onComplete = _asyncCompleteMap[asyncId];
    //   if(onComplete != null) onComplete();
    //   Future(() async {
    //     await _processQueue();
    //     _isProcessing = false;
    //     if (onComplete != null) onComplete();
    //   });
    // }
  }

  Future<AddStatusAsync> _runParallelAsync(Future<void> Function()? onComplete, String asyncId) async {
    final List<Future<void>> futures = [];
    for (var job in _jobList) {
      futures.add(process(job));
    }
    _jobList.clear();

    Future(() async {
      await Future.wait(futures);
      _queueCompleterMap[asyncId]!.complete();
    });

    Future(() async {
      await Future.wait([_userCompleterMap[asyncId]!.future, _queueCompleterMap[asyncId]!.future,]);
      if (onComplete != null) await onComplete();
    });

    return AddStatusAsync(addStatus: AddStatus.SUCCESS, asyncId: asyncId);
  }

  Future<AddStatusAsync> _runSerialAsync(Future<void> Function()? onComplete, String asyncId) async {
    for (var job in _jobList) {
      _jobQueue.add(job);
    }
    _jobList.clear();

    Future(() async {
      await _processQueue();
      _queueCompleterMap[asyncId]!.complete();
    });

    Future(() async {
      await Future.wait([_userCompleterMap[asyncId]!.future, _queueCompleterMap[asyncId]!.future,]);
      if (onComplete != null) await onComplete();
    });

    return AddStatusAsync(addStatus: AddStatus.SUCCESS, asyncId: asyncId);
  }

  Future<AddStatusAsync> _runRejectAsync(Future<void> Function()? onComplete, String asyncId) async {
    if(_isProcessing) return AddStatusAsync(addStatus: AddStatus.REJECT, asyncId: asyncId);
    _isProcessing = true;
    for (var job in _jobList) {
      _jobQueue.add(job);
    }
    _jobList.clear();

    Future(() async {
      await _processQueue();
      _queueCompleterMap[asyncId]!.complete();
    });

    Future(() async {
      await Future.wait([_userCompleterMap[asyncId]!.future, _queueCompleterMap[asyncId]!.future,]);
      _isProcessing = false;
      if (onComplete != null) await onComplete();
    });

    return  AddStatusAsync(addStatus: AddStatus.SUCCESS, asyncId: asyncId);
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

/// DEMO for pineline async
// Future<void> main() async {
//
//   Future<void> Function(String job) process = (String job) async {
//     print("Processing job: $job");
//     await Future.delayed(Duration(seconds: 2));
//     print("Finished job: $job");
//   };
//
//   PipelineAsync<String> pipeline = PipelineAsync(PipelineStrategyType.REJECT); // PARALLEL, SERIAL, REJECT
//
//   late AddStatusAsync addStatusAsync1;
//
//   Future(() async {
//     pipeline.addJob("job1");
//
//     addStatusAsync1 = await pipeline.runAsync(process, onComplete: () async {
//       print("job1  done");
//     });
//     print(addStatusAsync1.addStatus.toString() + ": " + addStatusAsync1.asyncId);
//   });
//
//   await Future.delayed(Duration(seconds: 3));
//
//   late AddStatusAsync addStatusAsync23;
//   Future(() async {
//     pipeline.addJob("job2");
//     pipeline.addJob("job3");
//
//     addStatusAsync23 = await pipeline.runAsync(process, onComplete: () async {
//       print("job2&3 done");
//     });
//     print(addStatusAsync23.addStatus.toString() + ": " + addStatusAsync23.asyncId);
//   });
//
//   await Future.delayed(Duration(seconds: 2));
//
//   pipeline.completeAsync(addStatusAsync23.asyncId);
//
//   await Future.delayed(Duration(seconds: 2));
//
//   pipeline.completeAsync(addStatusAsync1.asyncId);
//
//   await Future.delayed(Duration(seconds: 10));
// }