import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../models/community_post_model.dart';
import '../models/sighting_report_model.dart';
import '../services/community_service.dart';
import '../../feed/widgets/report_bottom_sheet.dart';
import 'add_sighting_screen.dart';
import 'edit_community_post_screen.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final CommunityPost post;
  const CommunityPostDetailScreen({super.key, required this.post});

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final _service = CommunityService();
  late CommunityPost _post;
  List<SightingReport> _sightings = [];
  bool _loadingSightings = false;
  int _imageIndex = 0;

  static const _catColors = {
    'lost': AppColors.error,
    'found': AppColors.info,
    'rehome': AppColors.success,
    'looking': AppColors.warning,
  };

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    if (_post.category == 'lost') _loadSightings();
  }

  Future<void> _loadSightings() async {
    setState(() => _loadingSightings = true);
    try {
      final list = await _service.getSightings(_post.id);
      if (mounted) setState(() => _sightings = list);
    } catch (e) {
      debugPrint('sightings error: $e');
    } finally {
      if (mounted) setState(() => _loadingSightings = false);
    }
  }

  void _showOptions(bool isMyPost) {
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
                    // 공유 (항상)
                    ListTile(
                      leading: const Icon(Icons.share_outlined,
                          color: AppColors.primary),
                      title: const Text('공유하기',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        final text = _post.content.isNotEmpty
                            ? '${_post.title}\n\n${_post.content.length > 80 ? '${_post.content.substring(0, 80)}…' : _post.content}'
                            : _post.title;
                        Share.share('$text\n\n댕냥스토리에서 보기 🐾');
                      },
                    ),
                    if (isMyPost) ...[
                      const Divider(height: 1),
                      // 수정
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
                              await Navigator.push<CommunityPost>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditCommunityPostScreen(post: _post),
                            ),
                          );
                          if (updated != null && mounted) {
                            setState(() => _post = updated);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      // 삭제
                      ListTile(
                        leading: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        title: const Text('삭제',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600)),
                        onTap: () async {
                          Navigator.pop(context);
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: const Text('게시글 삭제'),
                              content: const Text('삭제하시겠어요?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('취소')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('삭제',
                                        style:
                                            TextStyle(color: AppColors.error))),
                              ],
                            ),
                          );
                          if (ok == true && mounted) {
                            await _service.deletePost(_post.id,
                                imageUrls: _post.imageUrls);
                            if (mounted) Navigator.pop(context, true);
                          }
                        },
                      ),
                    ] else ...[
                      const Divider(height: 1),
                      // 신고
                      ListTile(
                        leading: const Icon(Icons.flag_outlined,
                            color: AppColors.textSecondary),
                        title: const Text('신고',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          showReportSheet(context,
                              targetType: 'community_post',
                              targetId: _post.id);
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

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final catColor = _catColors[post.category] ?? AppColors.primary;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isMyPost = post.ownerId == myId;
    final isLost = post.category == 'lost';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(post.categoryLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptions(isMyPost),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // 이미지
          if (post.imageUrls.isNotEmpty) _buildImages(post),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 카테고리 + 상태
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(post.categoryLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: catColor)),
                    ),
                    if (post.isResolved) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brownLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Text('해결됨',
                            style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                      ),
                    ],
                    const Spacer(),
                    Text(DateFormat('M월 d일 HH:mm', 'ko').format(post.createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint)),
                  ],
                ),
                const SizedBox(height: 12),

                // 제목
                Text(post.title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),

                // 작성자
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: post.ownerAvatarUrl != null
                          ? NetworkImage(post.ownerAvatarUrl!)
                          : null,
                      child: post.ownerAvatarUrl == null
                          ? const Icon(Icons.person, size: 14, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(post.ownerName ?? '사용자',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ],
                ),

                const Divider(height: 24, color: AppColors.divider),

                // 펫 정보
                if (post.petName != null || post.petType != null) ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      if (post.petType != null)
                        _tag(post.petType == 'cat' ? '🐱 고양이' : '🐶 강아지',
                            AppColors.primaryLight, AppColors.primary),
                      if (post.petName != null)
                        _tag('이름: ${post.petName!}',
                            AppColors.card, AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 실종 위치
                if (isLost && (post.address != null || post.latitude != null)) ...[
                  GestureDetector(
                    onTap: post.latitude != null
                        ? () => _openMaps(post.latitude!, post.longitude!)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: AppColors.info, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('실종 위치',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.info,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  post.address ?? '좌표: ${post.latitude!.toStringAsFixed(4)}, ${post.longitude!.toStringAsFixed(4)}',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (post.latitude != null)
                            const Icon(Icons.open_in_new_rounded,
                                size: 16, color: AppColors.info),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 내용
                if (post.content.isNotEmpty) ...[
                  Text(post.content,
                      style: AppTextStyles.body),
                  const SizedBox(height: 12),
                ],

                // 연락처
                if (post.contact != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.primaryLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(post.contact!,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 목격 신고 섹션 (실종 글만)
                if (isLost) ...[
                  const Divider(height: 24, color: AppColors.divider),
                  Row(
                    children: [
                      Text(
                        '목격 신고 ${_sightings.isNotEmpty ? "(${_sightings.length})" : ""}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      if (myId != null && myId != post.ownerId)
                        TextButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddSightingScreen(
                                  postId: post.id,
                                  petName: post.petName ?? '이 아이',
                                ),
                              ),
                            );
                            if (result == true) _loadSightings();
                          },
                          icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                          label: const Text('발견했어요'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingSightings)
                    const Center(
                        child: CircularProgressIndicator(color: AppColors.primary))
                  else if (_sightings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('아직 목격 신고가 없어요',
                            style: TextStyle(
                                color: AppColors.textHint, fontSize: 14)),
                      ),
                    )
                  else
                    ..._sightings.map((s) => _SightingCard(
                          sighting: s,
                          onMapTap: s.latitude != null
                              ? () => _openMaps(s.latitude!, s.longitude!)
                              : null,
                        )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImages(CommunityPost post) {
    if (post.imageUrls.length == 1) {
      return Image.network(post.imageUrls.first,
          width: double.infinity, fit: BoxFit.contain);
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: post.imageUrls.length,
            onPageChanged: (i) => setState(() => _imageIndex = i),
            itemBuilder: (_, i) => Image.network(
              post.imageUrls[i],
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(post.imageUrls.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _imageIndex == i ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: _imageIndex == i ? AppColors.primary : AppColors.brownLight,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

// ── 목격 신고 카드 ───────────────────────────────────────

class _SightingCard extends StatelessWidget {
  final SightingReport sighting;
  final VoidCallback? onMapTap;
  const _SightingCard({required this.sighting, this.onMapTap});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return DateFormat('M/d HH:mm', 'ko').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: sighting.reporterAvatarUrl != null
                    ? NetworkImage(sighting.reporterAvatarUrl!)
                    : null,
                child: sighting.reporterAvatarUrl == null
                    ? const Icon(Icons.person, size: 12, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(sighting.reporterName ?? '사용자',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Text(_timeAgo(sighting.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          if (sighting.address != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onMapTap,
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.error, size: 15),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(sighting.address!,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary)),
                  ),
                  if (onMapTap != null)
                    const Icon(Icons.open_in_new_rounded,
                        size: 13, color: AppColors.textHint),
                ],
              ),
            ),
          ],
          if (sighting.note != null && sighting.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(sighting.note!,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4)),
          ],
        ],
      ),
    );
  }
}
