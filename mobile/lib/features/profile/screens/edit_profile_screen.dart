import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String? currentAvatarUrl;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    this.currentAvatarUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  final _profileService = ProfileService();
  File? _newPhoto;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _newPhoto = File(picked.path));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _profileService.updateProfile(
          name: name, photoFile: _newPhoto);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 업데이트됐어요 🐾')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.currentAvatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : const Text('저장',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Avatar
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: _newPhoto != null
                          ? FileImage(_newPhoto!) as ImageProvider
                          : (avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null),
                      child: (_newPhoto == null && avatarUrl == null)
                          ? const Icon(Icons.person,
                              size: 48, color: AppColors.primary)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
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
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('사진을 탭해서 변경',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textHint)),
            ),
            const SizedBox(height: 32),

            // Name
            const Text('닉네임',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: '이름을 입력하세요',
                hintStyle:
                    const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryLight)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryLight)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
