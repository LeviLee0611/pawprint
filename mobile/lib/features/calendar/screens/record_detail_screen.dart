import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/image_util.dart';
import 'package:intl/intl.dart';
import '../models/record_model.dart';
import '../services/record_service.dart';
import '../services/reminder_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_time.dart';
import '../../pet/models/pet_model.dart';
import 'add_record_screen.dart' show showReminderBottomSheet;

class RecordDetailScreen extends StatefulWidget {
  final Record record;
  final Pet pet;

  const RecordDetailScreen({
    super.key,
    required this.record,
    required this.pet,
  });

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  final _service = RecordService();
  final _reminderService = ReminderService();
  late final TextEditingController _notesController;
  late final TextEditingController _weightController;

  bool _editing = false;
  bool _saving = false;
  File? _newPhotoFile;

  List<Map<String, dynamic>> _existingReminders = [];

  bool get _isWeight => widget.record.type == 'weight';
  bool get _isPhoto => widget.record.type == 'photo';
  bool get _isHealth => widget.record.type == 'health';

  @override
  void initState() {
    super.initState();
    if (_isHealth) _loadReminders();
    _notesController =
        TextEditingController(text: widget.record.notes ?? '');
    _weightController = TextEditingController(
        text: widget.record.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    try {
      final all = await _reminderService.getMyReminders();
      if (mounted) {
        setState(() => _existingReminders = all.where((r) {
          final rid = r['record_id'] as String?;
          if (rid != null) return rid == widget.record.id;
          return r['pet_id'] == widget.pet.id;
        }).toList());
      }
    } catch (_) {}
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _newPhotoFile = File(picked.path));
  }

  Future<void> _save() async {
    if (_isWeight) {
      final val = double.tryParse(_weightController.text.trim());
      if (val == null || val <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('몸무게를 올바르게 입력해주세요')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await _service.updateRecord(
        id: widget.record.id,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        value: _isWeight
            ? double.tryParse(_weightController.text.trim())
            : null,
        newPhoto: _newPhotoFile,
        oldPhotoUrl: _newPhotoFile != null ? widget.record.photoUrl : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatted =
        DateFormat('yyyy년 M월 d일 (E)', 'ko').format(widget.record.date);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.record.label),
        actions: [
          if (_editing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Text('저장',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(widget.record.emoji,
                      style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.pet.emoji} ${widget.pet.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(formatted,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 사진
            if (_isPhoto) ...[
              _sectionLabel('사진'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _editing ? _pickPhoto : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _newPhotoFile != null
                      ? Image.file(_newPhotoFile!,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover)
                      : widget.record.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: toTransformUrl(widget.record.photoUrl, width: 900, quality: 85),
                              width: double.infinity,
                              height: 240,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const SizedBox(),
                            )
                          : Container(
                              width: double.infinity,
                              height: 240,
                              color: AppColors.card,
                              child: const Icon(Icons.image_outlined,
                                  size: 48, color: AppColors.textHint),
                            ),
                ),
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('사진 변경'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary),
                ),
              ],
              const SizedBox(height: 20),
            ],

            // 몸무게
            if (_isWeight) ...[
              _sectionLabel('몸무게 (kg)'),
              const SizedBox(height: 10),
              _editing
                  ? TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: _inputDecoration('예: 4.5'),
                    )
                  : _infoBox('${widget.record.value ?? '-'} kg'),
              const SizedBox(height: 20),
            ],

            // 메모
            if (!_isPhoto || _editing || (widget.record.notes?.isNotEmpty ?? false)) ...[
              _sectionLabel('메모'),
              const SizedBox(height: 10),
              _editing
                  ? TextField(
                      controller: _notesController,
                      maxLines: 5,
                      decoration: _inputDecoration('메모를 입력하세요'),
                    )
                  : widget.record.notes != null &&
                          widget.record.notes!.isNotEmpty
                      ? _infoBox(widget.record.notes!)
                      : _infoBox('메모 없음',
                          hint: true),
            ],

            // 예방접종 알림 (health 타입만)
            if (_isHealth) ...[
              const SizedBox(height: 24),
              _sectionLabel('알림'),
              const SizedBox(height: 10),
              ..._existingReminders.map((r) {
                final remindAt = LocalTime.toLocal(DateTime.parse(r['remind_at'] as String));
                final fmt = DateFormat('yyyy년 M월 d일', 'ko');
                final dDay = remindAt.difference(LocalTime.now).inDays;
                final isPast = dDay < 0;
                final timeStr = '${remindAt.hour.toString().padLeft(2, '0')}:${remindAt.minute.toString().padLeft(2, '0')}';
                return GestureDetector(
                  onTap: () => showReminderBottomSheet(
                    context,
                    title: r['title'] as String? ?? '알림',
                    initialDate: remindAt,
                    initialTime: TimeOfDay(hour: remindAt.hour, minute: remindAt.minute),
                    onSave: (d, t) async {
                      final fullDt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      await _reminderService.updateReminder(r['id'] as String, remindAt: fullDt);
                      _loadReminders();
                    },
                    onDelete: () async {
                      await _reminderService.deleteReminder(r['id'] as String);
                      _loadReminders();
                    },
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_outlined, size: 16,
                            color: isPast ? AppColors.textHint : AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${fmt.format(remindAt)}  $timeStr',
                            style: TextStyle(
                              fontSize: 14,
                              color: isPast ? AppColors.textHint : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!isPast) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: dDay <= 7 ? AppColors.peachLight : AppColors.primaryLight.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dDay == 0 ? 'D-Day' : 'D-$dDay',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold,
                                color: dDay <= 7 ? AppColors.peach : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textHint),
                      ],
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () => showReminderBottomSheet(
                  context,
                  title: '알림 추가',
                  initialDate: widget.record.date.add(const Duration(days: 365)),
                  initialTime: const TimeOfDay(hour: 9, minute: 0),
                  onSave: (d, t) async {
                    final fullDt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                    await _reminderService.addReminder(
                      petId: widget.pet.id,
                      title: '${widget.pet.name} 예방접종 알림',
                      remindAt: fullDt,
                      recordId: widget.record.id,
                    );
                    _loadReminders();
                  },
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.add_rounded, size: 16, color: AppColors.textHint),
                      SizedBox(width: 12),
                      Text('알림 추가', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            letterSpacing: 0.4),
      );

  Widget _infoBox(String text, {bool hint = false}) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.brown.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: hint ? AppColors.textHint : AppColors.textPrimary,
            height: 1.5,
          ),
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textHint, fontSize: 14),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
