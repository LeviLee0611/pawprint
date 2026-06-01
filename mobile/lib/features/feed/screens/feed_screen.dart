import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../pet/models/pet_model.dart';
import '../../pet/services/pet_service.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../../../features/profile/screens/user_profile_screen.dart';
import '../services/follow_service.dart';
import 'add_post_screen.dart';
import 'post_detail_screen.dart';
import '../widgets/report_bottom_sheet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

enum _FeedFilter { all, following, cat, dog }

class _FeedScreenState extends State<FeedScreen> {
  final _postService = PostService();
  final _petService = PetService();
  final _followService = FollowService();

  List<Post> _posts = [];
  List<Pet> _myPets = [];
  Set<String> _followingIds = {};
  _FeedFilter _filter = _FeedFilter.all;
  bool _loading = true;
  bool _hasError = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  final Set<String> _togglingLikes = {};
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final more = await _postService.getPosts(offset: _posts.length);
      if (!mounted) return;
      setState(() {
        _posts.addAll(_enrichPosts(more));
        _hasMore = more.length >= 20;
      });
    } catch (e) {
      debugPrint('loadMore error: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Pet> _cachedPets = [];

  List<Post> _enrichPosts(List<Post> rawPosts) {
    final petMap = {for (final p in _cachedPets) p.id: p};
    final me = Supabase.instance.client.auth.currentUser;
    final myName = (me?.userMetadata?['full_name'] ??
        me?.userMetadata?['name'] ??
        '나') as String;
    final myAvatar = me?.userMetadata?['avatar_url'] as String?;
    return rawPosts.map((post) {
      Post p = post;
      if (post.ownerId == me?.id) {
        p = p.copyWith(ownerName: myName, ownerAvatarUrl: myAvatar);
      }
      if (p.petId != null && petMap.containsKey(p.petId)) {
        final pet = petMap[p.petId!]!;
        p = p.copyWith(petName: pet.name, petType: pet.type);
      }
      return p;
    }).toList();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _hasError = false; _hasMore = true; });
    try {
      final results = await Future.wait([
        _postService.getPosts(offset: 0),
        _petService.getMyPets(),
        _followService.getFollowingIds(),
      ]);
      if (!mounted) return;
      final rawPosts = results[0] as List<Post>;
      final pets = results[1] as List<Pet>;
      final followingIds = results[2] as List<String>;
      _cachedPets = pets;
      setState(() {
        _posts = _enrichPosts(rawPosts);
        _myPets = pets;
        _followingIds = followingIds.toSet();
        _hasMore = rawPosts.length >= 20;
      });
    } catch (e) {
      debugPrint('loadAll error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Post> get _filteredPosts {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    return _posts.where((post) {
      switch (_filter) {
        case _FeedFilter.all:
          return true;
        case _FeedFilter.following:
          return post.ownerId == myId ||
              _followingIds.contains(post.ownerId);
        case _FeedFilter.cat:
          return post.petType == 'cat';
        case _FeedFilter.dog:
          return post.petType == 'dog';
      }
    }).toList();
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    if (_togglingLikes.contains(post.id)) return; // race condition 방지
    _togglingLikes.add(post.id);
    setState(() {
      _posts[index] = post.copyWith(
        isLikedByMe: !post.isLikedByMe,
        likesCount: post.likesCount + (post.isLikedByMe ? -1 : 1),
      );
    });
    try {
      await _postService.toggleLike(post.id);
    } catch (e) {
      debugPrint('toggleLike error: $e');
      if (mounted) setState(() => _posts[index] = post);
    } finally {
      _togglingLikes.remove(post.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('댕냥스토리'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: _buildFilterChips(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _hasError
              ? _buildError()
              : RefreshIndicator(
              onRefresh: _loadAll,
              color: AppColors.primary,
              child: _filteredPosts.isEmpty
                  ? _buildEmptyState()
                  : _buildFeed(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _myPets.isEmpty
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddPostScreen(pets: _myPets)),
                );
                await _loadAll();
              },
        backgroundColor:
            _myPets.isEmpty ? AppColors.brownLight : AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: _myPets.isEmpty ? '펫을 먼저 등록해요' : '글쓰기',
        child: const Icon(Icons.edit_rounded),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text('피드를 불러오지 못했어요',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() { _hasError = false; _loading = true; });
              _loadAll();
            },
            child: const Text('다시 시도', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const items = [
      (_FeedFilter.all, '전체'),
      (_FeedFilter.following, '팔로잉'),
      (_FeedFilter.cat, '고양이 🐱'),
      (_FeedFilter.dog, '강아지 🐶'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDE8E3))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: items.map((item) {
            final selected = _filter == item.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _filter = item.$1),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : AppColors.brownLight,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    final posts = _filteredPosts;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: posts.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final post = posts[index];
        final rawIndex = _posts.indexOf(post);
        final isLast = index < posts.length - 1;
        return Column(
          children: [
            _ThreadPost(
              post: post,
              onLike: () => _toggleLike(rawIndex),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: post),
                  ),
                );
                await _loadAll();
              },
              onProfileTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    userId: post.ownerId,
                    initialName: post.ownerName,
                    initialAvatarUrl: post.ownerAvatarUrl,
                  ),
                ),
              ),
            ),
            if (isLast)
              const Divider(height: 1, color: Color(0xFFEDE8E3)),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Column(
          children: [
            const Text('🐾', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('아직 첫 글이 없어요',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              _myPets.isEmpty
                  ? '펫을 먼저 등록해주세요'
                  : '오른쪽 아래 버튼으로 첫 글을 남겨보세요',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 스레드 스타일 포스트 ─────────────────────────────────

class _ThreadPost extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onTap;
  final VoidCallback onProfileTap;

  const _ThreadPost({
    required this.post,
    required this.onLike,
    required this.onTap,
    required this.onProfileTap,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분';
    if (diff.inDays < 1) return '${diff.inHours}시간';
    if (diff.inDays < 7) return '${diff.inDays}일';
    return DateFormat('M/d', 'ko').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final petLabel = post.petName != null
        ? '${post.petType == 'cat' ? '🐱' : '🐶'} ${post.petName}'
        : null;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isMyPost = post.ownerId == myId;

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primaryLight.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽: 아바타
            GestureDetector(
              onTap: onProfileTap,
              child: _Avatar(url: post.ownerAvatarUrl, size: 40),
            ),
            const SizedBox(width: 12),

            // 오른쪽: 내용 전체
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름 + 펫 + 시간
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onProfileTap,
                        child: Text(
                          post.ownerName ?? '사용자',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      if (petLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(petLabel,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                      const Spacer(),
                      Text(_timeAgo(post.createdAt),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint)),
                      if (!isMyPost) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => showReportSheet(context,
                              targetType: 'post', targetId: post.id),
                          child: const Icon(Icons.more_vert,
                              size: 18, color: AppColors.textHint),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  // 본문
                  Text(
                    post.content,
                    style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                        height: 1.5),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 이미지
                  if (post.imageUrl != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        post.imageUrl!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // 액션 버튼
                  Row(
                    children: [
                      _ActionBtn(
                        icon: post.isLikedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: post.likesCount > 0
                            ? '${post.likesCount}'
                            : '',
                        color: post.isLikedByMe
                            ? const Color(0xFFE53935)
                            : AppColors.textHint,
                        onTap: onLike,
                      ),
                      const SizedBox(width: 20),
                      _ActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: post.commentsCount > 0
                            ? '${post.commentsCount}'
                            : '',
                        color: AppColors.textHint,
                        onTap: onTap,
                      ),
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
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;

  const _Avatar({this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? ClipOval(
              child: Image.asset('assets/images/앱로고.png',
                  width: size, height: size, fit: BoxFit.cover))
          : null,
    );
  }
}
