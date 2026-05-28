import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _loading = false;

  Future<void> _signIn(Future<void> Function() signInMethod) async {
    setState(() => _loading = true);
    try {
      await signInMethod();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (e.toString().contains('canceled') || e.toString().contains('cancelled')) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류가 발생했어요'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _loginButton({
    required String label,
    required Color color,
    required Color textColor,
    required Color borderColor,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: icon,
        label: Text(label, style: TextStyle(fontSize: 16, color: textColor)),
        style: OutlinedButton.styleFrom(
          backgroundColor: color,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🐾', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text(
                '냥발도장',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '우리 고양이의 하루를 기록해요',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 64),
              if (_loading)
                const CircularProgressIndicator(color: AppColors.primary)
              else ...[
                _loginButton(
                  label: 'Google로 계속하기',
                  color: Colors.white,
                  textColor: AppColors.textPrimary,
                  borderColor: AppColors.primaryLight,
                  icon: Image.network(
                    'https://developers.google.com/identity/images/g-logo.png',
                    height: 20,
                    errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 20),
                  ),
                  onTap: () => _signIn(_authService.signInWithGoogle),
                ),
                const SizedBox(height: 12),
                _loginButton(
                  label: '카카오로 계속하기',
                  color: const Color(0xFFFEE500),
                  textColor: const Color(0xFF191919),
                  borderColor: const Color(0xFFFEE500),
                  icon: const Icon(Icons.chat_bubble, size: 20, color: Color(0xFF191919)),
                  onTap: () => _signIn(_authService.signInWithKakao),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
