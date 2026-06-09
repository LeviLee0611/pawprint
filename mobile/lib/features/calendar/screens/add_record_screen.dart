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

  // 예방접종 알림 설정
  bool _reminderEnabled = false;
  DateTime? _reminderDate;

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
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
        await _service.addRecord(
          petId: _isHousehold ? null : widget.pet.id,
          date: widget.date,
          type: widget.type,
          notes: combinedNote,
        );
        // 예방접종 알림 설정 (household는 알림 없음)
        if (_isHealth && !_isHousehold && _reminderEnabled && _reminderDate != null) {
          await _reminderService.addReminder(
            petId: widget.pet.id,
            title: '${widget.pet.name} 예방접종 알림: ${_notesController.text.trim()}',
            remindAt: _reminderDate!,
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
              _ReminderSection(
                enabled: _reminderEnabled,
                date: _reminderDate,
                onToggle: (v) => setState(() {
                  _reminderEnabled = v;
                  if (v && _reminderDate == null) {
                    _reminderDate = widget.date.add(const Duration(days: 365));
                  }
                }),
                onPickDate: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _reminderDate ?? widget.date.add(const Duration(days: 365)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    locale: const Locale('ko'),
                  );
                  if (picked != null) setState(() => _reminderDate = picked);
                },
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

class _ReminderSection extends StatelessWidget {
  final bool enabled;
  final DateTime? date;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickDate;

  const _ReminderSection({
    required this.enabled,
    required this.date,
    required this.onToggle,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy년 M월 d일', 'ko');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('다음 접종 알림',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onPickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      date != null ? fmt.format(date!) : '날짜를 선택해주세요',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('  선택한 날에 푸시 알림을 보내드려요',
                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }
}
