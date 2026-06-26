import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/widgets/skeleton.dart';
import '../../feed/models/post_model.dart';
import '../../feed/screens/post_detail_screen.dart';
import '../../feed/services/follow_service.dart';
import '../../feed/services/post_service.dart';
import '../../feed/screens/saved_posts_screen.dart';
import '../widgets/profile_banner.dart';
import 'follow_list_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _postService = PostService();
  final _followService = FollowService();
  late final ScrollController _scrollController;

  List<Post> _posts = [];
  int _followers = 0;
  int _following = 0;
  String? _avatarUrl;
  String _displayName = '';
  bool _loading = true;
  bool _hasError = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  PostCursor? _cursor;
  int _postCount = 0;

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
      final more = await _postService.getMyPosts(cursor: _cursor);
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
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id ?? '';
    try {
      final results = await Future.wait<dynamic>([
        _postService.getMyPosts(cursor: null),
        _followService.getFollowCounts(myId),
        supabase.from('profiles').select('display_name, avatar_url').eq('id', myId).single(),
        supabase.from('posts').count().eq('owner_id', myId).eq('is_hidden', false),
      ]);
      if (!mounted) return;
      final firstPage = results[0] as List<Post>;
      final counts = results[1] as Map<String, int>;
      final profile = results[2] as Map<String, dynamic>;
      final totalCount = (results[3] as int?) ?? 0;
      setState(() {
        _posts = firstPage;
        _postCount = totalCount;
        if (firstPage.isNotEmpty) _cursor = (createdAt: firstPage.last.createdAt.toIso8601String(), id: firstPage.last.id);
        _hasMore = firstPage.length >= 20;
        _followers = counts['followers'] ?? 0;
        _following = counts['following'] ?? 0;
        _avatarUrl = profile['avatar_url'] as String?;
        _displayName = profile['display_name'] as String? ?? '';
      });
    } catch (e) {
      debugPrint('MyProfileScreen load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
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
            title: Text(_displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.bookmark_border_rounded),
                tooltip: '저장된 게시글',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
                ),
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
                    child: _buildHeader(_avatarUrl, _displayName),
                  ),
                  _posts.isEmpty
                      ? SliverFillRemaining(
                          child: _buildEmpty(),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(10),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.0,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildGridItem(_posts[index]),
                              childCount: _posts.length,
                            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileBanner(
          avatarUrl: avatarUrl,
          name: name,
          statsRow: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatColumn(value: '$_postCount', label: '게시물'),
              GestureDetector(
                onTap: () {
                  final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FollowListScreen(userId: myId, showFollowers: true),
                  ));
                },
                child: _StatColumn(value: '$_followers', label: '팔로워'),
              ),
              GestureDetector(
                onTap: () {
                  final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FollowListScreen(userId: myId, showFollowers: false),
                  ));
                },
                child: _StatColumn(value: '$_following', label: '팔로잉'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(Post post) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: post.imageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: toTransformUrl(post.imageUrl, width: 400, height: 400, quality: 75, resize: 'cover'),
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _buildTextTile(post),
                  ),
                  // 하단 그라데이션 + 텍스트 오버레이
                  if (post.content.isNotEmpty)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                        child: Text(
                          post.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              )
            : _buildTextTile(post),
      ),
    );
  }

  Widget _buildTextTile(Post post) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE0B2), Color(0xFFFFF3E8)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(post.petType == 'dog' ? '🐶' : '🐱',
              style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            post.content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.4),
          ),
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
          SizedBox(height: 4),
          Text('첫 번째 순간을 기록해보세요 🐾',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
