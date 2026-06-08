import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_util.dart';

/// 내 피드 / 유저 프로필 공통 헤더 배너
class ProfileBanner extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final Widget statsRow;
  final Widget? actionButton;
  final Widget? petsRow;

  const ProfileBanner({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.statsRow,
    this.actionButton,
    this.petsRow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFF0DC),
                Color(0xFFFFFAF5),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아바타 + 통계
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(toTransformUrl(avatarUrl,
                                width: 160, height: 160, quality: 85, resize: 'cover'))
                            : null,
                        child: avatarUrl == null
                            ? ClipOval(
                                child: Image.asset(
                                  'assets/images/포포얼굴사진.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: statsRow),
                  ],
                ),
              ),
              // 닉네임 + 팔로우 버튼 + 펫 목록 (그라데이션 영역 안으로 포함)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary)),
                    if (actionButton != null) ...[
                      const SizedBox(height: 10),
                      actionButton!,
                    ],
                    if (petsRow != null) ...[
                      const SizedBox(height: 12),
                      petsRow!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
