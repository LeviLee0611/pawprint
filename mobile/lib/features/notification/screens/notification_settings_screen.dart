import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/notification_settings_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _service = NotificationSettingsService();

  NotificationSettings _settings = const NotificationSettings();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _service.getSettings();
      if (mounted) setState(() => _settings = s);
    } catch (e) {
      debugPrint('notification settings load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(NotificationSettings updated) async {
    setState(() { _settings = updated; _saving = true; });
    try {
      await _service.saveSettings(updated);
    } catch (e) {
      debugPrint('notification settings save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('알림 설정'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              children: [
                const _SectionHeader(title: '알림 종류'),
                _SettingsTile(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFE53935),
                  title: '좋아요 알림',
                  subtitle: '내 게시글에 좋아요를 받으면 알려드려요',
                  value: _settings.likeEnabled,
                  onChanged: (v) =>
                      _update(_settings.copyWith(likeEnabled: v)),
                ),
                _SettingsTile(
                  icon: Icons.chat_bubble_rounded,
                  iconColor: AppColors.primary,
                  title: '댓글 알림',
                  subtitle: '내 게시글에 댓글이 달리면 알려드려요',
                  value: _settings.commentEnabled,
                  onChanged: (v) =>
                      _update(_settings.copyWith(commentEnabled: v)),
                ),
                _SettingsTile(
                  icon: Icons.person_add_rounded,
                  iconColor: AppColors.primary,
                  title: '팔로우 알림',
                  subtitle: '누군가 나를 팔로우하면 알려드려요',
                  value: _settings.followEnabled,
                  onChanged: (v) =>
                      _update(_settings.copyWith(followEnabled: v)),
                ),
                _SettingsTile(
                  icon: Icons.feed_rounded,
                  iconColor: const Color(0xFF43A047),
                  title: '새 게시글 알림',
                  subtitle: '팔로우한 사람이 글을 올리면 알려드려요',
                  value: _settings.newPostEnabled,
                  onChanged: (v) =>
                      _update(_settings.copyWith(newPostEnabled: v)),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
