class CommunityPost {
  final String id;
  final String ownerId;
  final String category; // 'lost' | 'found' | 'rehome' | 'looking'
  final String title;
  final String content;
  final List<String> imageUrls;
  final String? petName;
  final String? petType; // 'cat' | 'dog'
  final String? location;
  final String? contact;
  final String status; // 'open' | 'resolved' | 'hidden'
  final DateTime createdAt;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? address;
  final double? latitude;
  final double? longitude;

  const CommunityPost({
    required this.id,
    required this.ownerId,
    required this.category,
    required this.title,
    required this.content,
    required this.imageUrls,
    this.petName,
    this.petType,
    this.location,
    this.contact,
    required this.status,
    required this.createdAt,
    this.ownerName,
    this.ownerAvatarUrl,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final raw = json['image_urls'];
    final urls = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
    return CommunityPost(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      content: (json['content'] as String?) ?? '',
      imageUrls: urls,
      petName: json['pet_name'] as String?,
      petType: json['pet_type'] as String?,
      location: json['location'] as String?,
      contact: json['contact'] as String?,
      status: (json['status'] as String?) ?? 'open',
      createdAt: DateTime.parse(json['created_at'] as String),
      ownerName: profile?['display_name'] as String?,
      ownerAvatarUrl: profile?['avatar_url'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'lost': return '실종 신고';
      case 'found': return '발견 신고';
      case 'rehome': return '입양 보내기';
      case 'looking': return '입양 원해요';
      default: return category;
    }
  }

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved';
  bool get isHidden => status == 'hidden';
}
