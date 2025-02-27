import 'dart:async';

class Timeout {
  final int timeoutSeconds;
  Timer? _timer;
  Timeout(this.timeoutSeconds);

  void start(void Function() func) {
    _timer = Timer(Duration(seconds: timeoutSeconds), () {
      func();
    });
  }

  void clear() {
    _timer?.cancel();
  }
}