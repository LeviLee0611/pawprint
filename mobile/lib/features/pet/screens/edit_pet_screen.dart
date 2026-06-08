import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../models/pet_model.dart';
import '../services/pet_service.dart';

class EditPetScreen extends StatefulWidget {
  final Pet pet;
  const EditPetScreen({super.key, required this.pet});

  @override
  State<EditPetScreen> createState() => _EditPetScreenState();
}

class _EditPetScreenState extends State<EditPetScreen> {
  final _petService = PetService();
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;

  late String _type;
  late bool _isMale;
  late bool _isFemale;
  late bool _isNeutered;
  late DateTime? _birthday;

  String? get _genderValue {
    if (_isMale && _isNeutered) return 'male_neutered';
    if (_isFemale && _isNeutered) return 'female_neutered';
    if (_isMale) return 'male';
    if (_isFemale) return 'female';
    if (_isNeutered) return 'neutered';
    return null;
  }
  File? _newProfileImage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _breedController = TextEditingController(text: widget.pet.breed ?? '');
    _type = widget.pet.type;
    final g = widget.pet.gender;
    _isMale = g == 'male' || g == 'male_neutered';
    _isFemale = g == 'female' || g == 'female_neutered';
    _isNeutered = g == 'neutered' || g == 'male_neutered' || g == 'female_neutered';
    _birthday = widget.pet.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _newProfileImage = File(picked.path));
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _petService.updatePet(
        petId: widget.pet.id,
        name: _nameController.text.trim(),
        type: _type,
        gender: _genderValue,
        birthday: _birthday,
        breed: _breedController.text.trim().isEmpty
            ? null
            : _breedController.text.trim(),
        newProfileImage: _newProfileImage,
        existingPhotoUrl: widget.pet.profileImageUrl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('오류가 발생했어요: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.pet.emoji} ${widget.pet.name} 수정'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 사진
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: _newProfileImage != null
                                ? FileImage(_newProfileImage!)
                                    as ImageProvider
                                : (widget.pet.profileImageUrl != null
                                    ? NetworkImage(
                                        widget.pet.profileImageUrl!)
                                    : null),
                            child: (_newProfileImage == null &&
                                    widget.pet.profileImageUrl == null)
                                ? Text(
                                    _type == 'cat' ? '🐱' : '🐶',
                                    style: const TextStyle(fontSize: 40),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '탭해서 사진 바꾸기',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 종류
              const Text('종류',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeButton(
                    label: '고양이',
                    isCat: true,
                    selected: _type == 'cat',
                    onTap: () => setState(() => _type = 'cat'),
                  ),
                  const SizedBox(width: 12),
                  _TypeButton(
                    label: '강아지',
                    isCat: false,
                    selected: _type == 'dog',
                    onTap: () => setState(() => _type = 'dog'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 이름
              const Text('이름 *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration('포포, 토토...'),
              ),
              const SizedBox(height: 20),

              // 성별
              const Text('성별',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ChipButton(
                    label: '수컷',
                    selected: _isMale,
                    onTap: () => setState(() {
                      if (_isFemale) _isFemale = false;
                      _isMale = !_isMale;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _ChipButton(
                    label: '암컷',
                    selected: _isFemale,
                    onTap: () => setState(() {
                      if (_isMale) _isMale = false;
                      _isFemale = !_isFemale;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _ChipButton(
                    label: '중성화',
                    selected: _isNeutered,
                    onTap: () => setState(() => _isNeutered = !_isNeutered),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 생일
              const Text('생일',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickBirthday,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_outlined,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _birthday == null
                            ? '생일을 선택해주세요'
                            : '${_birthday!.year}년 ${_birthday!.month}월 ${_birthday!.day}일',
                        style: TextStyle(
                          color: _birthday == null
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 품종
              const Text('품종',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _breedController,
                decoration: _inputDecoration('코리안 숏헤어, 말티즈...'),
              ),
              const SizedBox(height: 36),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : const Text('저장',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isCat;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton(
      {required this.label,
      required this.isCat,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? AppColors.primary : AppColors.primaryLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Opacity(
                opacity: selected ? 1.0 : 0.4,
                child: Image.asset(
                  isCat
                      ? 'assets/images/포포발자국.png'
                      : 'assets/images/토토발자국.png',
                  height: 60,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipButton(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.primaryLight),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected
                  ? Colors.white
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
