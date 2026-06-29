// 양분 태그 정의 — 체크인마다 선택(둘 다 선택). 인사이트의 축이 된다.
// topic(주제/양분): 무엇이 오늘의 양분이 됐나 → 마음 날씨와 교차해 상관관계를 본다.
// emotion(감정): 지금 어떤 결의 감정인가 → 분포·추이를 본다.

class Tag {
  const Tag(this.key, this.label, this.emoji);
  final String key; // DB에 저장되는 안정적인 키 (라벨 바뀌어도 유지)
  final String label;
  final String emoji;
}

/// 주제(양분) 태그 — 무엇이 오늘의 양분이 됐나.
const List<Tag> kTopicTags = [
  Tag('work', '일', '💼'),
  Tag('relationship', '관계', '🤝'),
  Tag('family', '가족', '🏠'),
  Tag('health', '건강', '🌿'),
  Tag('money', '돈', '💰'),
  Tag('rest', '휴식', '🛋️'),
  Tag('achievement', '성취', '🏆'),
  Tag('self', '나 자신', '🪞'),
];

/// 감정 태그 — 지금 마음의 결.
const List<Tag> kEmotionTags = [
  Tag('anger', '분노', '😤'),
  Tag('anxiety', '불안', '😰'),
  Tag('sadness', '슬픔', '😢'),
  Tag('overwhelm', '벅참', '🥹'),
  Tag('numb', '무감각', '😶'),
  Tag('hope', '희망', '🌱'),
];

Tag? topicTagByKey(String key) {
  for (final t in kTopicTags) {
    if (t.key == key) return t;
  }
  return null;
}

Tag? emotionTagByKey(String key) {
  for (final t in kEmotionTags) {
    if (t.key == key) return t;
  }
  return null;
}

/// 키 목록 → 라벨 문자열(쉼표). 알 수 없는 키는 건너뜀.
String topicLabels(List<String> keys) =>
    keys.map((k) => topicTagByKey(k)?.label).whereType<String>().join(', ');

String emotionLabels(List<String> keys) =>
    keys.map((k) => emotionTagByKey(k)?.label).whereType<String>().join(', ');
