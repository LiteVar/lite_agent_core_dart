import '../session_agent/model.dart';
import '../text_agent/model.dart';
import 'model.dart';
import 'reflector.dart';

class ReflectorManager {
  final List<Reflector> reflectorList = [];
  final int passScore;
  final int maxRetryCount;
  int currCount = 0;
  List<Content> userContentList = [];
  bool shouldReflect = false;

  ReflectorManager({this.passScore = 8, this.maxRetryCount = 10});

  void addReflector(Reflector reflector) {
    this.reflectorList.add(reflector);
    shouldReflect = reflectorList.length > 0;
  }

  void retry() {
    currCount = currCount + 1;
  }

  Future<Reflection> reflect(String messageType, String message) async {
    List<int> scoreList = [];
    for(Reflector reflector in reflectorList) {
      int currScore = await reflector.reflect(userContentList, message);
      scoreList.add(currScore);
      if(currScore < passScore) {
        MessageScore messageScore = MessageScore(contentList: userContentList, messageType: messageType, message: message, scoreList: scoreList);
        ReflectResult result = ReflectResult(isPass: false, messageScore: messageScore, passScore: passScore, count: currCount, maxCount: maxRetryCount);
        return Reflection(result: result);
      }
    }
    MessageScore messageScore = MessageScore(contentList: userContentList, messageType: messageType, message: message, scoreList: scoreList);
    ReflectResult result = ReflectResult(isPass: true, messageScore: messageScore, passScore: passScore, count: currCount, maxCount: maxRetryCount);
    return Reflection(result: result);
  }
}