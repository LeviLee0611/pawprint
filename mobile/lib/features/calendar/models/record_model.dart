class Record {
  final String id;
  final String? petId; // null = 공통 기록 (특정 펫 없음)
  final String ownerId;
  final DateTime date;
  final String type;
  final String? notes;
  final double? value;
  final String? photoUrl;
  final DateTime createdAt;

  const Record({
    required this.id,
    this.petId,
    required this.ownerId,
    required this.date,
    required this.type,
    this.notes,
    this.value,
    this.photoUrl,
    required this.createdAt,
  });

  factory Record.fromJson(Map<String, dynamic> json) => Record(
        id: json['id'] as String,
        petId: json['pet_id'] as String?,
        ownerId: json['owner_id'] as String,
        date: DateTime.parse(json['date'] as String),
        type: json['type'] as String,
        notes: json['notes'] as String?,
        value: json['value'] != null ? (json['value'] as num).toDouble() : null,
        photoUrl: json['photo_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get label {
    switch (type) {
      case 'meal':
        return '식사';
      case 'weight':
        return '몸무게';
      case 'health':
        return '예방접종';
      case 'grooming':
        return '그루밍';
      case 'play':
        return '놀이';
      case 'bath':
        return '목욕';
      case 'note':
        return '건강 메모';
      case 'photo':
        return '사진 기록';
      default:
        return type;
    }
  }

  static const _activityEmojis = {
    '빗질': '🪮',
    '목욕': '🛁',
    '전체 목욕': '🛁',
    '발톱 정리': '✂️',
    '귀 청소': '👂',
    '양치': '🦷',
    '구충제': '💊',
    '전체 구충제': '💊',
    '병원 방문': '🏥',
    '미용': '🎀',
    '모래 교체': '🪣',
    '화장실 청소': '🚿',
    '집 청소': '🧹',
    '용품 보충': '🛒',
  };

  String get emoji {
    switch (type) {
      case 'meal':
        return '🍖';
      case 'weight':
        return '📊';
      case 'health':
        return '💉';
      case 'grooming':
        return '✂️';
      case 'play':
        return '🎾';
      case 'bath':
        return '🛁';
      case 'photo':
        return '📷';
      case 'note':
        if (notes != null) {
          final firstLine = notes!.split('\n').first;
          for (final entry in _activityEmojis.entries) {
            if (firstLine.contains(entry.key)) return entry.value;
          }
        }
        return '📝';
      default:
        return '📋';
    }
  }
}
