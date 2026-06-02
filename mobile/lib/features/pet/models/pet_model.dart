class Pet {
  final String id;
  final String ownerId;
  final String name;
  final String type; // 'cat' | 'dog'
  final String? gender;
  final DateTime? birthday;
  final String? breed;
  final String? profileImageUrl;
  final bool isPublic;

  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    this.gender,
    this.birthday,
    this.breed,
    this.profileImageUrl,
    this.isPublic = true,
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
    isPublic: json['is_public'] as bool? ?? true,
  );

  Pet copyWith({bool? isPublic}) => Pet(
    id: id,
    ownerId: ownerId,
    name: name,
    type: type,
    gender: gender,
    birthday: birthday,
    breed: breed,
    profileImageUrl: profileImageUrl,
    isPublic: isPublic ?? this.isPublic,
  );

  String get emoji => type == 'dog' ? '🐶' : '🐱';
}
