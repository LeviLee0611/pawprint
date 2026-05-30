class Record {
  final String id;
  final String petId;
  final String ownerId;
  final DateTime date;
  final String type;
  final String? notes;
  final double? value;
  final DateTime createdAt;

  const Record({
    required this.id,
    required this.petId,
    required this.ownerId,
    required this.date,
    required this.type,
    this.notes,
    this.value,
    required this.createdAt,
  });

  factory Record.fromJson(Map<String, dynamic> json) => Record(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        ownerId: json['owner_id'] as String,
        date: DateTime.parse(json['date'] as String),
        type: json['type'] as String,
        notes: json['notes'] as String?,
        value: json['value'] != null ? (json['value'] as num).toDouble() : null,
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
      case 'note':
        return '건강 메모';
      default:
        return type;
    }
  }

  String get emoji {
    switch (type) {
      case 'meal':
        return '🍖';
      case 'weight':
        return '⚖️';
      case 'health':
        return '💉';
      case 'grooming':
        return '✂️';
      case 'play':
        return '🎾';
      case 'note':
        return '📝';
      default:
        return '📋';
    }
  }
}
