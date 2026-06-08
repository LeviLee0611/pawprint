import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ── 기본 shimmer 래퍼 ─────────────────────────────────────

class _Shimmer extends StatelessWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEBE6),
      highlightColor: const Color(0xFFF7F5F2),
      child: child,
    );
  }
}

Widget _box({double? width, double? height, double radius = 8, EdgeInsets? margin}) {
  return Container(
    width: width,
    height: height,
    margin: margin,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

// ── 피드 게시글 스켈레톤 ──────────────────────────────────

class FeedPostSkeleton extends StatelessWidget {
  final bool showImage;
  const FeedPostSkeleton({super.key, this.showImage = true});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아바타
            _box(width: 40, height: 40, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름
                  _box(width: 100, height: 13),
                  const SizedBox(height: 8),
                  // 본문 1줄
                  _box(height: 13),
                  const SizedBox(height: 6),
                  _box(width: double.infinity * 0.75, height: 13),
                  if (showImage) ...[
                    const SizedBox(height: 10),
                    _box(height: 180, radius: 12),
                  ],
                  const SizedBox(height: 10),
                  // 액션 버튼
                  Row(
                    children: [
                      _box(width: 40, height: 12),
                      const SizedBox(width: 20),
                      _box(width: 40, height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const FeedPostSkeleton(showImage: true),
        const Divider(height: 1, color: Color(0xFFEDE8E3)),
        const FeedPostSkeleton(showImage: false),
        const Divider(height: 1, color: Color(0xFFEDE8E3)),
        const FeedPostSkeleton(showImage: true),
        const Divider(height: 1, color: Color(0xFFEDE8E3)),
        const FeedPostSkeleton(showImage: false),
      ],
    );
  }
}

// ── 알림 스켈레톤 ─────────────────────────────────────────

class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Column(
        children: List.generate(6, (i) => _NotifRow()),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _box(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(height: 13),
                const SizedBox(height: 6),
                _box(width: 80, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _box(width: 18, height: 18, radius: 4),
        ],
      ),
    );
  }
}

// ── 검색 유저 스켈레톤 ────────────────────────────────────

class SearchUserSkeleton extends StatelessWidget {
  const SearchUserSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Column(
        children: List.generate(6, (i) => _UserRow()),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _box(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(child: _box(height: 14, width: 120)),
          _box(width: 76, height: 34, radius: 8),
        ],
      ),
    );
  }
}

// ── 프로필 그리드 스켈레톤 ────────────────────────────────

class ProfileGridSkeleton extends StatelessWidget {
  const ProfileGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 9,
          itemBuilder: (_, _) => _box(radius: 14),
        ),
      ),
    );
  }
}

// ── 프로필 배너 스켈레톤 ──────────────────────────────────

class ProfileBannerSkeleton extends StatelessWidget {
  const ProfileBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF0DC), Color(0xFFFFFAF5)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  _box(width: 80, height: 80, radius: 40),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatSkeleton(),
                        _StatSkeleton(),
                        _StatSkeleton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _box(width: 100, height: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _box(width: 36, height: 18),
        const SizedBox(height: 4),
        _box(width: 28, height: 12),
      ],
    );
  }
}
