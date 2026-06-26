import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../theme.dart';
import '../widgets/mood_icon.dart';

/// 기록 탭 — 마음 달력. 날짜마다 그날의 마음 날씨를 표시하고, 누르면 그날의 기록을 본다.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final GardenService _garden = GardenService(Supabase.instance.client);
  final Map<String, List<EntryRecord>> _byDay = {};
  bool _loading = true;

  late DateTime _month; // 표시 중인 달 (1일)
  late DateTime _selected; // 선택한 날

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    _load();
    gardenDirty.addListener(_onDirty);
  }

  @override
  void dispose() {
    gardenDirty.removeListener(_onDirty);
    super.dispose();
  }

  void _onDirty() {
    if (mounted) _load();
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<void> _load() async {
    try {
      final list = await _garden.recentEntries(limit: 800);
      _byDay.clear();
      for (final e in list) {
        final l = e.createdAt.toLocal();
        (_byDay[_key(DateTime(l.year, l.month, l.day))] ??= []).add(e);
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // 그날 대표 기분 (가장 최근 기록의 기분).
  int? _moodOfDay(DateTime d) {
    final list = _byDay[_key(d)];
    if (list == null) return null;
    for (final e in list) {
      if (e.mood != null) return e.mood;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마음 달력', style: TextStyle(color: AppColors.ink)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : Column(
              children: [
                _monthHeader(),
                _weekdayRow(),
                _calendarGrid(),
                const Divider(height: 1, color: AppColors.border),
                Expanded(child: _dayEntries()),
              ],
            ),
    );
  }

  Widget _monthHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.sub),
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1)),
          ),
          Text('${_month.year}.${_month.month.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.sub),
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _weekdayRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(_weekdays[i],
                    style: TextStyle(
                        fontSize: 12,
                        color: i == 0
                            ? const Color(0xFFD08770)
                            : AppColors.faint)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _calendarGrid() {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday % 7; // 일요일 시작 (Sun→0)
    final cells = <Widget>[];
    for (var i = 0; i < offset; i++) {
      cells.add(const SizedBox.shrink());
    }
    final today = DateTime.now();
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_month.year, _month.month, day);
      final has = _byDay.containsKey(_key(date));
      final mood = _moodOfDay(date);
      final selected = _key(date) == _key(_selected);
      final isToday = _key(date) == _key(today);
      cells.add(GestureDetector(
        onTap: () => setState(() => _selected = date),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDCEFC4) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isToday
                ? Border.all(color: AppColors.green, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.sub,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400)),
              const SizedBox(height: 2),
              SizedBox(
                height: 22,
                child: mood != null
                    ? MoodIcon(value: mood, size: 20)
                    : has
                        ? const Icon(Icons.eco,
                            size: 13, color: AppColors.green)
                        : null,
              ),
            ],
          ),
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.72,
        children: cells,
      ),
    );
  }

  Widget _dayEntries() {
    final list = _byDay[_key(_selected)] ?? const [];
    final title =
        '${_selected.month}월 ${_selected.day}일 (${_weekdays[_selected.weekday % 7]})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('이 날의 기록이 없어요',
                      style: TextStyle(color: AppColors.faint)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _entryCard(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _entryCard(EntryRecord e) {
    final l = e.createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (e.mood != null) ...[
                MoodIcon(value: e.mood!, size: 18),
                const SizedBox(width: 6),
              ],
              Text('${two(l.hour)}:${two(l.minute)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.faint)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            e.text.isEmpty ? '오늘의 마음 날씨를 남겼어요' : e.text,
            style: TextStyle(
                fontSize: 15,
                height: 1.5,
                fontStyle:
                    e.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                color: e.text.isEmpty ? AppColors.faint : AppColors.ink),
          ),
          if (e.reply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F7E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌿', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.reply,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.greenDark)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
