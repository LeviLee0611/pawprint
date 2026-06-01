import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../feed/services/follow_service.dart';
import 'user_profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers; // true = 팔로워, false = 팔로잉

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _followService = FollowService();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final users = widget.showFollowers
          ? await _followService.getFollowers(widget.userId)
          : await _followService.getFollowing(widget.userId);
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      debugPrint('FollowList load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showFollowers ? '팔로워' : '팔로잉'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 48, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      const Text('불러오지 못했어요',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: const Text('다시 시도',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                )
          : _users.isEmpty
              ? Center(
                  child: Text(
                    widget.showFollowers ? '아직 팔로워가 없어요' : '아직 팔로잉이 없어요',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFEDE8E3)),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final avatarUrl = user['avatar_url'] as String?;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? ClipOval(
                                child: Image.asset(
                                  'assets/images/포포얼굴사진.png',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        user['display_name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            userId: user['id'] as String,
                            initialName: user['display_name'] as String,
                            initialAvatarUrl: avatarUrl,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
