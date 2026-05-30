import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../features/calendar/screens/records_history_screen.dart';
import '../../../features/calendar/services/record_service.dart';
import '../../../features/pet/screens/pet_screen.dart';
import '../../../features/pet/services/pet_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _petService = PetService();
  final _recordService = RecordService();

  int _petCount = 0;
  int _recordCount = 0;
  bool _notificationsEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _petService.getMyPets(),
      _recordService.getTotalRecordCount(),
      SharedPreferences.getInstance(),
    ]);

    if (!mounted) return;
    final pets = results[0] as List;
    final recordCount = results[1] as int;
    final prefs = results[2] as SharedPreferences;

    setState(() {
      _petCount = pets.length;
      _recordCount = recordCount;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _loading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _signOut() async {
    final ok = await _showConfirmDialog(
      title: '로그아웃',
      content: '로그아웃 하시겠어요?',
      confirmLabel: '로그아웃',
      confirmColor: AppColors.primary,
    );
    if (ok != true) return;
    await _authService.signOut();
  }

  Future<void> _deleteAccount() async {
    final ok = await _showConfirmDialog(
      title: '정말 탈퇴하시겠어요?',
      content:
          '탈퇴하면 등록된 펫, 기록, 게시글이 모두 영구 삭제되며\n복구할 수 없어요.',
      confirmLabel: '탈퇴하기',
      confirmColor: Colors.red,
    );
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        // profiles 삭제 → pets, records 자동 cascade
        await supabase.from('profiles').delete().eq('id', userId);
      }
      await _authService.signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했어요: $e')),
      );
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          content: Text(content,
              style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel,
                  style: TextStyle(
                      color: confirmColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

  void _showTextDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: Text(content,
              style: const TextStyle(
                  color: AppColors.textSecondary, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final name = (user?.userMetadata?['full_name'] ??
            user?.userMetadata?['name'] ??
            '이름 없음') as String;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    currentName: name,
                    currentAvatarUrl: avatarUrl,
                  ),
                ),
              );
              if (updated == true && mounted) _loadData();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── 유저 정보 ──────────────────────────────
          _buildUserHeader(avatarUrl, name, email),

          // ── 통계 ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const PetScreen())),
                    child: _StatCard(
                        emoji: '🐾',
                        value: '$_petCount마리',
                        label: '등록한 펫'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const RecordsHistoryScreen())),
                    child: _StatCard(
                        emoji: '📝',
                        value: '$_recordCount개',
                        label: '총 기록'),
                  ),
                ),
              ],
            ),
          ),

          // ── 설정 ──────────────────────────────────
          _sectionLabel('설정'),
          _switchTile(
            icon: Icons.notifications_outlined,
            label: '알림',
            subtitle: '일일 기록 알림을 받아요',
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
          ),

          // ── 정보 ──────────────────────────────────
          _sectionLabel('정보'),
          _navTile(
            icon: Icons.description_outlined,
            label: '이용약관',
            onTap: () => _showTextDialog('이용약관', _kTerms),
          ),
          _navTile(
            icon: Icons.shield_outlined,
            label: '개인정보처리방침',
            onTap: () => _showTextDialog('개인정보처리방침', _kPrivacy),
          ),
          _navTile(
            icon: Icons.info_outline,
            label: '앱 버전',
            trailing:
                const Text('1.0.0', style: TextStyle(color: AppColors.textHint)),
          ),

          // ── 계정 ──────────────────────────────────
          _sectionLabel('계정'),
          _navTile(
            icon: Icons.logout_rounded,
            label: '로그아웃',
            onTap: _signOut,
          ),
          _navTile(
            icon: Icons.person_remove_outlined,
            label: '회원탈퇴',
            labelColor: Colors.red,
            iconColor: Colors.red,
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }

  // ── 유저 헤더 ─────────────────────────────────────
  Widget _buildUserHeader(String? avatarUrl, String name, String email) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primaryLight,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, size: 36, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 섹션 레이블 ───────────────────────────────────
  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint,
                letterSpacing: 0.6)),
      );

  // ── 스위치 타일 ───────────────────────────────────
  Widget _switchTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      _tileWrapper(
        child: ListTile(
          leading:
              Icon(icon, color: AppColors.primary, size: 22),
          title: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
          subtitle: Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textHint)),
          trailing: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ),
      );

  // ── 네비 타일 ─────────────────────────────────────
  Widget _navTile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
    Color? labelColor,
    Color? iconColor,
  }) =>
      _tileWrapper(
        child: ListTile(
          leading: Icon(icon,
              color: iconColor ?? AppColors.textSecondary, size: 22),
          title: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? AppColors.textPrimary)),
          trailing: trailing ??
              (onTap != null
                  ? const Icon(Icons.chevron_right,
                      color: AppColors.textHint)
                  : null),
          onTap: onTap,
        ),
      );

  Widget _tileWrapper({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: child,
        ),
      );
}

// ── 통계 카드 ─────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatCard(
      {required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── 약관 내용 ─────────────────────────────────────────
const _kTerms = '''
이용약관

포포와 토토 앱을 이용해 주셔서 감사합니다.

제1조 (목적)
본 약관은 포포와 토토(이하 "앱")가 제공하는 서비스의 이용 조건 및 절차를 규정합니다.

제2조 (서비스 이용)
이 앱을 통해 반려동물의 건강 기록과 일상을 기록·관리할 수 있습니다. 서비스는 개인 용도로만 사용해야 하며, 타인의 권리를 침해하는 용도로 사용할 수 없습니다.

제3조 (계정)
소셜 로그인(Google, 카카오)을 통해 계정을 생성할 수 있습니다. 계정 정보 보안은 사용자 본인이 책임집니다.

제4조 (개인정보)
앱은 서비스 제공에 필요한 최소한의 개인정보를 수집하며, 개인정보처리방침에 따라 관리합니다.

제5조 (서비스 변경 및 종료)
앱은 사전 공지 후 서비스 내용을 변경하거나 종료할 수 있습니다.

버전 1.0.0 | 시행일: 2026-05-30
''';

const _kPrivacy = '''
개인정보처리방침

포포와 토토는 사용자의 개인정보를 소중히 여깁니다.

수집 항목
• 소셜 로그인 정보 (이름, 이메일, 프로필 사진)
• 반려동물 정보 (이름, 종류, 사진, 생년월일)
• 건강 및 일상 기록 데이터

수집 목적
• 서비스 제공 및 개인화
• 펫 기록 관리 기능 제공

보관 기간
• 서비스 이용 기간 동안 보관
• 회원탈퇴 시 즉시 삭제

제3자 제공
• 사용자 동의 없이 개인정보를 제3자에게 제공하지 않습니다.

사용자 권리
• 언제든지 개인정보 조회, 수정, 삭제를 요청할 수 있습니다.
• 문의: dlrbqls5126@gmail.com

버전 1.0.0 | 시행일: 2026-05-30
''';
