class Post {
  final String id;
  final String ownerId;
  final String? petId;
  final String content;
  final String? imageUrl;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final DateTime createdAt;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? petName;
  final String? petType;

  const Post({
    required this.id,
    required this.ownerId,
    this.petId,
    required this.content,
    this.imageUrl,
    required this.likesCount,
    required this.commentsCount,
    this.isLikedByMe = false,
    required this.createdAt,
    this.ownerName,
    this.ownerAvatarUrl,
    this.petName,
    this.petType,
  });

  factory Post.fromJson(Map<String, dynamic> json,
      {bool isLikedByMe = false}) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final pet = json['pets'] as Map<String, dynamic>?;
    return Post(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      petId: json['pet_id'] as String?,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      likesCount: (json['likes_count'] as int?) ?? 0,
      commentsCount: (json['comments_count'] as int?) ?? 0,
      isLikedByMe: isLikedByMe,
      createdAt: DateTime.parse(json['created_at'] as String),
      ownerName: profile?['display_name'] as String?,
      ownerAvatarUrl: profile?['avatar_url'] as String?,
      petName: pet?['name'] as String?,
      petType: pet?['type'] as String?,
    );
  }

  Post copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
    String? ownerName,
    String? ownerAvatarUrl,
    String? petName,
    String? petType,
  }) =>
      Post(
        id: id,
        ownerId: ownerId,
        petId: petId,
        content: content,
        imageUrl: imageUrl,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
        createdAt: createdAt,
        ownerName: ownerName ?? this.ownerName,
        ownerAvatarUrl: ownerAvatarUrl ?? this.ownerAvatarUrl,
        petName: petName ?? this.petName,
        petType: petType ?? this.petType,
      );
}

class Comment {
  final String id;
  final String postId;
  final String ownerId;
  final String content;
  final DateTime createdAt;
  final String? ownerName;
  final String? ownerAvatarUrl;

  const Comment({
    required this.id,
    required this.postId,
    required this.ownerId,
    required this.content,
    required this.createdAt,
    this.ownerName,
    this.ownerAvatarUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      ownerId: json['owner_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      ownerName: profile?['display_name'] as String?,
      ownerAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
