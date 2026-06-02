enum NotificationType { like, comment, follow }

class AppNotification {
  final String id;
  final NotificationType type;
  final String actorId;
  final String actorName;
  final String? actorAvatarUrl;
  final String? postId;
  final String? commentContent;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    this.actorAvatarUrl,
    this.postId,
    this.commentContent,
    required this.isRead,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        actorId: actorId,
        actorName: actorName,
        actorAvatarUrl: actorAvatarUrl,
        postId: postId,
        commentContent: commentContent,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
