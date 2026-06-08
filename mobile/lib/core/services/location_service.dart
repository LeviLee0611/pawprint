import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class LocationService {
  static const _askedKey = 'location_permission_asked';

  /// 온보딩 시 1회 선택 요청 (알림 권한과 동일하게 OS 다이얼로그 직접 표시)
  static Future<void> requestOnboardingIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) == true) return;
    await prefs.setBool(_askedKey, true);

    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.always ||
        current == LocationPermission.whileInUse) {
      return;
    }
    if (current == LocationPermission.deniedForever) { return; }

    await Geolocator.requestPermission();
  }

  /// 위치가 필요한 기능 진입 시 호출 — 권한 없으면 필수 안내 후 요청
  /// 허용됐으면 true 반환
  static Future<bool> ensurePermission(BuildContext context,
      {String reason = '이 기능은 위치 권한이 필요해요.'}) async {
    LocationPermission perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      return true;
    }

    if (!context.mounted) return false;

    if (perm == LocationPermission.deniedForever) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: const Text('위치 권한 필요',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('$reason\n\n설정에서 위치 권한을 허용해주세요.',
              style: const TextStyle(height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: const Text('설정 열기',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return false;
    }

    // denied → 이유 설명 후 요청
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('위치 권한 필요',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(reason, style: const TextStyle(height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('허용하기',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (ok != true) return false;
    perm = await Geolocator.requestPermission();
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// 현재 위치 반환 — 권한 없으면 null
  static Future<Position?> getCurrentPosition() async {
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium));
    } catch (_) {
      return null;
    }
  }
}
