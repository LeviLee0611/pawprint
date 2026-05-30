import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/pet_model.dart';
import '../screens/add_pet_screen.dart';
import '../services/pet_service.dart';

class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  final _petService = PetService();
  List<Pet> _pets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() => _loading = true);
    final pets = await _petService.getMyPets();
    if (!mounted) return;
    setState(() {
      _pets = pets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 펫')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadPets,
              color: AppColors.primary,
              child: _pets.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _pets.length,
                      itemBuilder: (context, index) =>
                          _PetCard(pet: _pets[index]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPetScreen()),
          );
          await _loadPets();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('펫 추가', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Column(
          children: [
            Text('🐾', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              '아직 등록된 아이가 없어요',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              '아래 버튼으로 첫 번째 아이를 등록해보세요',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;

  const _PetCard({required this.pet});

  String _ageString(DateTime? birthday) {
    if (birthday == null) return '';
    final now = DateTime.now();
    final months =
        (now.year - birthday.year) * 12 + (now.month - birthday.month);
    if (months < 1) return '1개월 미만';
    if (months < 12) return '$months개월';
    final years = months ~/ 12;
    final remainMonths = months % 12;
    if (remainMonths == 0) return '$years살';
    return '$years살 $remainMonths개월';
  }

  String _genderLabel(String? gender) {
    switch (gender) {
      case 'male':
        return '수컷';
      case 'female':
        return '암컷';
      case 'neutered':
        return '중성화';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = pet.type == 'cat' ? '고양이' : '강아지';
    final subtitleParts = [
      typeLabel,
      if (pet.breed != null && pet.breed!.isNotEmpty) pet.breed!,
    ];
    final ageStr = _ageString(pet.birthday);
    final genderStr = _genderLabel(pet.gender);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pet.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(pet.emoji,
                          style: const TextStyle(fontSize: 17)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleParts.join(' · '),
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (ageStr.isNotEmpty) ...[
                        _InfoChip(
                            label: ageStr, color: AppColors.primary),
                        const SizedBox(width: 6),
                      ],
                      if (genderStr.isNotEmpty)
                        _InfoChip(
                            label: genderStr, color: AppColors.brown),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    const size = 76.0;
    if (pet.profileImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          pet.profileImageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _emojiAvatar(size),
        ),
      );
    }
    return _emojiAvatar(size);
  }

  Widget _emojiAvatar(double size) {
    final bgColor =
        pet.type == 'cat' ? AppColors.primaryLight : AppColors.brownLight;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(pet.emoji, style: const TextStyle(fontSize: 38)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
