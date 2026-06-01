import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;

  static bool _initialized = false;

  // App이 등록하는 콜백 — 알림 탭 시 캘린더로 이동
  static VoidCallback? onNotificationTap;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _saveToken();
    }

    _messaging.onTokenRefresh.listen(_updateToken);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 앱이 백그라운드일 때 알림 탭
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      onNotificationTap?.call();
    });

    // 앱이 종료된 상태에서 알림 탭으로 실행
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      onNotificationTap?.call();
    }
  }

  static Future<void> _saveToken() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await _updateToken(token);
  }

  static Future<void> _updateToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('fcm_tokens').upsert({
        'owner_id': userId,
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('fcm_tokens')
          .delete()
          .eq('owner_id', userId);
      await _messaging.deleteToken();
    } catch (_) {}
    _initialized = false;
  }
}
