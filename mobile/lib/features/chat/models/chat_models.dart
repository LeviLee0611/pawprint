class ChatRoom {
  final String id;
  final String postId;
  final String authorId;
  final String helperId;
  final DateTime lastMessageAt;
  final String? postTitle;
  final String? postCategory;
  final String? authorName;
  final String? helperName;
  final String? authorAvatar;
  final String? helperAvatar;

  const ChatRoom({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.helperId,
    required this.lastMessageAt,
    this.postTitle,
    this.postCategory,
    this.authorName,
    this.helperName,
    this.authorAvatar,
    this.helperAvatar,
  });

  String otherName(String myId) =>
      myId == authorId ? (helperName ?? '사용자') : (authorName ?? '사용자');

  String? otherAvatar(String myId) =>
      myId == authorId ? helperAvatar : authorAvatar;

  String otherId(String myId) => myId == authorId ? helperId : authorId;

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        authorId: json['author_id'] as String,
        helperId: json['helper_id'] as String,
        lastMessageAt: DateTime.parse(json['last_message_at'] as String),
        postTitle: json['post_title'] as String?,
        postCategory: json['post_category'] as String?,
        authorName: json['author_name'] as String?,
        helperName: json['helper_name'] as String?,
        authorAvatar: json['author_avatar'] as String?,
        helperAvatar: json['helper_avatar'] as String?,
      );
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        roomId: json['room_id'] as String,
        senderId: json['sender_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
