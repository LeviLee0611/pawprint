import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/pet/screens/add_pet_screen.dart';
import 'features/pet/services/pet_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await initializeDateFormatting('ko', null);

  runApp(const PawprintApp());
}

class PawprintApp extends StatefulWidget {
  const PawprintApp({super.key});

  @override
  State<PawprintApp> createState() => _PawprintAppState();
}

class _PawprintAppState extends State<PawprintApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    // 앱이 딥링크로 실행된 경우 (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await Supabase.instance.client.auth.getSessionFromUrl(initialUri);
      }
    } catch (_) {}

    // 앱 실행 중 딥링크 수신
    _deepLinkSub = _appLinks.uriLinkStream.listen((uri) {
      Supabase.instance.client.auth.getSessionFromUrl(uri);
    });
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '냥발도장',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('ko'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko')],
      home: const AuthGate(),
      // Flutter 라우터로 들어오는 OAuth 콜백 처리
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.contains('code=') || name.contains('access_token=')) {
          final callbackUri =
              Uri.parse('com.pawprint.mobile://login-callback$name');
          Supabase.instance.client.auth.getSessionFromUrl(callbackUri);
        }
        return MaterialPageRoute(builder: (_) => const AuthGate());
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginScreen();
        return const _PetGate();
      },
    );
  }
}

class _PetGate extends StatefulWidget {
  const _PetGate();

  // 세션 동안 스킵 여부 기억 (앱 재시작 전까지 유지)
  static bool skippedThisSession = false;

  @override
  State<_PetGate> createState() => _PetGateState();
}

class _PetGateState extends State<_PetGate> {
  final _petService = PetService();

  @override
  Widget build(BuildContext context) {
    if (_PetGate.skippedThisSession) return const App();

    return FutureBuilder(
      future: _petService.getMyPets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final pets = snapshot.data ?? [];
        if (pets.isEmpty) {
          return AddPetScreen(
            isOnboarding: true,
            onSkip: () => setState(() => _PetGate.skippedThisSession = true),
          );
        }
        return const App();
      },
    );
  }
}
