import 'dart:math';

const _adjectives = [
  '햇살이 머무는',
  '비를 기다리는',
  '바람을 닮은',
  '그늘에 앉은',
  '새벽을 머금은',
  '달빛을 마신',
  '이슬에 젖은',
  '봄을 품은',
  '조용한',
  '느린 걸음의',
];

const _nouns = ['다육이', '선인장', '잎', '뿌리', '씨앗', '새싹'];

String generateNickname([Random? rng]) {
  final r = rng ?? Random();
  final adj = _adjectives[r.nextInt(_adjectives.length)];
  final noun = _nouns[r.nextInt(_nouns.length)];
  final num = r.nextInt(9000) + 1000; // #1000~#9999
  return '$adj $noun #$num';
}
