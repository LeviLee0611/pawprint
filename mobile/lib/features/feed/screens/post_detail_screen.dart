import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/report_bottom_sheet.dart';
import 'edit_post_screen.dart';

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
  final _commentFocusNode = FocusNode();

  List<Comment> _comments = [];
  bool _loadingComments = true;
  bool _submittingComment = false;
  late Post _post;
  Comment? _replyingTo;

  Map<String?, List<Comment>> get _grouped {
    final map = <String?, List<Comment>>{};
    for (final c in _comments) {
      (map[c.parentId] ??= []).add(c);
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    final me = Supabase.instance.client.auth.currentUser;
    if (widget.post.ownerId == me?.id && widget.post.ownerName == null) {
      final myName = (me?.userMetadata?['full_name'] ??
          me?.userMetadata?['name'] ??
          '사용자') as String;
      final myAvatar = me?.userMetadata?['avatar_url'] as String?;
      _post =
          widget.post.copyWith(ownerName: myName, ownerAvatarUrl: myAvatar);
    } else {
      _post = widget.post;
    }
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
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

  void _startReply(Comment comment) {
    setState(() => _replyingTo = comment);
    _commentFocusNode.requestFocus();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submittingComment = true);
    try {
      final parentId = _replyingTo == null
          ? null
          : (_replyingTo!.parentId ?? _replyingTo!.id);

      var comment =
          await _postService.addComment(_post.id, text, parentId: parentId);
      if (comment.ownerName == null) {
        final me = Supabase.instance.client.auth.currentUser;
        final myName = (me?.userMetadata?['full_name'] ??
            me?.userMetadata?['name'] ??
            '사용자') as String;
        final myAvatar = me?.userMetadata?['avatar_url'] as String?;
        comment = Comment(
          id: comment.id,
          postId: comment.postId,
          ownerId: comment.ownerId,
          parentId: comment.parentId,
          content: comment.content,
          createdAt: comment.createdAt,
          ownerName: myName,
          ownerAvatarUrl: myAvatar,
        );
      }
      if (!mounted) return;
      _commentController.clear();
      _commentFocusNode.unfocus();
      setState(() {
        _replyingTo = null;
        _comments.add(comment);
        _post = _post.copyWith(commentsCount: _post.commentsCount + 1);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final isTopLevel = comment.parentId == null;
    final childCount = isTopLevel
        ? _comments.where((c) => c.parentId == comment.id).length
        : 0;
    try {
      await _postService.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        if (isTopLevel) {
          _comments.removeWhere(
              (c) => c.id == comment.id || c.parentId == comment.id);
        } else {
          _comments.removeWhere((c) => c.id == comment.id);
        }
        _post = _post.copyWith(
            commentsCount: _post.commentsCount - 1 - childCount);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      color: AppColors.error,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _postService.deletePost(_post.id, imageUrls: _post.imageUrls);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showPostOptions(bool isMyPost) {
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
                child: isMyPost
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit_outlined,
                                color: AppColors.primary),
                            title: const Text('수정',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                            onTap: () async {
                              Navigator.pop(context);
                              final updated =
                                  await Navigator.push<Post>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditPostScreen(post: _post),
                                ),
                              );
                              if (updated != null && mounted) {
                                setState(() => _post = updated.copyWith(
                                      ownerName: _post.ownerName,
                                      ownerAvatarUrl:
                                          _post.ownerAvatarUrl,
                                      petName: _post.petName,
                                      petType: _post.petType,
                                      likesCount: _post.likesCount,
                                      commentsCount:
                                          _post.commentsCount,
                                      isLikedByMe: _post.isLikedByMe,
                                    ));
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 16),
                          ListTile(
                            leading: const Icon(Icons.delete_outline,
                                color: AppColors.error),
                            title: const Text('삭제',
                                style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600)),
                            onTap: () {
                              Navigator.pop(context);
                              _deletePost();
                            },
                          ),
                        ],
                      )
                    : ListTile(
                        leading: const Icon(Icons.flag_outlined,
                            color: AppColors.textSecondary),
                        title: const Text('신고',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                        onTap: () {
                          Navigator.pop(context);
                          showReportSheet(context,
                              targetType: 'post',
                              targetId: _post.id);
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

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isMyPost = _post.ownerId == myId;
    bool canDelete(Comment c) => c.ownerId == myId || isMyPost;
    bool canReport(Comment c) => c.ownerId != myId;
    final grouped = _grouped;
    final topLevel = grouped[null] ?? [];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('게시글'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showPostOptions(isMyPost),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                _OriginalPost(post: _post, onLike: _toggleLike),
                const Divider(height: 1, color: AppColors.divider),
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
                if (_loadingComments)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                  )
                else if (topLevel.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: 32, horizontal: 16),
                    child: Center(
                      child: Text('첫 댓글을 남겨봐요 🐾',
                          style: TextStyle(
                              color: AppColors.textHint, fontSize: 14)),
                    ),
                  )
                else
                  ...topLevel.map((c) => _CommentThread(
                        comment: c,
                        replies: grouped[c.id] ?? [],
                        canDelete: canDelete,
                        canReport: canReport,
                        onReply: _startReply,
                        onDelete: _deleteComment,
                      )),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // 답글 달기 배너
          if (_replyingTo != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.card,
              child: Row(
                children: [
                  Text(
                    '${_replyingTo!.ownerName ?? '사용자'}에게 답글',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close,
                        size: 16, color: AppColors.textHint),
                  ),
                ],
              ),
            ),

          // 댓글 입력창
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
                  top: BorderSide(color: AppColors.divider, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      decoration: InputDecoration(
                        hintText: _replyingTo != null
                            ? '답글 달기...'
                            : '댓글 달기...',
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
          Row(
            children: [
              _CircleAv(url: post.ownerAvatarUrl, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.ownerName ?? '사용자',
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
          Text(post.content,
              style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  height: 1.6)),
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailImageCarousel(urls: post.imageUrls),
          ],
          const SizedBox(height: 14),
          if (post.likesCount > 0) ...[
            Text('좋아요 ${post.likesCount}개',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
          ],
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

class _LikeBtn extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;

  const _LikeBtn({required this.isLiked, required this.onTap});

  @override
  State<_LikeBtn> createState() => _LikeBtnState();
}

class _LikeBtnState extends State<_LikeBtn> with SingleTickerProviderStateMixin {
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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: ScaleTransition(
          scale: _scale,
          child: Icon(
            widget.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: 24,
            color: widget.isLiked ? AppColors.error : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

// ── 댓글 ⋮ 옵션 바텀시트 ──────────────────────────────────

void _showCommentOptions(
  BuildContext context, {
  required String content,
  required String commentId,
  required bool canDelete,
  required bool canReport,
  required VoidCallback onDelete,
}) {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

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
                  // 복사 (항상)
                  ListTile(
                    leading: const Icon(Icons.copy_outlined,
                        color: AppColors.textPrimary),
                    title: const Text('복사'),
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: content));
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                            content: Text('복사됐어요'),
                            duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                  if (canDelete) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                      title: const Text('삭제',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                    ),
                  ],
                  if (canReport) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined,
                          color: AppColors.textSecondary),
                      title: const Text('신고',
                          style: TextStyle(
                              color: AppColors.textSecondary)),
                      onTap: () {
                        Navigator.pop(context);
                        showReportSheet(context,
                            targetType: 'comment',
                            targetId: commentId);
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

// ── 댓글 스레드 위젯 ──────────────────────────────────────

class _CommentThread extends StatelessWidget {
  final Comment comment;
  final List<Comment> replies;
  final bool Function(Comment) canDelete;
  final bool Function(Comment) canReport;
  final void Function(Comment) onReply;
  final void Function(Comment) onDelete;

  const _CommentThread({
    required this.comment,
    required this.replies,
    required this.canDelete,
    required this.canReport,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasReplies = replies.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 아바타 + 세로선
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  _CircleAv(url: comment.ownerAvatarUrl, size: 42),
                  if (hasReplies)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          margin:
                              const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 댓글 내용 + 답글들
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(comment.ownerName ?? '사용자',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showCommentOptions(
                          context,
                          content: comment.content,
                          commentId: comment.id,
                          canDelete: canDelete(comment),
                          canReport: canReport(comment),
                          onDelete: () => onDelete(comment),
                        ),
                        child: const Icon(Icons.more_vert,
                            size: 18, color: AppColors.textHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(comment.content,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.4)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => onReply(comment),
                    child: const Text('답글 달기',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textHint)),
                  ),
                  // 답글 목록
                  ...replies.map((r) => Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _ReplyRow(
                          reply: r,
                          canDelete: canDelete(r),
                          canReport: canReport(r),
                          onReply: () => onReply(r),
                          onDelete: () => onDelete(r),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 답글 행 위젯 ───────────────────────────────────────────

class _ReplyRow extends StatelessWidget {
  final Comment reply;
  final bool canDelete;
  final bool canReport;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const _ReplyRow({
    required this.reply,
    required this.canDelete,
    required this.canReport,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CircleAv(url: reply.ownerAvatarUrl, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(reply.ownerName ?? '사용자',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showCommentOptions(
                      context,
                      content: reply.content,
                      commentId: reply.id,
                      canDelete: canDelete,
                      canReport: canReport,
                      onDelete: onDelete,
                    ),
                    child: const Icon(Icons.more_vert,
                        size: 17, color: AppColors.textHint),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(reply.content,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onReply,
                child: const Text('답글 달기',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 상세 이미지 캐러셀 ─────────────────────────────────────

class _DetailImageCarousel extends StatefulWidget {
  final List<String> urls;
  const _DetailImageCarousel({required this.urls});

  @override
  State<_DetailImageCarousel> createState() => _DetailImageCarouselState();
}

class _DetailImageCarouselState extends State<_DetailImageCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.urls.first,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.urls[i],
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.urls.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: _current == i ? AppColors.primary : AppColors.brownLight,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────

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
