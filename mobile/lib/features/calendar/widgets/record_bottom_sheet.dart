import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class RecordBottomSheet extends StatelessWidget {
  final DateTime date;

  const RecordBottomSheet({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.brownLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(formatted,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('어떤 기록을 남길까요?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _RecordOption(
              icon: Icons.photo_camera_rounded,
              label: '사진 / 동영상',
              description: '오늘의 순간을 남겨요',
              color: AppColors.primary,
              bgColor: AppColors.primaryLight,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('사진 기록은 곧 추가될 예정이에요 🐾'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            _RecordOption(
              icon: Icons.vaccines_rounded,
              label: '예방접종',
              description: '접종 기록을 관리해요',
              color: AppColors.green,
              bgColor: AppColors.greenLight,
              onTap: () => Navigator.pop(context, 'health'),
            ),
            _RecordOption(
              icon: Icons.monitor_weight_rounded,
              label: '몸무게 기록',
              description: '체중 변화를 체크해요',
              color: AppColors.brown,
              bgColor: AppColors.brownLight,
              onTap: () => Navigator.pop(context, 'weight'),
            ),
            _RecordOption(
              icon: Icons.favorite_rounded,
              label: '건강 메모',
              description: '특이사항이나 메모를 남겨요',
              color: AppColors.peach,
              bgColor: AppColors.peachLight,
              onTap: () => Navigator.pop(context, 'note'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _RecordOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 15)),
                    Text(description,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
