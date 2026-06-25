import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/crisis.dart';
import '../services/garden_service.dart';

/// 마음 한 줄 묻기 화면. 제출 → 위기감지 → 저장 → 식물 시점 응답 → 정원 복귀.
class InputScreen extends StatefulWidget {
  const InputScreen({super.key, required this.plant});
  final Plant plant;

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final TextEditingController _controller = TextEditingController();
  late final GardenService _garden = GardenService(Supabase.instance.client);
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;

    // 제출 직전 위기 키워드 스캔 — 막지 않되 먼저 지원 화면.
    if (detectCrisis(text)) {
      final proceed = await showCrisisSupport(context);
      if (!proceed) return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _garden.addEntry(plant: widget.plant, text: text);
      if (!mounted) return;
      await _showPlanted(grew: result.grew);
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

  Future<void> _showPlanted({required bool grew}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8E1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            const Text(
              '마음을 흙에 묻었어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              grew ? '양분이 되어 식물이 한 뼘 자랐어요.' : '오늘의 마음이 뿌리에 스며들어요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF8D6E63),
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
          '마음 한 줄 묻기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5D4037),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '아무에게도 보이지 않아요. 마음을 천천히 내려놓으세요.',
                style: TextStyle(fontSize: 13, color: Color(0xFFA1887F)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  maxLength: 500,
                  textAlignVertical: TextAlignVertical.top,
                  enabled: !_submitting,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF5D4037),
                  ),
                  decoration: const InputDecoration(
                    hintText: '오늘 마음에 담아둔 것을 적어보세요…',
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
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7CB342),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '흙에 묻기',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
