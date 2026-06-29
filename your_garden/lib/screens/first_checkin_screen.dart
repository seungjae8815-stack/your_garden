import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/daily_prompts.dart';
import '../services/auth_service.dart';
import '../services/crisis.dart';
import '../services/garden_service.dart';
import '../theme.dart';
import '../widgets/mood_icon.dart';
import '../widgets/plant_painter.dart';
import 'main_shell.dart';

/// 온보딩 직후 손잡은 첫 체크인.
/// 마음 한 줄(또는 마음 날씨)을 묻으면, 이름 지어준 식물이 눈앞에서 새싹을
/// 틔우며 한 뼘 자란다 — 첫 60~90초의 보람.
class FirstCheckInScreen extends StatefulWidget {
  const FirstCheckInScreen({
    super.key,
    required this.profile,
    required this.plant,
  });
  final AuthResult profile;
  final Plant plant;

  @override
  State<FirstCheckInScreen> createState() => _FirstCheckInScreenState();
}

enum _Phase { input, grown }

class _FirstCheckInScreenState extends State<FirstCheckInScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final GardenService _garden = GardenService(Supabase.instance.client);

  late final AnimationController _growCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  _Phase _phase = _Phase.input;
  int? _mood;
  bool _submitting = false;

  Plant _plant = const Plant(id: '', stage: 1, isComplete: false);
  String _reply = '';

  // 온보딩의 첫 식물에는 부드러운 환영 질문을 고정으로 둔다(굴리기 X — 첫 경험은 단순하게).
  static const String _welcomePrompt = '지금, 마음속에 어떤 말이 맴돌고 있나요?';

  String get _plantName =>
      (widget.plant.name != null && widget.plant.name!.trim().isNotEmpty)
          ? widget.plant.name!.trim()
          : speciesLabel(widget.plant.species);

  bool get _canSubmit =>
      !_submitting && (_mood != null || _controller.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
  }

  @override
  void dispose() {
    _growCtrl.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final text = _controller.text.trim();
    FocusScope.of(context).unfocus();

    // 위기 키워드 스캔 — 막지 않되 먼저 도움 안내.
    if (text.isNotEmpty && detectCrisis(text)) {
      final proceed = await showCrisisSupport(context);
      if (!proceed) return;
    }

    setState(() => _submitting = true);
    try {
      final result =
          await _garden.addEntry(plant: widget.plant, text: text, mood: _mood);
      markGardenDirty();
      if (!mounted) return;
      setState(() {
        _plant = result.plant;
        _reply = result.reply;
        _phase = _Phase.grown;
      });
      _growCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('묻기에 실패했어요: $e')),
      );
    }
  }

  void _toGarden() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainShell(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _phase == _Phase.input ? _inputView() : _grownView(),
        ),
      ),
    );
  }

  // ── 입력 단계 ─────────────────────────────────────────────
  Widget _inputView() {
    return Column(
      key: const ValueKey('input'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                Center(
                  child: Text('처음 만나는 $_plantName',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFA1887F))),
                ),
                const SizedBox(height: 10),
                SizedBox(height: 130, child: _plantStage(widget.plant.stage)),
                const SizedBox(height: 18),
                const Text(
                  '첫 마음을 흙에 묻어볼까요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5D4037)),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_plantName이(가) 당신의 첫 마음을 양분 삼아 자라요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: Color(0xFF8D6E63)),
                ),
                const SizedBox(height: 22),
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
                const Text('아무에게도 보이지 않아요. 천천히 내려놓으세요. (선택)',
                    style: TextStyle(fontSize: 13, color: Color(0xFFA1887F))),
                const SizedBox(height: 10),
                SizedBox(height: 150, child: _field()),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
          child: _PrimaryButton(
            label: '흙에 묻기',
            loading: _submitting,
            onPressed: _canSubmit ? _submit : null,
          ),
        ),
      ],
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
          const Text('첫 질문',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green)),
          const SizedBox(height: 6),
          const Text(_welcomePrompt,
              style: TextStyle(
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
                    color:
                        selected ? AppColors.greenDark : const Color(0xFFA1887F),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  // ── 보람(성장) 단계 ───────────────────────────────────────
  Widget _grownView() {
    final grew = _plant.stage > widget.plant.stage;
    return Column(
      key: const ValueKey('grown'),
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 200, child: _growthAnimation()),
                const SizedBox(height: 28),
                Text(
                  grew ? '첫 마음이 양분이 됐어요' : '마음이 흙에 스며들었어요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5D4037)),
                ),
                const SizedBox(height: 8),
                Text(
                  grew
                      ? '$_plantName이(가) 한 뼘 자랐어요.'
                      : '$_plantName이(가) 마음을 품었어요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, height: 1.5, color: Color(0xFF8D6E63)),
                ),
                if (_reply.trim().isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0D7C5)),
                    ),
                    child: Text(
                      _reply,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, height: 1.55, color: Color(0xFF5D4037)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
          child: Column(
            children: [
              Text(
                '내일도 한 줄을 묻으면, $_plantName은(는) 또 자라요.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFFA1887F)),
              ),
              const SizedBox(height: 12),
              _PrimaryButton(label: '내 정원으로', onPressed: _toGarden),
            ],
          ),
        ),
      ],
    );
  }

  // 새싹이 이전 단계 → 새 단계로 자라며 살짝 튀어오르는 연출 + 반짝임.
  Widget _growthAnimation() {
    final from = widget.plant.stage;
    final to = _plant.stage;
    return AnimatedBuilder(
      animation: _growCtrl,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_growCtrl.value);
        // 살짝 솟구쳤다 가라앉는 바운스.
        final pop = 1 + 0.10 * (1 - (2 * t - 1).abs());
        final sparkle = (1 - (_growCtrl.value)).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Transform.scale(
              scale: pop,
              alignment: Alignment.bottomCenter,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Opacity(opacity: 1 - t, child: _plantStage(from)),
                  Opacity(opacity: t, child: _plantStage(to)),
                ],
              ),
            ),
            if (sparkle > 0)
              Positioned(
                top: 10,
                child: Opacity(
                  opacity: sparkle,
                  child: Transform.scale(
                    scale: 0.8 + 0.4 * _growCtrl.value,
                    child: const Text('✨', style: TextStyle(fontSize: 26)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // 단계별 식물 그림 — 종류의 단계 비율(heightFactor)에 맞춰 크기를 준다.
  Widget _plantStage(int stage) {
    final hf = PlantSprite.heightFactor(widget.plant.species, stage);
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: hf.clamp(0.2, 1.0),
        child: PlantSprite(species: widget.plant.species, stage: stage),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCFE3B8),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 2,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
