import 'dart:math';

// 식물(정원)이 돌려주는 공감 한마디 — 템플릿 기반(비용 0). 나중에 AI로 교체 가능.
// 마음(기분)에 공감하는 한 줄 + 성장(양분) 한 줄을 합쳐서 돌려준다.
// 감정 태그가 있으면 그 결에 맞춘 공감을 섞어 반복을 줄인다.

final Random _vRng = Random();

String _pick(List<String> pool) => pool[_vRng.nextInt(pool.length)];

// ── 마음 날씨(mood) 기반 공감 ─────────────────────────────
const List<String> _empathyLow = [
  '많이 힘들었죠. 그 마음, 뿌리로 꼭 안아둘게요.',
  '오늘은 마음에 비가 내렸군요. 그 비도 나에겐 소중한 물이 돼요.',
  '무거운 마음이었네요. 여기 내려놓아도 괜찮아요.',
  '애썼어요, 오늘 하루. 내가 곁에 있을게요.',
  '아픈 마음일수록 더 깊이 받아둘게요. 천천히 숨 쉬어요.',
  '버텨준 것만으로 충분해요. 그 마음, 흙이 품을게요.',
  '오늘의 무게, 혼자 다 지지 않아도 돼요. 조금 나눠 묻어요.',
  '그렇게 힘든 줄도 모르고 하루가 지났겠죠. 이제 여기 기대요.',
];

const List<String> _empathyMid = [
  '그런 날도 있죠. 천천히 가도 괜찮아요.',
  '담담한 하루였군요. 그것만으로도 충분해요.',
  '오늘의 마음, 가만히 들어둘게요.',
  '흐린 날엔 흐린 대로, 그저 곁에 있을게요.',
  '특별할 것 없는 하루도 소중히 묻어둘게요.',
  '그저 그런 날을 지나온 것도 잘한 일이에요.',
];

const List<String> _empathyHigh = [
  '좋은 기운이 느껴져요. 햇살처럼 따뜻하네요.',
  '환한 마음이네요. 덕분에 나도 기뻐요.',
  '오늘은 마음이 맑았군요. 그 빛, 잎사귀에 담아둘게요.',
  '반짝이는 하루였네요. 오래 기억할게요.',
  '맑은 마음을 나눠줘서 고마워요. 잎이 더 푸르러져요.',
  '이런 날의 온기는 뿌리 깊이 저장해 둘게요.',
];

const List<String> _empathyNeutral = [
  '마음 한 줄, 잘 받았어요.',
  '들려줘서 고마워요. 여기 소중히 묻어둘게요.',
  '당신의 이야기를 가만히 품을게요.',
  '오늘도 찾아와 줘서 고마워요.',
  '무슨 마음이든, 여기선 괜찮아요.',
];

List<String> _moodEmpathy(int? mood) {
  if (mood == null) return _empathyNeutral;
  if (mood <= 2) return _empathyLow;
  if (mood == 3) return _empathyMid;
  return _empathyHigh;
}

// ── 감정 태그 기반 공감 (선택했을 때 섞어 씀) ──────────────
const Map<String, List<String>> _emotionEmpathy = {
  'anger': [
    '화가 많이 났군요. 그 뜨거움도 여기 흙에 식혀둘게요.',
    '분한 마음, 삼키지 말고 여기 묻어요. 뿌리가 받아낼게요.',
  ],
  'anxiety': [
    '마음이 자꾸 서성였군요. 그 불안도 가만히 붙잡아 둘게요.',
    '조마조마한 하루였네요. 여기서는 잠시 내려놔도 괜찮아요.',
  ],
  'sadness': [
    '슬픔이 깊었군요. 눈물도 나에겐 좋은 물이 돼요.',
    '가라앉은 마음, 천천히 안아둘게요.',
  ],
  'overwhelm': [
    '벅찬 마음이었네요. 그 큰 마음, 조심히 받아둘게요.',
    '가슴이 가득 찼군요. 넘치지 않게 함께 담을게요.',
  ],
  'numb': [
    '아무 느낌도 없는 날이었군요. 그 고요함도 그대로 괜찮아요.',
    '텅 빈 것 같은 하루, 억지로 채우지 않아도 돼요.',
  ],
  'hope': [
    '작은 희망이 피어났네요. 그 씨앗, 함께 키워가요.',
    '옅더라도 빛이 보였군요. 그 마음, 볕 잘 드는 곳에 둘게요.',
  ],
};

/// 선택한 감정 태그 중 하나에 맞춘 공감 한 줄 (없으면 null).
String? _tagEmpathy(List<String> emotionTags) {
  final matches = emotionTags
      .where((k) => _emotionEmpathy.containsKey(k))
      .toList();
  if (matches.isEmpty) return null;
  return _pick(_emotionEmpathy[matches[_vRng.nextInt(matches.length)]]!);
}

// ── 성장(양분) 한 줄 ──────────────────────────────────────
const List<String> _bloomLines = [
  '이 마음까지 품고, 드디어 활짝 피었어요 🌸',
  '그동안의 마음이 모여 한 송이로 피어났어요 🌸',
  '오래 묻어온 마음이 오늘, 꽃이 됐어요 🌸',
];

const List<String> _grewLines = [
  '덕분에 한 뼘 자랐어요 🌱',
  '오늘의 마음을 양분 삼아 조금 더 자랐어요 🌱',
  '한 뼘 더 커졌어요. 당신 덕분이에요 🌱',
  '마음을 먹고 새 잎을 하나 틔웠어요 🌱',
];

const List<String> _stayLines = [
  '오늘의 마음도 뿌리에 스며들어요.',
  '오늘 자라진 않았지만, 이 마음도 깊이 간직할게요.',
  '조용히 뿌리를 적셔둘게요. 자람은 내일도 이어져요.',
  '서두르지 않아도 돼요. 오늘 마음은 흙 속에 스며요.',
];

String _growth({required bool grew, required int stage}) {
  if (stage >= 5) return _pick(_bloomLines);
  if (grew) return _pick(_grewLines);
  return _pick(_stayLines);
}

/// 식물의 답장 (공감 + 성장). mood: 1..5 또는 null.
/// 감정 태그를 골랐다면 절반 확률로 그 결에 맞춘 공감을 사용해 반복을 줄인다.
String plantReply({
  int? mood,
  required bool grew,
  required int stage,
  List<String> topicTags = const [],
  List<String> emotionTags = const [],
}) {
  final tagLine = _tagEmpathy(emotionTags);
  final empathy = (tagLine != null && _vRng.nextBool())
      ? tagLine
      : _pick(_moodEmpathy(mood));
  return '$empathy\n${_growth(grew: grew, stage: stage)}';
}
