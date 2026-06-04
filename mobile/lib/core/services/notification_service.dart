import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _messageOpenedSub;

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

    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_updateToken);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 앱이 백그라운드일 때 알림 탭
    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((_) {
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
      await _supabase.from('fcm_tokens').upsert(
        {
          'owner_id': userId,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      debugPrint('FCM token upsert 실패: $e');
    }
  }

  static Future<void> clearToken() async {
    // DB 삭제와 FCM 삭제를 분리 — 한쪽 실패가 다른 작업을 막지 않도록
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _supabase.from('fcm_tokens').delete().eq('token', token);
      }
    } catch (e) {
      debugPrint('FCM DB 토큰 삭제 실패: $e');
    }

    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM 토큰 삭제 실패: $e');
    }

    await _tokenRefreshSub?.cancel();
    await _messageOpenedSub?.cancel();
    _tokenRefreshSub = null;
    _messageOpenedSub = null;
    _initialized = false;
  }
}
