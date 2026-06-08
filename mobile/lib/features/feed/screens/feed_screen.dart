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

enum _FeedFilter { all, following, cat, dog, popular }

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
  final Set<String> _togglingSaves = {};
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
      final List<Post> rawPosts;
      if (_filter == _FeedFilter.popular) {
        rawPosts = await _postService.getPopularPosts(
          offset: reset ? 0 : _rawOffset,
          blockedIds: _blockedIds.toList(),
        );
      } else {
        rawPosts = await _postService.getPosts(
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
      }
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

  List<Post> get _filteredPosts => _posts;

  Future<void> _toggleSave(int index) async {
    final post = _posts[index];
    if (_togglingSaves.contains(post.id)) return;
    _togglingSaves.add(post.id);
    setState(() {
      _posts[index] = post.copyWith(isSavedByMe: !post.isSavedByMe);
    });
    try {
      final saved = await _postService.toggleSave(post.id);
      if (mounted) {
        setState(() => _posts[index] = post.copyWith(isSavedByMe: saved));
      }
    } catch (e) {
      debugPrint('toggleSave error: $e');
      if (mounted) setState(() => _posts[index] = post);
    } finally {
      _togglingSaves.remove(post.id);
    }
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            _FeedFilterChip(
              label: '전체',
              selected: _filter == _FeedFilter.all,
              onTap: () => _applyFilter(_FeedFilter.all),
            ),
            const SizedBox(width: 7),
            _FeedFilterChip(
              label: '팔로잉',
              icon: Icons.people_outline_rounded,
              selected: _filter == _FeedFilter.following,
              onTap: () => _applyFilter(_FeedFilter.following),
            ),
            const SizedBox(width: 7),
            _FeedFilterChip(
              label: '인기',
              icon: Icons.local_fire_department_rounded,
              selected: _filter == _FeedFilter.popular,
              onTap: () => _applyFilter(_FeedFilter.popular),
            ),
            Container(
              height: 18,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.brownLight,
            ),
            _FeedFilterChip(
              label: '고양이',
              emoji: '🐱',
              selected: _filter == _FeedFilter.cat,
              isPet: true,
              onTap: () => _applyFilter(_FeedFilter.cat),
            ),
            const SizedBox(width: 7),
            _FeedFilterChip(
              label: '강아지',
              emoji: '🐶',
              selected: _filter == _FeedFilter.dog,
              isPet: true,
              onTap: () => _applyFilter(_FeedFilter.dog),
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilter(_FeedFilter filter) {
    setState(() => _filter = filter);
    _loadPosts(reset: true);
  }

  Widget _buildFeed() {
    final posts = _filteredPosts;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 100),
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
        return _ThreadPost(
          post: post,
          onLike: () => _toggleLike(rawIndex),
          onSave: () => _toggleSave(rawIndex),
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

// ── 뉴스형 카드 포스트 ──────────────────────────────────

class _ThreadPost extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final VoidCallback onProfileTap;

  const _ThreadPost({
    required this.post,
    required this.onLike,
    required this.onSave,
    required this.onTap,
    required this.onProfileTap,
  });

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
    final petLabel = post.petName != null
        ? '${post.petType == 'cat' ? '🐱' : '🐶'} ${post.petName}'
        : null;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isMyPost = post.ownerId == myId;
    final hasThumbnail = post.imageUrls.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWarm,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryLight.withValues(alpha: 0.25),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─ 헤더: 아바타 + 이름 + 펫칩 + 시간 + 더보기
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onProfileTap,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryLight, width: 2),
                        ),
                        child: _Avatar(url: post.ownerAvatarUrl, size: 34),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: GestureDetector(
                        onTap: onProfileTap,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                post.ownerName ?? '사용자',
                                style: AppTextStyles.subtitle.copyWith(
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (petLabel != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  petLabel,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(post.createdAt),
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                    ),
                    GestureDetector(
                      onTap: () => _showPostOptions(context, post: post, isMyPost: isMyPost),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.more_horiz, size: 18,
                            color: AppColors.textHint.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 9),

                // ─ 본문: 텍스트 왼쪽 + 썸네일 오른쪽
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        post.content,
                        style: AppTextStyles.body.copyWith(letterSpacing: -0.1),
                        maxLines: hasThumbnail ? 4 : 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasThumbnail) ...[
                      const SizedBox(width: 12),
                      _Thumbnail(urls: post.imageUrls),
                    ],
                  ],
                ),

                const SizedBox(height: 9),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 7),

                // ─ 액션 버튼
                Row(
                  children: [
                    _ActionBtn(
                      icon: post.isLikedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: post.likesCount > 0 ? '${post.likesCount}' : '',
                      color: post.isLikedByMe ? AppColors.error : AppColors.textHint,
                      onTap: onLike,
                    ),
                    const SizedBox(width: 16),
                    _ActionBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: post.commentsCount > 0 ? '${post.commentsCount}' : '',
                      color: AppColors.textHint,
                      onTap: onTap,
                    ),
                    const Spacer(),
                    _ActionBtn(
                      icon: post.isSavedByMe
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: '',
                      color: post.isSavedByMe ? AppColors.primary : AppColors.textHint,
                      onTap: onSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 우측 썸네일 위젯 ────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final List<String> urls;
  const _Thumbnail({required this.urls});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            urls.first,
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 88,
              height: 88,
              color: AppColors.primaryLight,
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            right: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${urls.length - 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
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
                          color: AppColors.error),
                      title: const Text('신고하기',
                          style: TextStyle(
                              color: AppColors.error,
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

class _ActionBtn extends StatefulWidget {
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
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.4)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.4, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(widget.icon, size: 19, color: widget.color),
            ),
            if (widget.label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13,
                      color: widget.color,
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

// ── 커스텀 피드 필터칩 ────────────────────────────────────

class _FeedFilterChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final IconData? icon;
  final bool selected;
  final bool isPet;
  final VoidCallback onTap;

  const _FeedFilterChip({
    required this.label,
    this.emoji,
    this.icon,
    required this.selected,
    this.isPet = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? AppColors.primary
        : isPet
            ? AppColors.primaryLight.withValues(alpha: 0.35)
            : AppColors.surface;

    final borderColor = selected
        ? AppColors.primary
        : isPet
            ? AppColors.primary.withValues(alpha: 0.3)
            : AppColors.brownLight;

    final textColor = selected
        ? Colors.white
        : isPet
            ? AppColors.primary
            : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isPet ? 11 : 12,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.brown.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(fontSize: selected ? 15 : 13),
                child: Text(emoji!),
              ),
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
