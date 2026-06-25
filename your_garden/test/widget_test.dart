import 'package:flutter_test/flutter_test.dart';
import 'package:your_garden/services/crisis.dart';

void main() {
  group('detectCrisis', () {
    test('자해/위기 키워드를 잡는다', () {
      expect(detectCrisis('더는 살기 싫어'), isTrue);
      expect(detectCrisis('자살하고 싶다'), isTrue);
      expect(detectCrisis('죽 고 싶 어'), isTrue); // 띄어쓰기 회피 방지
    });

    test('평범한 하소연은 통과시킨다', () {
      expect(detectCrisis('오늘 회사에서 너무 힘들었다'), isFalse);
      expect(detectCrisis('짜증나고 지친 하루였어'), isFalse);
      expect(detectCrisis(''), isFalse);
    });
  });
}
