import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  final _supabase = Supabase.instance.client;

  Future<List<AppNotification>> getNotifications() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    // 1. 알림 기본 데이터
    final raw = await _supabase
        .from('notifications')
        .select('*')
        .eq('recipient_id', myId)
        .order('created_at', ascending: false)
        .limit(50);

    final items = raw as List;
    if (items.isEmpty) return [];

    // 2. actor 프로필 일괄 조회
    final actorIds =
        items.map((e) => e['actor_id'] as String).toSet().toList();
    final profileMap = <String, Map<String, dynamic>>{};
    try {
      final profileData = await _supabase
          .from('profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', actorIds);
      for (final p in profileData as List) {
        profileMap[p['id'] as String] = p as Map<String, dynamic>;
      }
    } catch (_) {}

    // 3. 댓글 내용 일괄 조회
    final commentIds = items
        .where((e) => e['comment_id'] != null)
        .map((e) => e['comment_id'] as String)
        .toList();
    final commentMap = <String, String>{};
    if (commentIds.isNotEmpty) {
      try {
        final commentData = await _supabase
            .from('comments')
            .select('id, content')
            .inFilter('id', commentIds);
        for (final c in commentData as List) {
          commentMap[c['id'] as String] = c['content'] as String;
        }
      } catch (_) {}
    }

    return items.map((e) {
      final actorId = e['actor_id'] as String;
      final profile = profileMap[actorId];
      final commentId = e['comment_id'] as String?;
      return AppNotification(
        id: e['id'] as String,
        type: _parseType(e['type'] as String),
        actorId: actorId,
        actorName: profile?['display_name'] as String? ?? '사용자',
        actorAvatarUrl: profile?['avatar_url'] as String?,
        postId: e['post_id'] as String?,
        commentContent: commentId != null ? commentMap[commentId] : null,
        isRead: e['read_at'] != null,
        createdAt: DateTime.parse(e['created_at'] as String),
      );
    }).toList();
  }

  Future<int> getUnreadCount() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return 0;
    final result = await _supabase
        .from('notifications')
        .select('id')
        .eq('recipient_id', myId)
        .isFilter('read_at', null)
        .count(CountOption.exact);
    return result.count;
  }

  Future<void> markAllRead() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('recipient_id', myId)
        .isFilter('read_at', null);
  }

  static NotificationType _parseType(String s) => switch (s) {
        'like' => NotificationType.like,
        'comment' => NotificationType.comment,
        _ => NotificationType.follow,
      };
}
