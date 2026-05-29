class Pet {
  final String id;
  final String ownerId;
  final String name;
  final String type; // 'cat' | 'dog'
  final String? gender;
  final DateTime? birthday;
  final String? breed;
  final String? profileImageUrl;

  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    this.gender,
    this.birthday,
    this.breed,
    this.profileImageUrl,
  });

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    name: json['name'] as String,
    type: json['type'] as String? ?? 'cat',
    gender: json['gender'] as String?,
    birthday: json['birth_date'] != null ? DateTime.parse(json['birth_date'] as String) : null,
    breed: json['breed'] as String?,
    profileImageUrl: json['photo_url'] as String?,
  );

  String get emoji => type == 'dog' ? '🐶' : '🐱';
}
