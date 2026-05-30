import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _postService = PostService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  List<Comment> _comments = [];
  bool _loadingComments = true;
  bool _submittingComment = false;
  late Post _post;

  @override
  void initState() {
    super.initState();
    // 내 글이면 이름/아바타 주입
    final me = Supabase.instance.client.auth.currentUser;
    if (widget.post.ownerId == me?.id && widget.post.ownerName == null) {
      final myName = (me?.userMetadata?['full_name']
              ?? me?.userMetadata?['name']
              ?? '나') as String;
      final myAvatar = me?.userMetadata?['avatar_url'] as String?;
      _post = widget.post.copyWith(
          ownerName: myName, ownerAvatarUrl: myAvatar);
    } else {
      _post = widget.post;
    }
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    final comments = await _postService.getComments(_post.id);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loadingComments = false;
    });
  }

  Future<void> _toggleLike() async {
    final prev = _post;
    setState(() {
      _post = _post.copyWith(
        isLikedByMe: !_post.isLikedByMe,
        likesCount: _post.likesCount + (_post.isLikedByMe ? -1 : 1),
      );
    });
    try {
      await _postService.toggleLike(_post.id);
    } catch (_) {
      if (mounted) setState(() => _post = prev);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submittingComment = true);
    try {
      var comment = await _postService.addComment(_post.id, text);
      // 내 이름/아바타 주입 (profiles join 없이)
      final me = Supabase.instance.client.auth.currentUser;
      final myName = (me?.userMetadata?['full_name']
              ?? me?.userMetadata?['name']
              ?? '나') as String;
      final myAvatar = me?.userMetadata?['avatar_url'] as String?;
      comment = Comment(
        id: comment.id,
        postId: comment.postId,
        ownerId: comment.ownerId,
        content: comment.content,
        createdAt: comment.createdAt,
        ownerName: myName,
        ownerAvatarUrl: myAvatar,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _comments.add(comment);
        _post = _post.copyWith(commentsCount: _post.commentsCount + 1);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    try {
      await _postService.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _post = _post.copyWith(commentsCount: _post.commentsCount - 1);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('게시글 삭제',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('게시글을 삭제하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _postService.deletePost(_post.id, imageUrl: _post.imageUrl);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isMyPost = _post.ownerId == myId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('게시글'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEDE8E3)),
        ),
        actions: [
          if (isMyPost)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deletePost,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                // ── 원글 ──────────────────────────────────
                _OriginalPost(
                  post: _post,
                  onLike: _toggleLike,
                ),
                const Divider(height: 1, color: Color(0xFFEDE8E3)),

                // ── 댓글 헤더 ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    '댓글 ${_post.commentsCount}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                        letterSpacing: 0.3),
                  ),
                ),

                // ── 댓글 목록 ─────────────────────────────
                if (_loadingComments)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                  )
                else if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: 32, horizontal: 16),
                    child: Center(
                      child: Text(
                        '첫 댓글을 남겨봐요 🐾',
                        style: TextStyle(
                            color: AppColors.textHint, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ...List.generate(_comments.length, (i) {
                    final c = _comments[i];
                    final isLast = i == _comments.length - 1;
                    return Column(
                      children: [
                        _CommentRow(
                          comment: c,
                          isMine: c.ownerId == myId,
                          onDelete: () => _deleteComment(c),
                        ),
                        if (!isLast)
                          const Divider(
                              height: 1,
                              indent: 68,
                              color: Color(0xFFEDE8E3)),
                      ],
                    );
                  }),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── 댓글 입력창 ───────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(color: Color(0xFFEDE8E3), width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: '댓글 달기...',
                        hintStyle: const TextStyle(
                            color: AppColors.textHint, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _submittingComment ? null : _submitComment,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _submittingComment
                            ? AppColors.brownLight
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _submittingComment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.arrow_upward_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 원글 위젯 ──────────────────────────────────────────────

class _OriginalPost extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;

  const _OriginalPost({required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final petLabel = post.petName != null
        ? '${post.petType == 'cat' ? '🐱' : '🐶'} ${post.petName}'
        : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 행
          Row(
            children: [
              _CircleAv(url: post.ownerAvatarUrl, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.ownerName ?? '익명',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    if (petLabel != null)
                      Text(petLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(
                DateFormat('M월 d일 HH:mm', 'ko').format(post.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 본문
          Text(
            post.content,
            style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.6),
          ),

          // 이미지
          if (post.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // 좋아요 수 텍스트
          if (post.likesCount > 0) ...[
            Text(
              '좋아요 ${post.likesCount}개',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEDE8E3)),
            const SizedBox(height: 10),
          ],

          // 액션 버튼
          Row(
            children: [
              _LikeBtn(isLiked: post.isLikedByMe, onTap: onLike),
              const SizedBox(width: 24),
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 22, color: AppColors.textHint),
            ],
          ),
        ],
      ),
    );
  }
}

class _LikeBtn extends StatelessWidget {
  final bool isLiked;
  final VoidCallback onTap;

  const _LikeBtn({required this.isLiked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        isLiked
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        size: 24,
        color: isLiked ? const Color(0xFFE53935) : AppColors.textHint,
      ),
    );
  }
}

// ── 댓글 행 위젯 ──────────────────────────────────────────

class _CommentRow extends StatelessWidget {
  final Comment comment;
  final bool isMine;
  final VoidCallback onDelete;

  const _CommentRow(
      {required this.comment,
      required this.isMine,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleAv(url: comment.ownerAvatarUrl, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.ownerName ?? '익명',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    if (isMine)
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.close,
                            size: 15, color: AppColors.textHint),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAv extends StatelessWidget {
  final String? url;
  final double size;

  const _CircleAv({this.url, required this.size});

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
