import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/app_image.dart';
import '../../feed/models/post_model.dart';
import '../../feed/screens/post_detail_screen.dart';
import '../../feed/services/follow_service.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../services/search_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchService = SearchService();
  final _followService = FollowService();
  late final TabController _tabController;

  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  int _searchId = 0;

  List<Map<String, dynamic>> _users = [];
  List<Post> _posts = [];
  Map<String, bool> _followStates = {};
  final Set<String> _followLoading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {}); // clear 버튼 즉시 반영
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _users = [];
        _posts = [];
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(trimmed),
    );
  }

  Future<void> _search(String query) async {
    final thisId = ++_searchId;
    setState(() {
      _loading = true;
      _query = query;
    });
    try {
      final results = await Future.wait([
        _searchService.searchUsers(query),
        _searchService.searchPosts(query),
        _followService.getFollowingIds(),
      ]);
      if (!mounted || thisId != _searchId) return; // 오래된 응답 버림
      final users = results[0] as List<Map<String, dynamic>>;
      final followingIds = (results[2] as List<String>).toSet();
      setState(() {
        _users = users;
        _posts = results[1] as List<Post>;
        _followStates = {
          for (final u in users)
            u['id'] as String: followingIds.contains(u['id'] as String),
        };
      });
    } catch (e) {
      debugPrint('search error: $e');
    } finally {
      if (mounted && thisId == _searchId) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(String userId) async {
    if (_followLoading.contains(userId)) return;
    setState(() => _followLoading.add(userId));
    final current = _followStates[userId] ?? false;
    setState(() => _followStates[userId] = !current);
    try {
      await _followService.toggleFollow(userId);
    } catch (_) {
      if (mounted) setState(() => _followStates[userId] = current);
    } finally {
      if (mounted) setState(() => _followLoading.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        titleSpacing: 16,
        title: TextField(
          controller: _searchController,
          onChanged: _onQueryChanged,
          autofocus: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '유저 이름, 게시글 내용 검색',
            hintStyle:
                const TextStyle(color: AppColors.textHint, fontSize: 14),
            prefixIcon:
                const Icon(Icons.search_rounded, color: AppColors.textHint),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _onQueryChanged('');
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textHint, size: 20),
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brownLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brownLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(
              text: _query.isEmpty
                  ? '유저'
                  : '유저 ${_users.isNotEmpty ? "(${_users.length})" : ""}',
            ),
            Tab(
              text: _query.isEmpty
                  ? '게시글'
                  : '게시글 ${_posts.isNotEmpty ? "(${_posts.length})" : ""}',
            ),
          ],
        ),
      ),
      body: _loading
          ? const SearchUserSkeleton()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserTab(),
                _buildPostTab(),
              ],
            ),
    );
  }

  Widget _buildUserTab() {
    if (_query.isEmpty) return _buildIdleState('유저 이름으로 검색해보세요');
    if (_users.isEmpty) return _buildEmptyState('일치하는 유저가 없어요');
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.divider, indent: 72),
      itemBuilder: (context, index) => _UserTile(
        user: _users[index],
        isFollowing: _followStates[_users[index]['id'] as String] ?? false,
        isLoading:
            _followLoading.contains(_users[index]['id'] as String),
        onFollowTap: () =>
            _toggleFollow(_users[index]['id'] as String),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              userId: _users[index]['id'] as String,
              initialName:
                  _users[index]['display_name'] as String? ?? '사용자',
              initialAvatarUrl:
                  _users[index]['avatar_url'] as String?,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostTab() {
    if (_query.isEmpty) return _buildIdleState('게시글 내용으로 검색해보세요');
    if (_posts.isEmpty) return _buildEmptyState('일치하는 게시글이 없어요');
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _posts.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) => _PostTile(
        post: _posts[index],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: _posts[index]),
          ),
        ),
        onProfileTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              userId: _posts[index].ownerId,
              initialName: _posts[index].ownerName,
              initialAvatarUrl: _posts[index].ownerAvatarUrl,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdleState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_rounded,
              size: 56, color: AppColors.brownLight),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Image.asset('assets/images/검색결과없음.png', width: 320),
    );
  }
}

// ── 유저 타일 ────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onFollowTap;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.isFollowing,
    required this.isLoading,
    required this.onFollowTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['display_name'] as String? ?? '사용자';
    final avatarUrl = user['avatar_url'] as String?;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(url: avatarUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary),
              ),
            ),
            isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : OutlinedButton(
                    onPressed: onFollowTap,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? Colors.transparent
                          : AppColors.primary,
                      foregroundColor: isFollowing
                          ? AppColors.textPrimary
                          : Colors.white,
                      side: BorderSide(
                        color: isFollowing
                            ? AppColors.brownLight
                            : AppColors.primary,
                      ),
                      minimumSize: const Size(76, 34),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isFollowing ? '팔로잉' : '팔로우',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── 게시글 타일 ──────────────────────────────────────────

class _PostTile extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onProfileTap;

  const _PostTile({
    required this.post,
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

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primaryLight.withValues(alpha: 0.3),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onProfileTap,
              child: _Avatar(url: post.ownerAvatarUrl, size: 38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onProfileTap,
                        child: Text(
                          post.ownerName ?? '사용자',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      if (petLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(petLabel,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.content,
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                        height: 1.45),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.imageUrl != null) ...[
                    const SizedBox(height: 8),
                    AppPostImage(url: post.imageUrl!, fixedHeight: 140),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        post.isLikedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 15,
                        color: post.isLikedByMe
                            ? AppColors.error
                            : AppColors.textHint,
                      ),
                      if (post.likesCount > 0) ...[
                        const SizedBox(width: 3),
                        Text('${post.likesCount}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint)),
                      ],
                      const SizedBox(width: 14),
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 15, color: AppColors.textHint),
                      if (post.commentsCount > 0) ...[
                        const SizedBox(width: 3),
                        Text('${post.commentsCount}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint)),
                      ],
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

// ── 아바타 ───────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;

  const _Avatar({this.url, required this.size});

  @override
  Widget build(BuildContext context) => AppAvatar(url: url, size: size);
}
