import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../community/screens/community_post_detail_screen.dart';
import '../../community/services/community_service.dart';
import '../../feed/screens/post_detail_screen.dart';
import '../../feed/services/post_service.dart';
import '../../profile/screens/user_profile_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _supabase = Supabase.instance.client;
  final _postService = PostService();
  final _communityService = CommunityService();

  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String _filter = 'pending'; // pending | resolved | dismissed | all

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = _filter == 'all'
          ? await _supabase
              .from('reports')
              .select('*, reporter:reporter_id(display_name, avatar_url)')
              .order('created_at', ascending: false)
          : await _supabase
              .from('reports')
              .select('*, reporter:reporter_id(display_name, avatar_url)')
              .eq('status', _filter)
              .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _reports = (data as List).cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('admin load error: $e');
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _updateStatus(String reportId, String status) async {
    try {
      await _supabase.from('reports').update({
        'status': status,
        'handled_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('처리 실패: $e')));
      }
    }
  }

  Future<void> _deletePost(String postId, String reportId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글을 삭제하고 신고를 처리완료로 변경할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final row = await _supabase
          .from('posts')
          .select('image_url, image_urls')
          .eq('id', postId)
          .maybeSingle();
      final urls = <String>[
        if (row?['image_url'] is String) row!['image_url'] as String,
        ...((row?['image_urls'] as List?)?.cast<String>() ?? []),
      ];
      await _postService.deletePost(postId, imageUrls: urls);
      await _updateStatus(reportId, 'resolved');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  Future<void> _deleteCommunityPost(String postId, String reportId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('커뮤니티 글 삭제'),
        content: const Text('이 커뮤니티 글을 삭제하고 신고를 처리완료로 변경할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _communityService.deletePost(postId);
      await _updateStatus(reportId, 'resolved');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('관리자 — 신고 처리'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                for (final f in [
                  ('pending', '미처리'),
                  ('resolved', '처리완료'),
                  ('dismissed', '기각'),
                  ('all', '전체'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) {
                        setState(() => _filter = f.$1);
                        _load();
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: _filter == f.$1 ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: _filter == f.$1 ? AppColors.primary : AppColors.brownLight),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _reports.isEmpty
              ? Center(
                  child: Text(
                    _filter == 'pending' ? '미처리 신고가 없어요 🎉' : '신고 내역이 없어요',
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _reports.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFEDE8E3)),
                    itemBuilder: (context, i) => _ReportTile(
                      report: _reports[i],
                      onResolve: () => _updateStatus(_reports[i]['id'], 'resolved'),
                      onDismiss: () => _updateStatus(_reports[i]['id'], 'dismissed'),
                      onDeletePost: _reports[i]['target_type'] == 'post'
                          ? () => _deletePost(_reports[i]['target_id'], _reports[i]['id'])
                          : _reports[i]['target_type'] == 'community_post'
                              ? () => _deleteCommunityPost(_reports[i]['target_id'], _reports[i]['id'])
                              : null,
                      onViewContent: () async {
                        final type = _reports[i]['target_type'];
                        final targetId = _reports[i]['target_id'];
                        if (type == 'post') {
                          final post = await _postService.getPostById(targetId);
                          if (!context.mounted || post == null) return;
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: post),
                          ));
                        } else if (type == 'community_post') {
                          final post = await _communityService.getPostById(targetId);
                          if (!context.mounted || post == null) return;
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => CommunityPostDetailScreen(post: post),
                          ));
                        }
                      },
                      onViewReporter: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          userId: _reports[i]['reporter_id'],
                          initialName: (_reports[i]['reporter'] as Map?)?['display_name'],
                        ),
                      )),
                    ),
                  ),
                ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;
  final VoidCallback? onDeletePost;
  final VoidCallback onViewContent;
  final VoidCallback onViewReporter;

  const _ReportTile({
    required this.report,
    required this.onResolve,
    required this.onDismiss,
    this.onDeletePost,
    required this.onViewContent,
    required this.onViewReporter,
  });

  String _timeAgo(String raw) {
    final dt = DateTime.parse(raw).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return DateFormat('M/d HH:mm', 'ko').format(dt);
  }

  Color get _statusColor {
    switch (report['status']) {
      case 'resolved': return const Color(0xFF43A047);
      case 'dismissed': return AppColors.textHint;
      default: return const Color(0xFFE53935);
    }
  }

  String get _statusLabel {
    switch (report['status']) {
      case 'resolved': return '처리완료';
      case 'dismissed': return '기각';
      default: return '미처리';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reporterName = (report['reporter'] as Map?)?['display_name'] as String? ?? '알 수 없음';
    final isPending = report['status'] == 'pending';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  switch (report['target_type']) {
                    'post' => '피드 글',
                    'community_post' => '커뮤니티 글',
                    _ => report['target_type'] as String? ?? '기타',
                  },
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              const Spacer(),
              Text(_timeAgo(report['created_at']),
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '사유: ${report['reason']}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onViewReporter,
            child: Text(
              '신고자: $reporterName',
              style: const TextStyle(fontSize: 12, color: AppColors.primary, decoration: TextDecoration.underline),
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewContent,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('내용 보기', style: TextStyle(fontSize: 13)),
                  ),
                ),
                if (onDeletePost != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDeletePost,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        report['target_type'] == 'community_post' ? '커뮤니티 글 삭제' : '게시글 삭제',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textHint,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('기각', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onResolve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('처리완료', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
