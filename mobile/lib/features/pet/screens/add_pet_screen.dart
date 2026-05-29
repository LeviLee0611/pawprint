import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../services/pet_service.dart';

class AddPetScreen extends StatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onSkip;
  const AddPetScreen({super.key, this.isOnboarding = false, this.onSkip});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _petService = PetService();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();

  String _type = 'cat';
  String? _gender;
  DateTime? _birthday;
  File? _profileImage;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
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
      await _petService.addPet(
        name: _nameController.text.trim(),
        type: _type,
        gender: _gender,
        birthday: _birthday,
        breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
        profileImage: _profileImage,
      );

      if (mounted) {
        if (widget.isOnboarding) {
          widget.onSkip?.call(); // PetGate가 App()으로 전환
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했어요: $e'), backgroundColor: Colors.red),
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
      appBar: widget.isOnboarding
          ? AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              actions: [
                TextButton(
                  onPressed: () {
                    widget.onSkip?.call();
                  },
                  child: const Text('나중에', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            )
          : AppBar(title: const Text('펫 추가'), backgroundColor: AppColors.background),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isOnboarding) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/포포얼굴사진.png', height: 60),
                    const SizedBox(width: 12),
                    const Text(
                      '아이를\n소개해주세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.4),
                    ),
                    const SizedBox(width: 12),
                    Image.asset('assets/images/토토얼굴사진.png', height: 60),
                  ],
                ),
                const SizedBox(height: 24),
              ],

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
                            backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                            child: _profileImage == null
                                ? Text(_type == 'cat' ? '🐱' : '🐶', style: const TextStyle(fontSize: 40))
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
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _profileImage == null ? '아이의 프로필을 선택해주세요 🐾' : '사진을 바꾸려면 탭해봐요',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 종류 선택
              const Text('종류', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
              const Text('이름 *', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration('포포, 토토...'),
              ),
              const SizedBox(height: 20),

              // 성별
              const Text('성별', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ChipButton(label: '수컷', selected: _gender == 'male', onTap: () => setState(() => _gender = _gender == 'male' ? null : 'male')),
                  const SizedBox(width: 8),
                  _ChipButton(label: '암컷', selected: _gender == 'female', onTap: () => setState(() => _gender = _gender == 'female' ? null : 'female')),
                  const SizedBox(width: 8),
                  _ChipButton(label: '중성화', selected: _gender == 'neutered', onTap: () => setState(() => _gender = _gender == 'neutered' ? null : 'neutered')),
                ],
              ),
              const SizedBox(height: 20),

              // 생일
              const Text('생일', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickBirthday,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _birthday == null
                            ? '생일을 선택해주세요'
                            : '${_birthday!.year}년 ${_birthday!.month}월 ${_birthday!.day}일',
                        style: TextStyle(
                          color: _birthday == null ? AppColors.textHint : AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 품종
              const Text('품종', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('등록 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryLight)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryLight)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isCat;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({required this.label, required this.isCat, required this.selected, required this.onTap});

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
              color: selected ? AppColors.primary : AppColors.primaryLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Opacity(
                opacity: selected ? 1.0 : 0.4,
                child: Image.asset(
                  isCat ? 'assets/images/포포발자국.png' : 'assets/images/토토발자국.png',
                  height: 60,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
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

  const _ChipButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.primaryLight),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
