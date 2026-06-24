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
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/widgets/app_image.dart';
import '../../pet/services/pet_service.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../../../features/profile/screens/user_profile_screen.dart';
import '../services/follow_service.dart';
import 'add_post_screen.dart';
import 'edit_post_screen.dart';
import 'post_detail_screen.dart';
import '../widgets/report_bottom_sheet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

enum _FeedFilter { all, following, cat, dog, popular }

class _FeedScreenState extends State<FeedScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
    setState(() { _loading = _posts.isEmpty; _hasError = false; _hasMore = true; });
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
    if (reset) setState(() { _hasMore = true; _rawOffset = 0; });
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
      // API 응답 즉시 첫 10개 이미지 백그라운드 다운로드 시작
      _prefetchImages(rawPosts);
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

  void _prefetchImages(List<Post> posts) {
    if (!mounted) return;
    final ctx = context;
    for (final post in posts.take(10)) {
      if (post.imageUrls.isEmpty) continue;
      final url = toTransformUrl(post.imageUrls.first, width: 900, quality: 85);
      if (url.isEmpty) continue;
      unawaited(precacheImage(CachedNetworkImageProvider(url), ctx));
    }
  }

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
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
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
              child: _posts.isEmpty
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
                _loadAll();
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
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _posts.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final post = _posts[index];
        return _ThreadPost(
          key: ValueKey(post.id),
          post: post,
          onLike: () => _toggleLike(index),
          onSave: () => _toggleSave(index),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(post: post),
              ),
            );
            _loadPosts(reset: true);
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
          onEdit: (updated) {
            setState(() {
              final idx = _posts.indexWhere((p) => p.id == updated.id);
              if (idx == -1) return;
              _posts[idx] = updated.copyWith(
                ownerName: post.ownerName,
                ownerAvatarUrl: post.ownerAvatarUrl,
                petName: post.petName,
                petType: post.petType,
                likesCount: post.likesCount,
                commentsCount: post.commentsCount,
                isLikedByMe: post.isLikedByMe,
                isSavedByMe: post.isSavedByMe,
              );
            });
          },
          onDelete: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await _postService.deletePost(post.id, imageUrls: post.imageUrls);
              if (!mounted) return;
              setState(() => _posts.removeWhere((p) => p.id == post.id));
            } catch (e) {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text('삭제 실패: $e'), backgroundColor: AppColors.error),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final (title, subtitle) = _emptyMessage();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Image.asset('assets/images/빈화면_투명.png', width: 260),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  (String, String) _emptyMessage() {
    if (_myPets.isEmpty) {
      return ('아직 아무것도 없어요', '펫을 먼저 등록하면 피드가 활성화돼요 🐾');
    }
    switch (_filter) {
      case _FeedFilter.following:
        return ('팔로잉 피드가 비어있어요', '관심 있는 친구를 팔로우해보세요');
      case _FeedFilter.cat:
        return ('고양이 게시글이 없어요', '고양이 집사들의 첫 게시글을 기다리는 중이에요 🐱');
      case _FeedFilter.dog:
        return ('강아지 게시글이 없어요', '댕댕이 집사들의 첫 게시글을 기다리는 중이에요 🐶');
      case _FeedFilter.popular:
        return ('인기 게시글이 없어요', '좋아요를 많이 받은 게시글이 여기 모여요');
      default:
        return ('아직 게시글이 없어요', '첫 번째 글을 올려볼까요? 🐾');
    }
  }
}

// ── 카드 포스트 ──────────────────────────────────

class _ThreadPost extends StatefulWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final VoidCallback onProfileTap;
  final ValueChanged<Post>? onEdit;
  final VoidCallback? onDelete;

  const _ThreadPost({
    super.key,
    required this.post,
    required this.onLike,
    required this.onSave,
    required this.onTap,
    required this.onProfileTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_ThreadPost> createState() => _ThreadPostState();
}

class _ThreadPostState extends State<_ThreadPost> with TickerProviderStateMixin {
  late final AnimationController _heartCtrl;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  bool _showHeart = false;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
    ]).animate(_heartCtrl);
    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartCtrl);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일', 'ko').format(dt);
  }

  void _handleDoubleTap() {
    widget.onLike();
    if (!widget.post.isLikedByMe) {
      setState(() => _showHeart = true);
      _heartCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _showHeart = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final petLabel = post.petName != null
        ? '${post.petType == 'cat' ? '🐱' : '🐶'} ${post.petName}'
        : null;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isMyPost = post.ownerId == myId;

    if (post.imageUrls.isNotEmpty) {
      return _buildImageCard(post, petLabel, isMyPost);
    }
    return _buildTextPost(post, petLabel, isMyPost);
  }

  // 이미지 포스트: 이미지가 카드 전체, 정보는 overlay
  Widget _buildImageCard(Post post, String? petLabel, bool isMyPost) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: _handleDoubleTap,
          child: Stack(
            children: [
              // 단일 이미지: 3:4 고정 프레임 + cover (Supabase도 900×1200 강제)
              // 다중 이미지: PageView는 고정 높이 필요하므로 4:5 유지
              if (post.imageUrls.length == 1)
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: CachedNetworkImage(
                    imageUrl: toTransformUrl(post.imageUrls[0], width: 900, height: 1200, quality: 85, resize: 'cover'),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_, _) => _ImageShimmer(),
                    errorWidget: (_, _, _) => const SizedBox(),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: PageView.builder(
                    physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
                    itemCount: post.imageUrls.length,
                    onPageChanged: (i) => setState(() => _imageIndex = i),
                    itemBuilder: (context, i) {
                      if (i + 1 < post.imageUrls.length) {
                        precacheImage(CachedNetworkImageProvider(toTransformUrl(post.imageUrls[i + 1], width: 900, height: 1200, quality: 85, resize: 'cover')), context);
                      }
                      return CachedNetworkImage(
                        imageUrl: toTransformUrl(post.imageUrls[i], width: 900, height: 1200, quality: 85, resize: 'cover'),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (_, _) => _ImageShimmer(),
                        errorWidget: (_, _, _) => const SizedBox(),
                      );
                    },
                  ),
                ),
              // 상단 그라디언트 + 사용자 정보
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onProfileTap,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white54, width: 1.5),
                          ),
                          child: _Avatar(url: post.ownerAvatarUrl, size: 30),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onProfileTap,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.ownerName ?? '사용자',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (petLabel != null)
                                Text(
                                  petLabel,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      GestureDetector(
                        onTap: () => _showPostOptions(context, post: post, isMyPost: isMyPost, onEdit: widget.onEdit, onDelete: widget.onDelete),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.more_horiz, size: 18, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 하단 그라디언트 + 본문 + 액션
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xDD000000), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 36, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.content.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            post.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Row(
                        children: [
                          _ActionBtn(
                            icon: post.isLikedByMe
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: post.likesCount > 0 ? '${post.likesCount}' : '',
                            color: post.isLikedByMe ? const Color(0xFFFF6B6B) : Colors.white,
                            onTap: widget.onLike,
                          ),
                          const SizedBox(width: 14),
                          _ActionBtn(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: post.commentsCount > 0 ? '${post.commentsCount}' : '',
                            color: Colors.white,
                            onTap: widget.onTap,
                          ),
                          const Spacer(),
                          if (post.imageUrls.length > 1)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(post.imageUrls.length, (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _imageIndex == i ? 14 : 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: _imageIndex == i ? Colors.white : Colors.white38,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              )),
                            ),
                          const Spacer(),
                          _ActionBtn(
                            icon: post.isSavedByMe
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            label: '',
                            color: post.isSavedByMe ? AppColors.primaryLight : Colors.white,
                            onTap: widget.onSave,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 더블탭 하트 애니메이션
              if (_showHeart)
                Positioned.fill(
                  child: Center(
                    child: ScaleTransition(
                      scale: _heartScale,
                      child: FadeTransition(
                        opacity: _heartOpacity,
                        child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 90),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const _textCardGradients = [
    [Color(0xFFFFB347), Color(0xFFFF6B6B)],
    [Color(0xFF8EC5FC), Color(0xFFA78BFA)],
    [Color(0xFF84FAB0), Color(0xFF38BDF8)],
    [Color(0xFFFDA085), Color(0xFFF6D365)],
    [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
    [Color(0xFF96FBC4), Color(0xFFF9F586)],
    [Color(0xFFFF9A9E), Color(0xFFFFD580)],
    [Color(0xFF6EE7B7), Color(0xFF60A5FA)],
  ];

  // 텍스트 포스트: 그라디언트 카드
  Widget _buildTextPost(Post post, String? petLabel, bool isMyPost) {
    final gradPair = _textCardGradients[post.id.hashCode.abs() % _textCardGradients.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradPair,
              ),
            ),
            child: Stack(
              children: [
                // 상단: 사용자 정보
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onProfileTap,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white54, width: 1.5),
                          ),
                          child: _Avatar(url: post.ownerAvatarUrl, size: 28),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onProfileTap,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.ownerName ?? '사용자',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (petLabel != null)
                                Text(
                                  petLabel,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      GestureDetector(
                        onTap: () => _showPostOptions(context, post: post, isMyPost: isMyPost, onEdit: widget.onEdit, onDelete: widget.onDelete),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.more_horiz, size: 18, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                // 중앙: 본문 텍스트 (큼직하게)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 56),
                  child: Text(
                    post.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      letterSpacing: -0.3,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 하단: 액션 버튼
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.25), Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    child: Row(
                      children: [
                        _ActionBtn(
                          icon: post.isLikedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: post.likesCount > 0 ? '${post.likesCount}' : '',
                          color: post.isLikedByMe ? const Color(0xFFFF6B6B) : Colors.white,
                          onTap: widget.onLike,
                        ),
                        const SizedBox(width: 14),
                        _ActionBtn(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: post.commentsCount > 0 ? '${post.commentsCount}' : '',
                          color: Colors.white,
                          onTap: widget.onTap,
                        ),
                        const Spacer(),
                        _ActionBtn(
                          icon: post.isSavedByMe
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: '',
                          color: post.isSavedByMe ? Colors.white : Colors.white70,
                          onTap: widget.onSave,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showPostOptions(
  BuildContext context, {
  required Post post,
  required bool isMyPost,
  ValueChanged<Post>? onEdit,
  VoidCallback? onDelete,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => SafeArea(
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
                      Navigator.pop(sheetCtx);
                      final ownerName = post.ownerName ?? '누군가';
                      final content = post.content.length > 80
                          ? '${post.content.substring(0, 80)}…'
                          : post.content;
                      Share.share(
                        '[$ownerName] $content\n\n댕냥스토리에서 보기 🐾',
                      );
                    },
                  ),
                  if (isMyPost) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined,
                          color: AppColors.primary),
                      title: const Text('수정하기',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        if (onEdit == null) return;
                        final updated = await Navigator.push<Post>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EditPostScreen(post: post)),
                        );
                        if (updated != null) onEdit(updated);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                      title: const Text('삭제하기',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('게시글 삭제'),
                            content: const Text('이 게시글을 삭제할까요?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('삭제',
                                    style: TextStyle(color: AppColors.error)),
                              ),
                            ],
                          ),
                        ).then((confirmed) {
                          if (confirmed == true) onDelete?.call();
                        });
                      },
                    ),
                  ] else ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined,
                          color: AppColors.error),
                      title: const Text('신고하기',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(sheetCtx);
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
                onTap: () => Navigator.pop(sheetCtx),
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

class _ImageShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E0D8),
      highlightColor: const Color(0xFFF5F0EB),
      child: Container(color: const Color(0xFFE8E0D8)),
    );
  }
}
