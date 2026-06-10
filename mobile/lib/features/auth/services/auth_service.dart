import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/notification_service.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.pawprint.mobile://login-callback/',
    );
  }

  Future<void> signInWithKakao() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      token = await UserApi.instance.loginWithKakaoTalk(nonce: hashedNonce);
    } else {
      token = await UserApi.instance.loginWithKakaoAccount(nonce: hashedNonce);
    }

    final idToken = token.idToken;
    if (idToken == null) throw Exception('카카오 ID 토큰을 가져올 수 없어요');

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.kakao,
      idToken: idToken,
      accessToken: token.accessToken,
      nonce: rawNonce,
    );
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  Future<void> signOut() async {
    await NotificationService.clearToken();
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
