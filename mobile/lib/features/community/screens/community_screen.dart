import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';
import 'add_community_post_screen.dart';
import 'community_post_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _service = CommunityService();

  int _selectedCategory = 0;
  List<CommunityPost> _posts = [];
  bool _loading = true;

  static const _categories = ['전체', '실종', '나눔&입양'];
  static const _categoryColors = [
    AppColors.primary,
    Color(0xFFE53935),
    Color(0xFF43A047),
  ];
  static const _categoryIcons = [
    Icons.grid_view_rounded,
    Icons.location_searching_rounded,
    Icons.favorite_border_rounded,
  ];

  // 탭 → DB category 값 매핑
  List<String>? get _filterCategories {
    switch (_selectedCategory) {
      case 1: return ['lost'];
      case 2: return ['rehome', 'looking'];
      default: return null; // 전체
    }
  }

  // 글쓰기 버튼 탭 시 기본 카테고리
  String get _defaultWriteCategory {
    switch (_selectedCategory) {
      case 1: return 'lost';
      case 2: return 'rehome';
      default: return 'lost';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final posts = await _service.getPosts(categories: _filterCategories);
      if (mounted) setState(() => _posts = posts);
    } catch (e) {
      debugPrint('community load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyCategory(int index) {
    setState(() => _selectedCategory = index);
    _loadPosts();
  }

  Future<void> _openWrite() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCommunityPostScreen(
          initialCategory: _defaultWriteCategory,
        ),
      ),
    );
    if (result == true) _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF0DC),
        title: const Text('나눔 & 실종',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _openWrite,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _loadPosts,
                    color: AppColors.primary,
                    child: _posts.isEmpty ? _buildEmpty() : _buildList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openWrite,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit_rounded),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      height: 48,
      color: const Color(0xFFFFFAF5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final selected = _selectedCategory == index;
          return GestureDetector(
            onTap: () => _applyCategory(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? _categoryColors[index] : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _categoryColors[index] : AppColors.brownLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(_categoryIcons[index], size: 14,
                      color: selected ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(_categories[index],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityPostDetailScreen(post: _posts[i]),
          ),
        ),
        child: _CommunityCard(post: _posts[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Text(
                _selectedCategory == 1 ? '🔍' : _selectedCategory == 2 ? '🏠' : '📋',
                style: const TextStyle(fontSize: 56),
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyTitle(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(_getEmptySubtitle(),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _openWrite,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('글 올리기'),
                style: TextButton.styleFrom(
                  foregroundColor: _categoryColors[_selectedCategory],
                  backgroundColor:
                      _categoryColors[_selectedCategory].withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getEmptyTitle() {
    switch (_selectedCategory) {
      case 1: return '등록된 실종 글이 없어요';
      case 2: return '나눔&입양 글이 없어요';
      default: return '아직 게시글이 없어요';
    }
  }

  String _getEmptySubtitle() {
    switch (_selectedCategory) {
      case 1: return '실종된 아이를 제보해주세요';
      case 2: return '나눔 또는 입양 글을 올려주세요';
      default: return '첫 번째 글을 올려보세요';
    }
  }
}

// ── 게시글 카드 ──────────────────────────────────────────

class _CommunityCard extends StatelessWidget {
  final CommunityPost post;
  const _CommunityCard({required this.post});

  static const _catColors = {
    'lost': Color(0xFFE53935),
    'found': Color(0xFF1E88E5),
    'rehome': Color(0xFF43A047),
    'looking': Color(0xFFFF8F00),
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M/d', 'ko').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _catColors[post.category] ?? AppColors.primary;
    final hasThumbnail = post.imageUrls.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D6E63).withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 카테고리 뱃지 + 상태 + 시간
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.categoryLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: catColor),
                  ),
                ),
                if (post.isResolved) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('해결됨',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ],
                const Spacer(),
                Text(_timeAgo(post.createdAt),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textHint)),
              ],
            ),
            const SizedBox(height: 9),

            // 제목 + 썸네일
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (post.content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          post.content,
                          style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              height: 1.45),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasThumbnail) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      post.imageUrls.first,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ],
              ],
            ),

            // 태그 행 (펫 이름, 펫 종류, 장소)
            if (post.petName != null || post.petType != null || post.location != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (post.petType != null)
                    _tag(post.petType == 'cat' ? '🐱 고양이' : '🐶 강아지', AppColors.primaryLight, AppColors.primary),
                  if (post.petName != null)
                    _tag(post.petName!, const Color(0xFFFFF3EB), AppColors.primary),
                  if (post.location != null)
                    _tag('📍 ${post.location!}', const Color(0xFFF0F4FF), const Color(0xFF1E88E5)),
                ],
              ),
            ],

            // 하단: 작성자
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: post.ownerAvatarUrl != null
                      ? NetworkImage(post.ownerAvatarUrl!)
                      : null,
                  child: post.ownerAvatarUrl == null
                      ? const Icon(Icons.person, size: 12, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  post.ownerName ?? '사용자',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
