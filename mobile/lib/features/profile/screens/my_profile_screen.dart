import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../feed/models/post_model.dart';
import '../../feed/screens/post_detail_screen.dart';
import '../../feed/services/follow_service.dart';
import '../../feed/services/post_service.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _postService = PostService();
  final _followService = FollowService();

  List<Post> _posts = [];
  int _followers = 0;
  int _following = 0;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final myId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    try {
      final results = await Future.wait([
        _postService.getMyPosts(),
        _followService.getFollowCounts(myId),
      ]);
      if (!mounted) return;
      final counts = results[1] as Map<String, int>;
      setState(() {
        _posts = results[0] as List<Post>;
        _followers = counts['followers'] ?? 0;
        _following = counts['following'] ?? 0;
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final name = (user?.userMetadata?['full_name'] ??
            user?.userMetadata?['name'] ??
            '이름 없음') as String;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      ? SliverFillRemaining(
                          child: _buildEmpty(),
                        )
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 그라데이션 배너
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFE0B2),
                Color(0xFFFFF3E8),
                Color(0xFFFFFAF5),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 아바타 — 흰 테두리링
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? ClipOval(
                          child: Image.asset('assets/images/앱로고.png',
                              width: 84, height: 84, fit: BoxFit.cover))
                      : null,
                ),
              ),
              const SizedBox(width: 20),
              // 통계
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(value: '${_posts.length}', label: '게시물'),
                    _StatColumn(value: '$_followers', label: '팔로워'),
                    _StatColumn(value: '$_following', label: '팔로잉'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 이름
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary)),
        ),
        const Divider(height: 1),
      ],
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
