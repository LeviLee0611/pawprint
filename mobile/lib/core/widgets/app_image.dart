import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/image_util.dart';

/// 피드 게시글 이미지
class AppPostImage extends StatelessWidget {
  final String url;
  final double height;

  const AppPostImage({super.key, required this.url, this.height = 220});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, _) => const SizedBox(),
      ),
    );
  }
}

/// 아바타 원형 이미지 — 캐싱 + Transform(120px)
class AppAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final String fallbackAsset;

  const AppAvatar({
    super.key,
    this.url,
    required this.size,
    this.fallbackAsset = 'assets/images/앱로고.png',
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback();
    final transformUrl = toTransformUrl(url, width: 120, height: 120, quality: 85, resize: 'cover');
    return CachedNetworkImage(
      imageUrl: transformUrl,
      imageBuilder: (_, imageProvider) => CircleAvatar(
        radius: size / 2,
        backgroundImage: imageProvider,
      ),
      placeholder: (_, _) => _placeholder(),
      errorWidget: (context, error, _) => _fallback(),
    );
  }

  Widget _placeholder() => CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.primaryLight,
      );

  Widget _fallback() => CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.primaryLight,
        child: ClipOval(
          child: Image.asset(
            fallbackAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
}

/// 그리드 썸네일 — 캐싱 + Transform(400px)
class AppGridImage extends StatelessWidget {
  final String url;

  const AppGridImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final transformUrl = toTransformUrl(url, width: 400, quality: 75);
    return CachedNetworkImage(
      imageUrl: transformUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) =>
          Container(color: AppColors.primaryLight),
      errorWidget: (context, error, _) =>
          Container(color: AppColors.primaryLight),
    );
  }
}
