import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../../feed/models/post_model.dart';
import '../../feed/screens/post_detail_screen.dart';
import '../../feed/services/follow_service.dart';
import '../../feed/services/post_service.dart';
import '../../pet/models/pet_model.dart';
import '../../pet/services/pet_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/widgets/app_image.dart';
import '../services/block_service.dart';
import '../widgets/profile_banner.dart';
import 'follow_list_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? initialName;
  final String? initialAvatarUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialAvatarUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _followService = FollowService();
  final _postService = PostService();
  final _petService = PetService();
  final _blockService = BlockService();
  late final ScrollController _scrollController;

  List<Post> _posts = [];
  List<Pet> _pets = [];
  int _followers = 0;
  int _following = 0;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _loading = true;
  bool _followLoading = false;
  bool _hasError = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  PostCursor? _cursor;
  int _postCount = 0;

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';
  bool get _isMyProfile => widget.userId == _myId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadData();
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
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    setState(() => _loadingMore = true);
    try {
      final more = await _postService.getPostsByUser(widget.userId, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _posts.addAll(more);
        if (more.isNotEmpty) _cursor = (createdAt: more.last.createdAt.toIso8601String(), id: more.last.id);
        _hasMore = more.length >= 20;
      });
    } catch (e) {
      debugPrint('loadMorePosts error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('더 불러오기 실패. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _hasError = false; _cursor = null; _hasMore = true; });
    try {
      final supabase = Supabase.instance.client;
      final results = await Future.wait<dynamic>([
        _postService.getPostsByUser(widget.userId, cursor: null),
        _followService.getFollowCounts(widget.userId),
        _petService.getPetsByUser(widget.userId),
        supabase.from('posts').count().eq('owner_id', widget.userId).eq('is_hidden', false),
        if (!_isMyProfile) _followService.isFollowing(widget.userId),
        if (!_isMyProfile) _blockService.isBlocked(widget.userId),
      ]);
      if (!mounted) return;
      final firstPage = results[0] as List<Post>;
      final counts = results[1] as Map<String, int>;
      final totalCount = (results[3] as int?) ?? 0;
      setState(() {
        _posts = firstPage;
        _postCount = totalCount;
        if (firstPage.isNotEmpty) _cursor = (createdAt: firstPage.last.createdAt.toIso8601String(), id: firstPage.last.id);
        _hasMore = firstPage.length >= 20;
        _pets = results[2] as List<Pet>;
        _followers = counts['followers'] ?? 0;
        _following = counts['following'] ?? 0;
        if (!_isMyProfile) {
          _isFollowing = results[4] as bool;
          _isBlocked = results[5] as bool;
        }
      });
    } catch (e) {
      debugPrint('UserProfileScreen load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleBlock() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final nowBlocked = await _blockService.toggleBlock(widget.userId);
      if (!mounted) return;
      setState(() {
        _isBlocked = nowBlocked;
        if (nowBlocked) _isFollowing = false;
      });
      messenger.showSnackBar(SnackBar(
        content: Text(nowBlocked ? '차단했어요' : '차단을 해제했어요'),
      ));
      if (nowBlocked && mounted) Navigator.pop(context);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('요청에 실패했어요')),
      );
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _followLoading = true);
    try {
      final nowFollowing =
          await _followService.toggleFollow(widget.userId);
      if (!mounted) return;
      setState(() {
        _isFollowing = nowFollowing;
        _followers += nowFollowing ? 1 : -1;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요청에 실패했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  void _showOptions(BuildContext context) {
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
                child: ListTile(
                  leading: Icon(
                    _isBlocked ? Icons.lock_open_outlined : Icons.block_outlined,
                    color: AppColors.error,
                  ),
                  title: Text(
                    _isBlocked ? '차단 해제' : '차단',
                    style: const TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _isBlocked
                        ? '이 사용자의 게시글이 다시 보여요'
                        : '이 사용자의 게시글이 피드에서 숨겨져요',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showBlockConfirm();
                  },
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

  Future<void> _showBlockConfirm() async {
    final name = widget.initialName ?? '사용자';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_isBlocked ? '차단 해제' : '$name 차단'),
        content: Text(_isBlocked
            ? '$name님의 차단을 해제하시겠어요?'
            : '$name님을 차단하면 이 사용자의 게시글이 피드에서 숨겨지고 팔로우 관계가 해제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _isBlocked ? '해제' : '차단',
              style: const TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (ok == true) _toggleBlock();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.initialName ?? '사용자';
    final avatarUrl = widget.initialAvatarUrl;

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
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: false,
            actions: _isMyProfile
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showOptions(context),
                    ),
                  ],
          ),
        ),
      ),
      body: _loading
          ? const SingleChildScrollView(
              child: Column(children: [
                ProfileBannerSkeleton(),
                ProfileGridSkeleton(),
              ]),
            )
          : _hasError
              ? _buildError()
              : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(avatarUrl, name),
                  ),
                  _posts.isEmpty
                      ? SliverFillRemaining(child: _buildEmpty())
                      : SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 1.5,
                            mainAxisSpacing: 1.5,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildGridItem(_posts[index]),
                            childCount: _posts.length,
                          ),
                        ),
                  if (_loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(String? avatarUrl, String name) {
    final followBtn = _isMyProfile
        ? null
        : SizedBox(
            width: double.infinity,
            child: _followLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : OutlinedButton(
                    onPressed: _toggleFollow,
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          _isFollowing ? Colors.transparent : AppColors.primary,
                      foregroundColor:
                          _isFollowing ? AppColors.textPrimary : Colors.white,
                      side: BorderSide(
                        color: _isFollowing
                            ? AppColors.brownLight
                            : AppColors.primary,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      _isFollowing ? '팔로잉' : '팔로우',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
          );

    final petsWidget = _pets.isEmpty
        ? null
        : Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _pets
                .map((pet) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (pet.profileImageUrl != null)
                            ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: toTransformUrl(pet.profileImageUrl, width: 40, height: 40, quality: 80),
                                width: 20,
                                height: 20,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Text(pet.emoji,
                                    style: const TextStyle(fontSize: 14)),
                              ),
                            )
                          else
                            Text(pet.emoji,
                                style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          Text(pet.name,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ))
                .toList(),
          );

    return ProfileBanner(
      avatarUrl: avatarUrl,
      name: name,
      statsRow: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(value: '$_postCount', label: '게시물'),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FollowListScreen(userId: widget.userId, showFollowers: true),
            )),
            child: _StatColumn(value: '$_followers', label: '팔로워'),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FollowListScreen(userId: widget.userId, showFollowers: false),
            )),
            child: _StatColumn(value: '$_following', label: '팔로잉'),
          ),
        ],
      ),
      actionButton: followBtn,
      petsRow: petsWidget,
    );
  }

  Widget _buildGridItem(Post post) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      ),
      child: post.imageUrl != null
          ? AppGridImage(url: post.imageUrl!)
          : _buildTextTile(post),
    );
  }

  Widget _buildTextTile(Post post) {
    return Container(
      color: AppColors.primaryLight,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        post.content,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.camera_alt_outlined,
              size: 56, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('아직 게시글이 없어요',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
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
          const Text('불러오지 못했어요',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() { _hasError = false; _loading = true; });
              _loadData();
            },
            child: const Text('다시 시도', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
