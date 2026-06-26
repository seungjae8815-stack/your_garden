import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/daily_prompts.dart';
import '../services/crisis.dart';
import '../services/garden_service.dart';
import '../theme.dart';
import '../widgets/mood_icon.dart';

/// 매일 체크인 화면 — 오늘의 질문 + 기분(1탭) + 마음 한 줄(선택).
/// 기분만 골라도 묻을 수 있다(마찰 최소화). 글을 쓰기 시작하면 입력칸이 크게 위로 올라온다.
class InputScreen extends StatefulWidget {
  const InputScreen({super.key, required this.plant});
  final Plant plant;

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final GlobalKey _fieldKey = GlobalKey(); // 입력칸 묶음 — 포커스 시 상단으로 스크롤
  late final GardenService _garden = GardenService(Supabase.instance.client);
  String _prompt = todaysPrompt();
  int? _mood; // 선택한 기분 1..5
  bool _submitting = false;

  bool get _canSubmit =>
      !_submitting && (_mood != null || _controller.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(() {
      if (_focus.hasFocus) _scrollFieldToTop();
    });
  }

  // 자판 높이가 바뀔 때(올라올 때)마다 호출 — 이때 스크롤하면 타이밍이 정확.
  @override
  void didChangeMetrics() {
    if (_focus.hasFocus) _scrollFieldToTop();
  }

  // 입력칸 묶음(안내+칸)을 화면 상단으로 끌어올린다.
  void _scrollFieldToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _fieldKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(ctx,
          alignment: 0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final text = _controller.text.trim();

    // 제출 직전 위기 키워드 스캔 — 막지 않되 먼저 지원 화면.
    if (text.isNotEmpty && detectCrisis(text)) {
      final proceed = await showCrisisSupport(context);
      if (!proceed) return;
    }

    setState(() => _submitting = true);
    try {
      final result =
          await _garden.addEntry(plant: widget.plant, text: text, mood: _mood);
      markGardenDirty(); // 달력·도감 즉시 갱신
      if (!mounted) return;
      await _showPlanted(result.reply);
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('묻기에 실패했어요: $e')),
      );
    }
  }

  // 식물의 답장을 보여준다.
  Future<void> _showPlanted(String reply) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8E1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌿', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 14),
            const Text(
              '마음을 흙에 묻었어요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF8D6E63)),
            ),
            const SizedBox(height: 14),
            // 식물의 답장 (말풍선 느낌)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0D7C5)),
              ),
              child: Text(
                reply,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, height: 1.55, color: Color(0xFF5D4037)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('정원으로'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF8D6E63),
        title: const Text(
          '오늘의 마음',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF5D4037)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _fullLayout()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7CB342),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCFE0B4),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('흙에 묻기',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 질문 + 기분 + 입력칸(스크롤). 입력칸을 누르면 상단으로 스크롤된다.
  Widget _fullLayout() {
    // 자판이 올라오면 아래 여백을 넉넉히 줘서, 입력칸을 화면 최상단까지 끌어올릴 수 있게.
    final media = MediaQuery.of(context);
    final extra = media.viewInsets.bottom > 0 ? media.size.height * 0.6 : 0.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 8 + extra),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _questionCard(),
          const SizedBox(height: 18),
          const Text('지금 마음 날씨는 어떤가요?',
              style: TextStyle(fontSize: 13, color: Color(0xFFA1887F))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final m in kMoods) _moodButton(m)],
          ),
          const SizedBox(height: 18),
          Column(
            key: _fieldKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('아무에게도 보이지 않아요. 천천히 내려놓으세요. (선택)',
                  style: TextStyle(fontSize: 13, color: Color(0xFFA1887F))),
              const SizedBox(height: 10),
              SizedBox(height: 220, child: _field()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D7C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('오늘의 질문',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green)),
              const Spacer(),
              if (_mood != null) ...[
                MoodIcon(value: _mood!, size: 16),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: _submitting
                    ? null
                    : () => setState(() => _prompt = anotherPrompt(_prompt)),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh, size: 15, color: Color(0xFFA1887F)),
                    SizedBox(width: 3),
                    Text('다른 질문',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFFA1887F))),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_prompt,
              style: const TextStyle(
                  fontSize: 16.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4037))),
        ],
      ),
    );
  }

  Widget _field() {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLines: null,
      expands: true,
      maxLength: 500,
      textAlignVertical: TextAlignVertical.top,
      enabled: !_submitting,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF5D4037)),
      decoration: const InputDecoration(
        hintText: '떠오르는 대로 적어보세요…',
        hintStyle: TextStyle(color: Color(0xFFBCAAA4)),
        filled: true,
        fillColor: Color(0xFFFFFDF5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFFE0D7C5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFFE0D7C5)),
        ),
        contentPadding: EdgeInsets.all(16),
      ),
    );
  }

  Widget _moodButton(Mood m) {
    final selected = _mood == m.value;
    return GestureDetector(
      onTap: _submitting ? null : () => setState(() => _mood = m.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDCEFC4) : const Color(0xFFFFFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.green : const Color(0xFFE0D7C5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            MoodIcon(value: m.value, size: 38),
            const SizedBox(height: 4),
            Text(m.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9.5,
                    height: 1.1,
                    color: selected ? AppColors.greenDark : const Color(0xFFA1887F),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
