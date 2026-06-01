import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../feed/models/post_model.dart';
import '../../feed/screens/post_detail_screen.dart';
import '../../feed/services/follow_service.dart';
import '../../feed/services/post_service.dart';
import '../../pet/models/pet_model.dart';
import '../../pet/services/pet_service.dart';
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

  List<Post> _posts = [];
  List<Pet> _pets = [];
  int _followers = 0;
  int _following = 0;
  bool _isFollowing = false;
  bool _loading = true;
  bool _followLoading = false;
  bool _hasError = false;

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';
  bool get _isMyProfile => widget.userId == _myId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _postService.getPostsByUser(widget.userId),
        _followService.getFollowCounts(widget.userId),
        _petService.getPetsByUser(widget.userId),
        if (!_isMyProfile) _followService.isFollowing(widget.userId),
      ]);
      if (!mounted) return;
      final counts = results[1] as Map<String, int>;
      setState(() {
        _posts = results[0] as List<Post>;
        _pets = results[2] as List<Pet>;
        _followers = counts['followers'] ?? 0;
        _following = counts['following'] ?? 0;
        if (!_isMyProfile) _isFollowing = results[3] as bool;
      });
    } catch (e) {
      debugPrint('UserProfileScreen load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final name = widget.initialName ?? '사용자';
    final avatarUrl = widget.initialAvatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _hasError
              ? _buildError()
              : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: CustomScrollView(
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
                              child: Image.network(
                                pet.profileImageUrl!,
                                width: 20,
                                height: 20,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Text(pet.emoji,
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
          _StatColumn(value: '${_posts.length}', label: '게시물'),
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
          ? Image.network(
              post.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildTextTile(post),
            )
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
    return Column(
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
    );
  }
}
