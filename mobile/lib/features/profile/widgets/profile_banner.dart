import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

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
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 20),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 아바타
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
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
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
        // 이름 + 팔로우 버튼 + 펫 목록
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              const SizedBox(height: 14),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
