import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/record_service.dart';
import '../services/reminder_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../feed/screens/add_post_screen.dart';
import '../../pet/models/pet_model.dart';
import '../../pet/services/pet_service.dart';

class AddRecordScreen extends StatefulWidget {
  final DateTime date;
  final Pet pet;
  final String type;

  const AddRecordScreen({
    super.key,
    required this.date,
    required this.pet,
    required this.type,
  });

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _notesController = TextEditingController();
  final _weightController = TextEditingController();
  final _service = RecordService();
  final _reminderService = ReminderService();
  bool _saving = false;
  File? _photoFile;

  DateTime? _reminderDate;
  TimeOfDay? _reminderTime;

  // 건강 메모 빠른 선택
  final Set<String> _selectedActivities = {};
  static const _quickActivities = [
    ('🛁', '목욕'),
    ('🪮', '빗질'),
    ('✂️', '발톱 정리'),
    ('👂', '귀 청소'),
    ('🦷', '양치'),
    ('💊', '구충제'),
    ('🏥', '병원 방문'),
    ('🎀', '미용'),
  ];
  static const _householdActivities = [
    ('🪣', '모래 교체'),
    ('🚿', '화장실 청소'),
    ('🛁', '전체 목욕'),
    ('💊', '전체 구충제'),
    ('🧹', '집 청소'),
    ('🛒', '용품 보충'),
    ('🏥', '병원 방문'),
    ('📋', '기타'),
  ];

  bool get _isHousehold => widget.pet.isHousehold;
  bool get _isWeight => widget.type == 'weight';
  bool get _isPhoto => widget.type == 'photo';
  bool get _isHealth => widget.type == 'health';

  String get _typeLabel {
    switch (widget.type) {
      case 'weight':
        return '몸무게 기록';
      case 'health':
        return '예방접종';
      case 'note':
        return '건강 메모';
      case 'photo':
        return '사진 기록';
      default:
        return '기록';
    }
  }

  String get _typeEmoji {
    switch (widget.type) {
      case 'weight':
        return '📊';
      case 'health':
        return '💉';
      case 'note':
        return '📝';
      case 'photo':
        return '📷';
      default:
        return '📋';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }

  Future<void> _save() async {
    if (_isPhoto) {
      if (_photoFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 선택해주세요')),
        );
        return;
      }
      setState(() => _saving = true);
      try {
        await _service.addRecord(
          petId: _isHousehold ? null : widget.pet.id,
          date: widget.date,
          type: widget.type,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          photo: _photoFile,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
        return;
      }
    } else if (_isWeight) {
      final val = double.tryParse(_weightController.text.trim());
      if (val == null || val <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('몸무게를 입력해주세요 (예: 4.5)')),
        );
        return;
      }
      setState(() => _saving = true);
      try {
        await _service.addRecord(
          petId: widget.pet.id,
          date: widget.date,
          type: widget.type,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          value: val,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
        return;
      }
    } else {
      final freeText = _notesController.text.trim();
      final String? combinedNote;
      if (!_isHealth) {
        // note 타입: 칩 + 직접 입력 조합
        final chips = _selectedActivities.toList();
        if (chips.isEmpty && freeText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('항목을 선택하거나 내용을 입력해주세요')),
          );
          return;
        }
        combinedNote = [
          if (chips.isNotEmpty) chips.join(', '),
          if (freeText.isNotEmpty) freeText,
        ].join('\n');
      } else {
        combinedNote = freeText;
        if (freeText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('내용을 입력해주세요')),
          );
          return;
        }
      }
      setState(() => _saving = true);
      try {
        final recordId = await _service.addRecord(
          petId: _isHousehold ? null : widget.pet.id,
          date: widget.date,
          type: widget.type,
          notes: combinedNote,
        );
        // 예방접종 알림 설정 (household는 알림 없음)
        if (_isHealth && !_isHousehold && _reminderDate != null) {
          final t = _reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
          final fullDt = DateTime(
            _reminderDate!.year, _reminderDate!.month, _reminderDate!.day,
            t.hour, t.minute,
          );
          await _reminderService.addReminder(
            petId: widget.pet.id,
            title: '${widget.pet.name} 예방접종 알림: ${_notesController.text.trim()}',
            remindAt: fullDt,
            recordId: recordId,
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
        return;
      }
    }

    if (!mounted) return;
    // 사진 기록이면 피드 공유 다이얼로그 표시
    if (_isPhoto && _photoFile != null) {
      final share = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('피드에도 공유할까요? 🐾'),
          content: const Text('저장된 사진을 피드에 올리면\n다른 반려인들과 나눌 수 있어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('건너뛰기',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('공유하기',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (share == true) {
        final pets = await PetService().getMyPets();
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddPostScreen(
              pets: pets,
              initialImage: _photoFile,
              initialPet: pets.firstWhere(
                (p) => p.id == widget.pet.id,
                orElse: () => pets.isNotEmpty ? pets.first : widget.pet,
              ),
            ),
          ),
        );
      }
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final formatted =
        DateFormat('yyyy년 M월 d일 (E)', 'ko').format(widget.date);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_typeLabel),
        actions: [
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
                  : const Text(
                      '저장',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
            ),
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
                  Text(_typeEmoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isHousehold ? '🏠 공통 기록' : '${widget.pet.emoji} ${widget.pet.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isHousehold ? '모든 아이 / 집 전체 · $formatted' : formatted,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            if (_isPhoto) ...[
              // 사진 선택 영역
              GestureDetector(
                onTap: _pickPhoto,
                child: _photoFile == null
                    ? Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primaryLight, width: 2),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 48, color: AppColors.primary),
                            SizedBox(height: 12),
                            Text('사진을 선택해주세요',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                            SizedBox(height: 4),
                            Text('탭해서 갤러리 열기',
                                style: TextStyle(
                                    color: AppColors.textHint, fontSize: 12)),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _photoFile!,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _photoFile = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius:
                                        BorderRadius.circular(20)),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _pickPhoto,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius:
                                        BorderRadius.circular(20)),
                                child: const Text('사진 변경',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12)),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              const Text('한마디 (선택)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 15)),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '오늘 ${widget.pet.name}는 어땠나요?',
                  hintStyle: const TextStyle(
                      color: AppColors.textHint, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ] else if (_isWeight) ...[
              const Text('몸무게 (kg)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 15)),
              const SizedBox(height: 10),
              TextField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '0.0',
                  hintStyle: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  suffixText: 'kg',
                  suffixStyle: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 18),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                ),
              ),
              const SizedBox(height: 24),
              const Text('메모 (선택)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 15)),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '추가로 기록할 내용이 있으면 적어주세요',
                  hintStyle: const TextStyle(
                      color: AppColors.textHint, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ] else if (_isHealth) ...[
              const Text('접종 내용',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 15)),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 4,
                minLines: 3,
                autofocus: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '예: 광견병 예방접종 1차',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
              ReminderSection(
                date: _reminderDate,
                time: _reminderTime,
                onTap: () => showReminderBottomSheet(
                  context,
                  title: '다음 접종 알림',
                  initialDate: _reminderDate ?? widget.date.add(const Duration(days: 365)),
                  initialTime: _reminderTime,
                  onSave: (d, t) => setState(() { _reminderDate = d; _reminderTime = t; }),
                  onDelete: _reminderDate != null
                      ? () => setState(() { _reminderDate = null; _reminderTime = null; })
                      : null,
                ),
              ),
            ] else ...[
              // 건강 메모 — 빠른 선택 칩
              Text(_isHousehold ? '어떤 케어를 했나요?' : '어떤 케어를 했나요?',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 15)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (_isHousehold ? _householdActivities : _quickActivities).map((a) {
                  final selected = _selectedActivities.contains(a.$2);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedActivities.remove(a.$2);
                      } else {
                        _selectedActivities.add(a.$2);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.peach : AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected ? AppColors.peach : AppColors.brownLight,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(a.$1, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(a.$2,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text('직접 입력 (선택)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 15)),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 5,
                minLines: 3,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: _isHousehold
                      ? '추가로 남기고 싶은 내용을 적어주세요\n예: 모래를 새 브랜드로 교체했어요'
                      : '추가로 남기고 싶은 내용을 적어주세요\n예: 오늘 첫 미용, 밥을 잘 안 먹었어요',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReminderSection extends StatelessWidget {
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ReminderSection({
    super.key,
    required this.date,
    required this.time,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy년 M월 d일', 'ko');
    final isSet = date != null;
    final timeStr = time != null
        ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
        : '09:00';

    if (!isSet) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.brownLight, width: 1),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_alarm_rounded, size: 18, color: AppColors.textHint),
              SizedBox(width: 8),
              Text('다음 접종 알림 추가', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_active_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmt.format(date!),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(timeStr, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.edit_outlined, size: 16, color: AppColors.textHint),
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 16, color: AppColors.textHint),
              ),
            ),
        ],
      ),
    );
  }
}

// add_record, record_detail, reminder_screen 에서 공유
Future<void> showReminderBottomSheet(
  BuildContext context, {
  required String title,
  required DateTime? initialDate,
  required TimeOfDay? initialTime,
  required void Function(DateTime date, TimeOfDay time) onSave,
  VoidCallback? onDelete,
}) async {
  final fmt = DateFormat('yyyy년 M월 d일', 'ko');
  DateTime pickedDate = initialDate ?? DateTime.now().add(const Duration(days: 365));
  final initTime = initialTime ?? const TimeOfDay(hour: 9, minute: 0);
  int hour = initTime.hour;
  int minute = initTime.minute == 30 ? 30 : 0;
  final hourController = FixedExtentScrollController(initialItem: hour);

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              // 날짜
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: pickedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    locale: const Locale('ko'),
                  );
                  if (picked != null) setSheet(() => pickedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(fmt.format(pickedDate),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textHint),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 시간 — 드럼롤(시) + 토글(분) 인라인
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 시(hour) 드럼롤
                    Expanded(
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.access_time_outlined, size: 13, color: AppColors.primary),
                              SizedBox(width: 5),
                              Text('시', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 선택 영역 하이라이트
                                Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                ListWheelScrollView.useDelegate(
                                  controller: hourController,
                                  itemExtent: 40,
                                  physics: const FixedExtentScrollPhysics(),
                                  perspective: 0.003,
                                  onSelectedItemChanged: (val) => setSheet(() => hour = val),
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    childCount: 24,
                                    builder: (_, i) => Center(
                                      child: Text(
                                        '${i.toString().padLeft(2, '0')}시',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: hour == i ? FontWeight.bold : FontWeight.normal,
                                          color: hour == i ? AppColors.textPrimary : AppColors.textHint,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // 상하 페이드
                                Positioned(
                                  top: 0, left: 0, right: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [AppColors.background, AppColors.background.withValues(alpha: 0)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [AppColors.background, AppColors.background.withValues(alpha: 0)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 분(minute) :00 / :30 토글
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.timer_outlined, size: 13, color: AppColors.primary),
                              SizedBox(width: 5),
                              Text('분', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _MinuteToggle(
                            label: ':00',
                            selected: minute == 0,
                            onTap: () => setSheet(() => minute = 0),
                          ),
                          const SizedBox(height: 8),
                          _MinuteToggle(
                            label: ':30',
                            selected: minute == 30,
                            onTap: () => setSheet(() => minute = 30),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onSave(pickedDate, TimeOfDay(hour: hour, minute: minute));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('저장하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () { Navigator.pop(ctx); onDelete(); },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('알림 삭제', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  } finally {
    hourController.dispose();
  }
}

class _MinuteToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MinuteToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
