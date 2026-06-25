import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../theme.dart';

/// 기록 탭 — 내가 묻은 마음(잎)을 다시 본다.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final GardenService _garden = GardenService(Supabase.instance.client);
  List<EntryRecord> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _garden.recentEntries();
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마음 기록', style: TextStyle(color: AppColors.ink)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.green,
              child: _entries.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 160),
                      Center(
                        child: Text(
                          '아직 묻은 마음이 없어요.\n정원에서 식물을 톡 눌러 시작해보세요.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: AppColors.faint, height: 1.6),
                        ),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final e = _entries[i];
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
                              Text(_dateTime(e.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.faint)),
                              const SizedBox(height: 6),
                              Text(e.text,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: AppColors.ink)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _dateTime(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}.${two(l.month)}.${two(l.day)}  ${two(l.hour)}:${two(l.minute)}';
  }
}
