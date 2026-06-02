import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppConfigResult {
  final bool needsUpdate;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final String storeUrl;

  const AppConfigResult({
    required this.needsUpdate,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.storeUrl,
  });
}

class ForceUpdateService {
  static Future<AppConfigResult> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final data = await Supabase.instance.client
          .from('app_config')
          .select('min_version, store_url_android, store_url_ios, maintenance_mode, maintenance_message')
          .eq('id', 1)
          .single();

      final minVersion = data['min_version'] as String? ?? '1.0.0';
      final maintenance = data['maintenance_mode'] as bool? ?? false;
      final maintenanceMsg = data['maintenance_message'] as String? ??
          '점검 중이에요. 잠시 후 다시 시도해주세요.';
      final storeUrl = Platform.isIOS
          ? (data['store_url_ios'] as String? ?? '')
          : (data['store_url_android'] as String? ?? '');

      return AppConfigResult(
        needsUpdate: _isOlderVersion(current, minVersion),
        maintenanceMode: maintenance,
        maintenanceMessage: maintenanceMsg,
        storeUrl: storeUrl,
      );
    } catch (_) {
      // 서버 오류 시 통과 (사용자 차단하지 않음)
      return const AppConfigResult(
        needsUpdate: false,
        maintenanceMode: false,
        maintenanceMessage: '',
        storeUrl: '',
      );
    }
  }

  // 현재 버전이 최소 버전보다 낮은지 비교 (예: 1.0.0 < 1.1.0)
  static bool _isOlderVersion(String current, String minimum) {
    final c = _parse(current);
    final m = _parse(minimum);
    for (int i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.');
    return List.generate(3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }

  static Future<void> openStore(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── 강제 업데이트 / 점검 다이얼로그 ────────────────────────

Future<void> showForceUpdateDialogIfNeeded(BuildContext context) async {
  final result = await ForceUpdateService.check();

  if (!context.mounted) return;

  if (result.maintenanceMode) {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MaintenanceDialog(message: result.maintenanceMessage),
    );
    return;
  }

  if (result.needsUpdate) {
    // storeUrl 없으면 사용자가 빠져나갈 방법이 없으므로 통과
    if (result.storeUrl.isEmpty) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(storeUrl: result.storeUrl),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  final String storeUrl;
  const _UpdateDialog({required this.storeUrl});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/새버전출시.png', width: 280),
            const SizedBox(height: 8),
            const Text('업데이트가 필요해요',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '더 나은 서비스를 위해\n새 버전으로 업데이트해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF8D6E63)),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => ForceUpdateService.openStore(storeUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9A3C),
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('업데이트하기',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceDialog extends StatelessWidget {
  final String message;
  const _MaintenanceDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/점검중.png', width: 280),
            const SizedBox(height: 8),
            const Text('점검 중이에요',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF8D6E63)),
            ),
          ],
        ),
      ),
    );
  }
}
