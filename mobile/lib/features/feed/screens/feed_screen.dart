import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../../notification/screens/notification_screen.dart';
import '../../notification/services/notification_repository.dart';
import '../../pet/models/pet_model.dart';
import '../../profile/services/block_service.dart';
import '../../../core/widgets/app_image.dart';
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
  final _notificationRepo = NotificationRepository();
  final _blockService = BlockService();

  List<Post> _posts = [];
  List<Pet> _myPets = [];
  Set<String> _followingIds = {};
  Set<String> _blockedIds = {};
  _FeedFilter _filter = _FeedFilter.all;
  bool _loading = true;
  bool _hasError = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _rawOffset = 0; // 차단 필터와 무관한 실제 서버 offset
  int _unreadNotifications = 0;
  final Set<String> _togglingLikes = {};
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadAll();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationRepo.getUnreadCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {}
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
      await _loadPosts();
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Pet> _cachedPets = [];

  List<Post> _enrichPosts(List<Post> rawPosts) {
    final petMap = {for (final p in _cachedPets) p.id: p};
    return rawPosts
        .where((post) => !_blockedIds.contains(post.ownerId))
        .map((post) {
      Post p = post;
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
        _petService.getMyPets(),
        _followService.getFollowingIds(),
        _blockService.getBlockedIds(),
      ]);
      if (!mounted) return;
      final pets = results[0] as List<Pet>;
      final followingIds = results[1] as List<String>;
      final blockedIds = results[2] as List<String>;
      _cachedPets = pets;
      _myPets = pets;
      _followingIds = followingIds.toSet();
      _blockedIds = blockedIds.toSet();

      await _loadPosts(reset: true);
    } catch (e) {
      debugPrint('loadAll error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPosts({bool reset = false}) async {
    if (reset) setState(() { _posts = []; _hasMore = true; _rawOffset = 0; });
    try {
      final rawPosts = await _postService.getPosts(
        offset: reset ? 0 : _rawOffset,
        petType: _filter == _FeedFilter.cat
            ? 'cat'
            : _filter == _FeedFilter.dog
                ? 'dog'
                : null,
        followingIds: _filter == _FeedFilter.following
            ? _followingIds.toList()
            : null,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _posts = _enrichPosts(rawPosts);
        } else {
          _posts.addAll(_enrichPosts(rawPosts));
        }
        _rawOffset = (reset ? 0 : _rawOffset) + rawPosts.length;
        _hasMore = rawPosts.length >= 20;
      });
    } catch (e) {
      debugPrint('loadPosts error: $e');
    }
  }

  // 필터 변경 시 서버에서 재조회
  List<Post> get _filteredPosts => _posts;

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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 49),
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
            title: const Text('댕냥스토리'),
            actions: [
              IconButton(
                icon: Badge(
                  isLabelVisible: _unreadNotifications > 0,
                  label: Text('$_unreadNotifications'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationScreen()),
                  );
                  _loadUnreadCount();
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(49),
              child: _buildFilterChips(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const SingleChildScrollView(child: FeedSkeleton())
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
    return GestureDetector(
      onTap: () {
        setState(() { _hasError = false; _loading = true; });
        _loadAll();
      },
      child: Center(
        child: Image.asset('assets/images/네트워킹이슈_투명.png', width: 320),
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
                onSelected: (_) {
                  setState(() => _filter = item.$1);
                  _loadPosts(reset: true);
                },
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
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Image.asset('assets/images/빈화면_투명.png', width: 300),
        ),
        if (_myPets.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              '펫을 먼저 등록해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
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
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _showPostOptions(
                          context,
                          post: post,
                          isMyPost: isMyPost,
                        ),
                        child: const Icon(Icons.more_vert,
                            size: 18, color: AppColors.textHint),
                      ),
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
                    AppPostImage(url: post.imageUrl!),
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

void _showPostOptions(
  BuildContext context, {
  required Post post,
  required bool isMyPost,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.share_outlined,
                        color: AppColors.primary),
                    title: const Text('공유하기',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      final ownerName = post.ownerName ?? '누군가';
                      final content = post.content.length > 80
                          ? '${post.content.substring(0, 80)}…'
                          : post.content;
                      Share.share(
                        '[$ownerName] $content\n\n댕냥스토리에서 보기 🐾',
                      );
                    },
                  ),
                  if (!isMyPost) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined,
                          color: Colors.red),
                      title: const Text('신고하기',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        showReportSheet(context,
                            targetType: 'post', targetId: post.id);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                onTap: () => Navigator.pop(context),
                title: const Text('취소',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => AppAvatar(url: url, size: size);
}
