import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../../feed/screens/post_detail_screen.dart';
import '../../feed/services/post_service.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../models/app_notification.dart';
import '../services/notification_repository.dart';
import 'notification_settings_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _repo = NotificationRepository();
  final _postService = PostService();

  List<AppNotification> _notifications = [];
  bool _loading = true;
  bool _hasError = false;
  String? _navigatingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final result = await _repo.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = result);
      // 읽음 처리 후 로컬 상태도 즉시 갱신
      await _repo.markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications =
            _notifications.map((n) => n.copyWith(isRead: true)).toList();
      });
    } catch (e) {
      debugPrint('notification load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTap(AppNotification n) async {
    if (n.type == NotificationType.follow) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            userId: n.actorId,
            initialName: n.actorName,
            initialAvatarUrl: n.actorAvatarUrl,
          ),
        ),
      );
      return;
    }

    if (n.postId == null) return;
    setState(() => _navigatingId = n.id);
    try {
      final post = await _postService.getPostById(n.postId!);
      if (!mounted) return;
      if (post == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제된 게시글이에요')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글을 불러오지 못했어요')),
        );
      }
    } finally {
      if (mounted) setState(() => _navigatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('알림'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const NotificationSkeleton()
          : _hasError
              ? _buildError()
              : _notifications.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: Color(0xFFEDE8E3),
                            indent: 72),
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return _NotificationTile(
                            notification: n,
                            isNavigating: _navigatingId == n.id,
                            onTap: () => _onTap(n),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return GestureDetector(
      onTap: _load,
      child: Center(
        child: Image.asset('assets/images/알림없음.png', width: 320),
      ),
    );
  }

  Widget _buildError() {
    return GestureDetector(
      onTap: _load,
      child: Center(
        child: Image.asset('assets/images/서버이슈_투명.png', width: 320),
      ),
    );
  }
}

// ── 알림 타일 ────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isNavigating;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.isNavigating,
    required this.onTap,
  });

  String _message() {
    switch (notification.type) {
      case NotificationType.like:
        return '${notification.actorName}님이 게시글을 좋아합니다 ❤️';
      case NotificationType.comment:
        final preview = notification.commentContent;
        if (preview != null && preview.isNotEmpty) {
          final short = preview.length > 30
              ? '${preview.substring(0, 30)}…'
              : preview;
          return '${notification.actorName}님이 댓글을 달았어요\n"$short"';
        }
        return '${notification.actorName}님이 댓글을 달았어요';
      case NotificationType.follow:
        return '${notification.actorName}님이 팔로우했어요';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일', 'ko').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final url = notification.actorAvatarUrl;
    final unread = !notification.isRead;

    return InkWell(
      onTap: isNavigating ? null : onTap,
      splashColor: AppColors.primaryLight.withValues(alpha: 0.3),
      child: Container(
        color: unread
            ? AppColors.primaryLight.withValues(alpha: 0.25)
            : Colors.transparent,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아바타
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: url != null ? NetworkImage(url) : null,
              child: url == null
                  ? ClipOval(
                      child: Image.asset(
                        'assets/images/앱로고.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _message(),
                    style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                        fontWeight: unread
                            ? FontWeight.w600
                            : FontWeight.normal,
                        height: 1.45),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            isNavigating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : _typeIcon(),
          ],
        ),
      ),
    );
  }

  Widget _typeIcon() {
    switch (notification.type) {
      case NotificationType.like:
        return const Icon(Icons.favorite_rounded,
            size: 18, color: Color(0xFFE53935));
      case NotificationType.comment:
        return const Icon(Icons.chat_bubble_rounded,
            size: 18, color: AppColors.primary);
      case NotificationType.follow:
        return const Icon(Icons.person_add_rounded,
            size: 18, color: AppColors.primary);
    }
  }
}
