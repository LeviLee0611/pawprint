import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'post_detail_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final _postService = PostService();
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final posts = await _postService.getSavedPosts();
      if (mounted) setState(() => _posts = posts);
    } catch (e) {
      debugPrint('SavedPosts load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unsave(Post post) async {
    setState(() => _posts.removeWhere((p) => p.id == post.id));
    try {
      await _postService.toggleSave(post.id);
    } catch (e) {
      if (mounted) setState(() => _posts.insert(0, post));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('저장된 게시글'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const SingleChildScrollView(child: FeedSkeleton())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border_rounded,
                          size: 64, color: AppColors.brownLight),
                      const SizedBox(height: 16),
                      const Text('저장된 게시글이 없어요',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      const Text('피드에서 북마크 버튼을 눌러 저장해보세요',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textHint)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: _posts.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, i) {
                      final post = _posts[i];
                      return Dismissible(
                        key: Key(post.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.bookmark_remove_outlined,
                              color: AppColors.primary),
                        ),
                        onDismissed: (_) => _unsave(post),
                        child: _SavedPostTile(
                          post: post,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PostDetailScreen(post: post)),
                            );
                            _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _SavedPostTile extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _SavedPostTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: post.ownerAvatarUrl != null
                  ? NetworkImage(post.ownerAvatarUrl!)
                  : null,
              child: post.ownerAvatarUrl == null
                  ? const Icon(Icons.person, size: 20, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.ownerName ?? '사용자',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (post.imageUrl != null) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
