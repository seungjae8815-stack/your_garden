import 'dart:math';

// 식물(정원)이 돌려주는 공감 한마디 — 템플릿 기반(비용 0). 나중에 AI로 교체 가능.
// 마음(기분)에 공감하는 한 줄 + 성장(양분) 한 줄을 합쳐서 돌려준다.

final Random _vRng = Random();

const List<String> _empathyLow = [
  '많이 힘들었죠. 그 마음, 뿌리로 꼭 안아둘게요.',
  '오늘은 마음에 비가 내렸군요. 그 비도 나에겐 소중한 물이 돼요.',
  '무거운 마음이었네요. 여기 내려놓아도 괜찮아요.',
  '애썼어요, 오늘 하루. 내가 곁에 있을게요.',
  '아픈 마음일수록 더 깊이 받아둘게요. 천천히 숨 쉬어요.',
];

const List<String> _empathyMid = [
  '그런 날도 있죠. 천천히 가도 괜찮아요.',
  '담담한 하루였군요. 그것만으로도 충분해요.',
  '오늘의 마음, 가만히 들어둘게요.',
  '흐린 날엔 흐린 대로, 그저 곁에 있을게요.',
];

const List<String> _empathyHigh = [
  '좋은 기운이 느껴져요. 햇살처럼 따뜻하네요.',
  '환한 마음이네요. 덕분에 나도 기뻐요.',
  '오늘은 마음이 맑았군요. 그 빛, 잎사귀에 담아둘게요.',
  '반짝이는 하루였네요. 오래 기억할게요.',
];

const List<String> _empathyNeutral = [
  '마음 한 줄, 잘 받았어요.',
  '들려줘서 고마워요. 여기 소중히 묻어둘게요.',
  '당신의 이야기를 가만히 품을게요.',
];

String _growth({required bool grew, required int stage}) {
  if (stage >= 5) return '이 마음까지 품고, 드디어 활짝 피었어요 🌸';
  if (grew) return '덕분에 한 뼘 자랐어요 🌱';
  return '오늘의 마음도 뿌리에 스며들어요.';
}

String _pick(List<String> pool) => pool[_vRng.nextInt(pool.length)];

/// 식물의 답장 (공감 + 성장). mood: 1..5 또는 null.
String plantReply({int? mood, required bool grew, required int stage}) {
  final List<String> empathy;
  if (mood == null) {
    empathy = _empathyNeutral;
  } else if (mood <= 2) {
    empathy = _empathyLow;
  } else if (mood == 3) {
    empathy = _empathyMid;
  } else {
    empathy = _empathyHigh;
  }
  return '${_pick(empathy)}\n${_growth(grew: grew, stage: stage)}';
}
