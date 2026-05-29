import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.pawprint.mobile://login-callback/',
    );
  }

  Future<void> signInWithKakao() async {
    OAuthToken token;

    if (await isKakaoTalkInstalled()) {
      token = await UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }

    final idToken = token.idToken;
    if (idToken == null) throw Exception('카카오 ID 토큰을 가져올 수 없어요');

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.kakao,
      idToken: idToken,
      accessToken: token.accessToken,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
