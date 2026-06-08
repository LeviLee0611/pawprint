class SightingReport {
  final String id;
  final String postId;
  final String reporterId;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? note;
  final DateTime createdAt;
  final String? reporterName;
  final String? reporterAvatarUrl;

  const SightingReport({
    required this.id,
    required this.postId,
    required this.reporterId,
    this.address,
    this.latitude,
    this.longitude,
    this.note,
    required this.createdAt,
    this.reporterName,
    this.reporterAvatarUrl,
  });

  factory SightingReport.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return SightingReport(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      reporterId: json['reporter_id'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reporterName: profile?['display_name'] as String?,
      reporterAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
