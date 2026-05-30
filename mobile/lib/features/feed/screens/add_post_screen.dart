import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../pet/models/pet_model.dart';
import '../services/post_service.dart';

class AddPostScreen extends StatefulWidget {
  final List<Pet> pets;
  const AddPostScreen({super.key, required this.pets});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _contentController = TextEditingController();
  final _postService = PostService();

  Pet? _selectedPet;
  File? _imageFile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.pets.isNotEmpty) _selectedPet = widget.pets.first;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _postService.addPost(
        petId: _selectedPet?.id,
        content: _contentController.text.trim(),
        imageFile: _imageFile,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('오류가 발생했어요: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('글쓰기'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : const Text('게시',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pet selector
              if (widget.pets.length > 1) ...[
                const Text('누구의 이야기인가요?',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.pets.map((pet) {
                      final selected = _selectedPet?.id == pet.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedPet = pet),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.primaryLight),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(pet.emoji),
                                const SizedBox(width: 6),
                                Text(
                                  pet.name,
                                  style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Content
              TextField(
                controller: _contentController,
                maxLines: 8,
                minLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText:
                      '${_selectedPet?.name ?? '아이'}의 오늘은 어땠나요? 🐾',
                  hintStyle:
                      const TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primaryLight)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primaryLight)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2)),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 8),

              // Image preview
              if (_imageFile != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _imageFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius:
                                  BorderRadius.circular(20)),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined,
                    color: AppColors.primary),
                label: Text(
                  _imageFile == null ? '사진 추가' : '사진 변경',
                  style: const TextStyle(color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryLight),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
