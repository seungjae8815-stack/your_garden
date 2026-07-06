import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/share_util.dart';
import '../theme.dart';

// 추천 문구 — 위로·응원·따뜻함을 담은 짧은 두 줄 시.
const List<String> _captions = [
  '당신은 이미\n충분히 잘하고 있어요',
  '오늘 하루도\n버텨줘서 고마워요',
  '괜찮아요,\n천천히 가도 돼요',
  '당신의 계절은\n반드시 찾아옵니다',
  '지금 이대로도\n충분히 아름다워요',
  '흐린 날 뒤엔\n늘 맑은 날이 와요',
  '당신이 흘린 마음마다\n꽃이 필 거예요',
  '조금 쉬어가도\n정말 괜찮아요',
  '당신은\n혼자가 아니에요',
  '오늘의 슬픔도\n내일의 양분이 돼요',
  '작은 한 걸음도\n분명한 나아감이에요',
  '당신의 마음에\n봄이 스며들기를',
  '울어도 괜찮아요,\n그래도 자라니까요',
  '여기까지 온 당신,\n참 대단해요',
  '느려도 괜찮아,\n꽃은 결국 피니까',
  '당신의 하루에\n따뜻한 볕이 들기를',
  '지친 마음에\n작은 위로를 건네요',
  '그 마음, 다 알아요.\n토닥토닥',
  '어제보다 오늘,\n조금 더 단단해졌어요',
  '당신이라는 정원은\n계속 자라고 있어요',
  '오늘도 피어나줘서\n고마워요',
  '당신은 당신에게\n좋은 사람이에요',
];

/// 정원 스냅샷에 문구(중앙)·닉네임·날짜·워터마크를 붙여 공유하는 미리보기.
class SharePreviewScreen extends StatefulWidget {
  const SharePreviewScreen({
    super.key,
    required this.imageBytes,
    required this.nickname,
  });
  final Uint8List imageBytes;
  final String nickname;

  @override
  State<SharePreviewScreen> createState() => _SharePreviewScreenState();
}

class _SharePreviewScreenState extends State<SharePreviewScreen> {
  final GlobalKey _cardKey = GlobalKey();
  final Random _rng = Random();
  String _caption = '';
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _preloadFont();
  }

  // 캡처 전에 손글씨 폰트를 미리 받아둔다(공유 이미지에 폰트가 빠지지 않게).
  Future<void> _preloadFont() async {
    try {
      await GoogleFonts.pendingFonts([GoogleFonts.gaegu()]);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  TextStyle _captionStyle() => GoogleFonts.gaegu(
    fontSize: 25,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF4E3B2A),
  );

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await captureBoundary(_cardKey, pixelRatio: 2.5);
      if (bytes != null) {
        await shareBytes(bytes, text: '${widget.nickname}의 정원 🌿 #너의정원');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _suggestCaption() {
    String c;
    do {
      c = _captions[_rng.nextInt(_captions.length)];
    } while (c == _caption && _captions.length > 1);
    setState(() => _caption = c);
  }

  Future<void> _editCaption() async {
    final controller = TextEditingController(text: _caption);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '문구 쓰기',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 60,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.4),
          decoration: const InputDecoration(
            hintText: '정원에 남길 한마디…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('지우기'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _caption = result);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = '${now.year}.${now.month}.${now.day}';
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('정원 공유', style: TextStyle(color: AppColors.ink)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: Container(
                      width: 360,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 정원 이미지 + 중앙 문구 오버레이
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: Stack(
                              children: [
                                Image.memory(
                                  widget.imageBytes,
                                  width: 360,
                                  fit: BoxFit.fitWidth,
                                ),
                                if (_caption.isNotEmpty)
                                  Positioned.fill(
                                    child: Center(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 30,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.66,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Text(
                                          _caption,
                                          textAlign: TextAlign.center,
                                          style: _captionStyle(),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // 워터마크 + 닉네임 + 날짜
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                            child: Row(
                              children: [
                                const Text(
                                  '🌿',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '너의 정원',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                    color: AppColors.greenDark,
                                  ),
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      widget.nickname,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    Text(
                                      date,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.faint,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 하단 컨트롤 (시스템바 위로)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _editCaption,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.greenDark,
                            side: const BorderSide(color: AppColors.green),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('직접 쓰기'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _suggestCaption,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.greenDark,
                            side: const BorderSide(color: AppColors.green),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('추천 문구'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _sharing ? null : _share,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      icon: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.ios_share),
                      label: const Text(
                        '공유하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
