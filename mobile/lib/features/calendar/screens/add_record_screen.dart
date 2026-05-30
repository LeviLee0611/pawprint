import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/record_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../pet/models/pet_model.dart';

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
  bool _saving = false;

  bool get _isWeight => widget.type == 'weight';

  String get _typeLabel {
    switch (widget.type) {
      case 'weight':
        return '몸무게 기록';
      case 'health':
        return '예방접종';
      case 'note':
        return '건강 메모';
      default:
        return '기록';
    }
  }

  String get _typeEmoji {
    switch (widget.type) {
      case 'weight':
        return '⚖️';
      case 'health':
        return '💉';
      case 'note':
        return '📝';
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

  Future<void> _save() async {
    if (_isWeight) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
        return;
      }
    } else {
      if (_notesController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내용을 입력해주세요')),
        );
        return;
      }
      setState(() => _saving = true);
      try {
        await _service.addRecord(
          petId: widget.pet.id,
          date: widget.date,
          type: widget.type,
          notes: _notesController.text.trim(),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
        return;
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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(_typeEmoji,
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
                      Text(
                        formatted,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (_isWeight) ...[
              const Text(
                '몸무게 (kg)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 15),
              ),
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
              const Text(
                '메모 (선택)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 15),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '추가로 기록할 내용이 있으면 적어주세요',
                  hintStyle:
                      const TextStyle(color: AppColors.textHint, fontSize: 14),
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
            ] else ...[
              Text(
                widget.type == 'health' ? '접종 내용' : '오늘의 기록',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 15),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 12,
                minLines: 8,
                autofocus: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: widget.type == 'health'
                      ? '예: 광견병 예방접종 1차'
                      : '오늘 ${widget.pet.name}의 상태는 어떤가요?',
                  hintStyle:
                      const TextStyle(color: AppColors.textHint, fontSize: 14),
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
            ],
          ],
        ),
      ),
    );
  }
}
