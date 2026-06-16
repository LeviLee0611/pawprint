import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_time.dart';
import '../services/reminder_service.dart';
import 'add_record_screen.dart' show showReminderBottomSheet;

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final _service = ReminderService();
  List<Map<String, dynamic>> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getMyReminders();
      if (mounted) setState(() { _reminders = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editReminder(Map<String, dynamic> r) async {
    final remindAt = LocalTime.toLocal(DateTime.parse(r['remind_at'] as String));
    await showReminderBottomSheet(
      context,
      title: r['title'] as String? ?? '알림 수정',
      initialDate: remindAt,
      initialTime: TimeOfDay(hour: remindAt.hour, minute: remindAt.minute),
      onSave: (d, t) async {
        final fullDt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        await _service.updateReminder(r['id'] as String, remindAt: fullDt);
        await _load();
      },
      onDelete: () => _confirmDelete(r['id'] as String),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/포포얼굴사진.png', height: 80),
            const SizedBox(height: 12),
            const Text('알림을 삭제할거냥?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 8),
            const Text('이 알림을 삭제할게요', textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteReminder(id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF0DC), Color(0xFFFFFAF5)],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('예방접종 알림 관리'),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _reminders.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reminders.length,
                  itemBuilder: (_, i) => _buildTile(_reminders[i]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💉', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text('예정된 알림이 없어요',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('예방접종 기록 시\n다음 접종 알림을 설정할 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> r) {
    final fmt = DateFormat('yyyy년 M월 d일', 'ko');
    final remindAt = LocalTime.toLocal(DateTime.parse(r['remind_at'] as String));
    final pet = r['pets'] as Map<String, dynamic>?;
    final petName = pet?['name'] as String? ?? '';
    final petType = pet?['type'] as String? ?? 'cat';
    final petEmoji = petType == 'dog' ? '🐶' : '🐱';
    final dDay = remindAt.difference(LocalTime.now).inDays;
    final isPast = dDay < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPast ? AppColors.card : AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.vaccines_rounded,
                color: isPast ? AppColors.textHint : AppColors.green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['title'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isPast ? AppColors.textHint : AppColors.textPrimary,
                      fontSize: 14),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$petEmoji $petName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    const Text('  ·  ', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    Text(fmt.format(remindAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isPast)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: dDay <= 7 ? AppColors.peachLight : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dDay == 0 ? 'D-Day' : 'D-$dDay',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: dDay <= 7 ? AppColors.peach : AppColors.primary,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('D+${-dDay}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                _editReminder(r);
              } else {
                _confirmDelete(r['id'] as String);
              }
            },
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textHint),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: AppColors.textHint),
                  SizedBox(width: 10),
                  Text('수정'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('삭제', style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
