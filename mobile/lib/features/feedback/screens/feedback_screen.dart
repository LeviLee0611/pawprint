import 'package:flutter/material.dart';
import '../services/feedback_service.dart';
import '../../../core/theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _service = FeedbackService();
  final _contentController = TextEditingController();
  String _category = '일반 의견';
  bool _sending = false;

  static const _categories = [
    ('🐛', '버그 신고'),
    ('✨', '기능 요청'),
    ('💬', '일반 의견'),
  ];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await _service.submit(category: _category, content: content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('소중한 의견 감사해요! 꼭 반영할게요 🙏')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('전송 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF0DC), Color(0xFFFFFAF5)],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('피드백 보내기'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _sending ? null : _submit,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Text('보내기',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 카드
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Text('🐾', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('여러분의 의견이 앱을 만들어요',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 14)),
                        SizedBox(height: 2),
                        Text('버그, 불편한 점, 원하는 기능 무엇이든 알려주세요',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 카테고리 선택
            const Text('유형',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: _categories
                  .map((c) => Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _category = c.$2),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _category == c.$2
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _category == c.$2
                                    ? AppColors.primary
                                    : AppColors.brownLight,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(c.$1, style: const TextStyle(fontSize: 20)),
                                const SizedBox(height: 4),
                                Text(
                                  c.$2,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _category == c.$2
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),

            // 내용 입력
            const Text('내용',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 10),
            TextField(
              controller: _contentController,
              maxLines: 10,
              minLines: 6,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: _category == '버그 신고'
                    ? '어떤 상황에서 오류가 발생했는지 자세히 알려주세요\n예: "피드에서 좋아요를 누르면 앱이 꺼져요"'
                    : _category == '기능 요청'
                        ? '어떤 기능이 있으면 좋을지 알려주세요\n예: "펫끼리 사진을 비교해볼 수 있으면 좋겠어요"'
                        : '자유롭게 의견을 남겨주세요',
                hintStyle:
                    const TextStyle(color: AppColors.textHint, fontSize: 13),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
