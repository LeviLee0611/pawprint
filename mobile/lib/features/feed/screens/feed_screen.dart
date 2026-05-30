import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../pet/models/pet_model.dart';
import '../../pet/services/pet_service.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'add_post_screen.dart';
import 'post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _postService = PostService();
  final _petService = PetService();

  List<Post> _posts = [];
  List<Pet> _myPets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _postService.getPosts(),
      _petService.getMyPets(),
    ]);
    if (!mounted) return;
    final rawPosts = results[0] as List<Post>;
    final pets = results[1] as List<Pet>;
    final petMap = {for (final p in pets) p.id: p};

    // 현재 유저 정보 (auth 메타데이터)
    final me = Supabase.instance.client.auth.currentUser;
    final myName = (me?.userMetadata?['full_name']
            ?? me?.userMetadata?['name']
            ?? '나') as String;
    final myAvatar = me?.userMetadata?['avatar_url'] as String?;

    final enriched = rawPosts.map((post) {
      Post p = post;
      // 작성자가 나인 경우 내 이름/아바타 주입
      if (post.ownerId == me?.id) {
        p = p.copyWith(ownerName: myName, ownerAvatarUrl: myAvatar);
      }
      // 내 펫에 한해 pet 정보 로컬 매칭
      if (p.petId != null && petMap.containsKey(p.petId)) {
        final pet = petMap[p.petId!]!;
        p = p.copyWith(petName: pet.name, petType: pet.type);
      }
      return p;
    }).toList();

    setState(() {
      _posts = enriched;
      _myPets = pets;
      _loading = false;
    });
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    setState(() {
      _posts[index] = post.copyWith(
        isLikedByMe: !post.isLikedByMe,
        likesCount: post.likesCount + (post.isLikedByMe ? -1 : 1),
      );
    });
    try {
      await _postService.toggleLike(post.id);
    } catch (_) {
      if (mounted) setState(() => _posts[index] = post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🐾 포포와 토토'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEDE8E3)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: AppColors.primary,
              child: _posts.isEmpty ? _buildEmptyState() : _buildFeed(),
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

  Widget _buildFeed() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _posts.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEDE8E3)),
      itemBuilder: (context, index) => _ThreadPost(
        post: _posts[index],
        onLike: () => _toggleLike(index),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(post: _posts[index]),
            ),
          );
          await _loadAll();
        },
      ),
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

  const _ThreadPost(
      {required this.post, required this.onLike, required this.onTap});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽: 아바타
            _Avatar(url: post.ownerAvatarUrl, size: 40),
            const SizedBox(width: 12),

            // 오른쪽: 내용 전체
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름 + 펫 + 시간
                  Row(
                    children: [
                      Text(
                        post.ownerName ?? '익명',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary),
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
          ? Icon(Icons.person,
              size: size * 0.5, color: AppColors.primary)
          : null,
    );
  }
}
