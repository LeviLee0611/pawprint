import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _contentController;
  final _postService = PostService();

  File? _newImageFile;
  bool _removeImage = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _contentController =
        TextEditingController(text: widget.post.content);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  String? get _currentImageUrl =>
      _removeImage ? null : widget.post.imageUrl;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _newImageFile = File(picked.path);
        _removeImage = false;
      });
    }
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
      final updated = await _postService.updatePost(
        postId: widget.post.id,
        content: _contentController.text.trim(),
        newImageFile: _newImageFile,
        existingImageUrl: widget.post.imageUrl,
        removeImage: _removeImage,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('수정 실패: $e'),
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
      appBar: AppBar(
        title: const Text('게시글 수정'),
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
                  : const Text('완료',
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
              TextField(
                controller: _contentController,
                maxLines: 8,
                minLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: '내용을 수정해주세요',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          const BorderSide(color: AppColors.brownLight)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          const BorderSide(color: AppColors.brownLight)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 8),

              // 이미지 미리보기
              if (_newImageFile != null) ...[
                _buildImagePreview(
                  child: Image.file(_newImageFile!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover),
                  onRemove: () =>
                      setState(() => _newImageFile = null),
                ),
                const SizedBox(height: 12),
              ] else if (_currentImageUrl != null) ...[
                _buildImagePreview(
                  child: Image.network(_currentImageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover),
                  onRemove: () =>
                      setState(() => _removeImage = true),
                ),
                const SizedBox(height: 12),
              ],

              if (widget.post.imageUrls.length > 1)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Text(
                    '사진이 여러 장인 게시글은 수정 시 사진이 첫 번째 한 장으로 교체됩니다.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),

              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined,
                    color: AppColors.primary),
                label: Text(
                  (_newImageFile != null || _currentImageUrl != null)
                      ? '사진 변경'
                      : '사진 추가',
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

  Widget _buildImagePreview({
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}
