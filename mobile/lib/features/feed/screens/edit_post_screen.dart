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

  late List<String> _keptUrls;   // 기존 이미지 중 유지할 것들
  final List<File> _newFiles = [];     // 새로 추가한 파일
  final List<String> _removedUrls = []; // 삭제 예정 URL

  bool _loading = false;

  static const _maxImages = 5;

  int get _totalCount => _keptUrls.length + _newFiles.length;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    _keptUrls = List<String>.from(widget.post.imageUrls);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _totalCount;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
    setState(() => _newFiles.addAll(toAdd));
  }

  void _removeExisting(int index) {
    setState(() {
      _removedUrls.add(_keptUrls[index]);
      _keptUrls.removeAt(index);
    });
  }

  void _removeNew(int index) {
    setState(() => _newFiles.removeAt(index));
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
        keptImageUrls: _keptUrls,
        newImageFiles: _newFiles,
        removedImageUrls: _removedUrls,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
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
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),

              // 이미지 그리드
              if (_totalCount > 0) ...[
                SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // 기존 유지 이미지
                      ..._keptUrls.asMap().entries.map((e) => _ImageThumb(
                            child: Image.network(e.value,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                    width: 88,
                                    height: 88,
                                    color: AppColors.primaryLight)),
                            onRemove: () => _removeExisting(e.key),
                          )),
                      // 새로 추가한 이미지
                      ..._newFiles.asMap().entries.map((e) => _ImageThumb(
                            child: Image.file(e.value,
                                width: 88, height: 88, fit: BoxFit.cover),
                            onRemove: () => _removeNew(e.key),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _totalCount >= _maxImages ? null : _pickImages,
                    icon: const Icon(Icons.image_outlined,
                        color: AppColors.primary, size: 18),
                    label: Text(
                      _totalCount == 0 ? '사진 추가' : '사진 추가 ($_totalCount/$_maxImages)',
                      style: const TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _ImageThumb({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(10), child: child),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12)),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
