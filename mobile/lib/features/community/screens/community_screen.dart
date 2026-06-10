import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_util.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';
import '../../chat/screens/chat_list_screen.dart';
import 'add_community_post_screen.dart';
import 'community_post_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _service = CommunityService();

  int _selectedCategory = 0;
  List<CommunityPost> _posts = [];
  bool _loading = true;

  static const _categories = ['전체', '실종', '나눔&입양', '꿀팁/정보', '질문/고민'];
  static const _categoryColors = [
    AppColors.primary,
    AppColors.error,
    AppColors.success,
    AppColors.catTip,
    AppColors.catQuestion,
  ];
  static const _categoryIcons = [
    Icons.grid_view_rounded,
    Icons.location_searching_rounded,
    Icons.favorite_border_rounded,
    Icons.lightbulb_outline_rounded,
    Icons.chat_bubble_outline_rounded,
  ];

  // 탭 → DB category 값 매핑
  List<String>? get _filterCategories {
    switch (_selectedCategory) {
      case 1: return ['lost'];
      case 2: return ['rehome', 'looking'];
      case 3: return ['tip'];
      case 4: return ['question'];
      default: return null; // 전체
    }
  }

  // 글쓰기 버튼 탭 시 기본 카테고리
  String get _defaultWriteCategory {
    switch (_selectedCategory) {
      case 1: return 'lost';
      case 2: return 'rehome';
      case 3: return 'tip';
      case 4: return 'question';
      default: return 'lost';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = _posts.isEmpty);
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
    super.build(context);
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
            title: const Text('나눔 & 실종',
                style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatListScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: _openWrite,
              ),
            ],
          ),
        ),
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
      height: 58,
      color: AppColors.background,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final selected = _selectedCategory == index;
          final color = _categoryColors[index];
          return GestureDetector(
            onTap: () => _applyCategory(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: selected ? color : color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(24),
                boxShadow: selected
                    ? [BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3))]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(_categoryIcons[index],
                      size: 15,
                      color: selected ? Colors.white : color),
                  const SizedBox(width: 5),
                  Text(_categories[index],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : color)),
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
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: AppColors.primaryLight.withValues(alpha: 0.25),
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
                switch (_selectedCategory) {
                  1 => '🔍',
                  2 => '🏠',
                  3 => '💡',
                  4 => '💬',
                  _ => '📋',
                },
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
      case 3: return '등록된 꿀팁이 없어요';
      case 4: return '등록된 질문이 없어요';
      default: return '아직 게시글이 없어요';
    }
  }

  String _getEmptySubtitle() {
    switch (_selectedCategory) {
      case 1: return '실종된 아이를 제보해주세요';
      case 2: return '나눔 또는 입양 글을 올려주세요';
      case 3: return '반려동물 꿀팁을 공유해보세요 💡';
      case 4: return '궁금한 점을 자유롭게 물어보세요';
      default: return '첫 번째 글을 올려보세요';
    }
  }
}

// ── 게시글 카드 ──────────────────────────────────────────

class _CommunityCard extends StatelessWidget {
  final CommunityPost post;
  const _CommunityCard({required this.post});

  static const _catColors = {
    'lost':     AppColors.error,
    'found':    AppColors.info,
    'rehome':   AppColors.success,
    'looking':  AppColors.warning,
    'tip':      AppColors.catTip,
    'question': AppColors.catQuestion,
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일', 'ko').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _catColors[post.category] ?? AppColors.primary;
    final hasThumbnail = post.imageUrls.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWarm,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
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
                      color: AppColors.brownLight.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text('해결됨',
                        style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ),
                ],
                const Spacer(),
                Text(_timeAgo(post.createdAt),
                    style: AppTextStyles.caption),
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
                        style: AppTextStyles.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (post.content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          post.content,
                          style: AppTextStyles.bodySmall,
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
                    child: CachedNetworkImage(
                      imageUrl: toTransformUrl(post.imageUrls.first, width: 200, quality: 75),
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox(),
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
                    _tag(post.petName!, AppColors.card, AppColors.primary),
                  if (post.location != null)
                    _tag('📍 ${post.location!}', AppColors.info.withValues(alpha: 0.1), AppColors.info),
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
                  style: AppTextStyles.caption,
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
