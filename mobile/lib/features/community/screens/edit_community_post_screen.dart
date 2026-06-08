import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';

class EditCommunityPostScreen extends StatefulWidget {
  final CommunityPost post;
  const EditCommunityPostScreen({super.key, required this.post});

  @override
  State<EditCommunityPostScreen> createState() =>
      _EditCommunityPostScreenState();
}

class _EditCommunityPostScreenState extends State<EditCommunityPostScreen> {
  final _service = CommunityService();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _petNameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _addressCtrl;

  String? _petType;
  double? _latitude;
  double? _longitude;
  bool _submitting = false;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _titleCtrl = TextEditingController(text: p.title);
    _contentCtrl = TextEditingController(text: p.content);
    _petNameCtrl = TextEditingController(text: p.petName ?? '');
    _locationCtrl = TextEditingController(text: p.location ?? '');
    _contactCtrl = TextEditingController(text: p.contact ?? '');
    _addressCtrl = TextEditingController(text: p.address ?? '');
    _petType = p.petType;
    _latitude = p.latitude;
    _longitude = p.longitude;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _petNameCtrl.dispose();
    _locationCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 필요해요')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _addressCtrl.text =
            '현재 위치 (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 가져올 수 없어요')));
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final updated = await _service.updatePost(
        postId: widget.post.id,
        title: title,
        content: _contentCtrl.text.trim(),
        petName: _petNameCtrl.text.trim(),
        petType: _petType,
        location: _locationCtrl.text.trim(),
        contact: _contactCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLost = widget.post.category == 'lost';
    final showPetName = widget.post.category != 'looking';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('글 수정'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : const Text('저장',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('제목 *'),
            const SizedBox(height: 8),
            _field(_titleCtrl, '제목을 입력해주세요'),
            const SizedBox(height: 16),

            if (showPetName) ...[
              _label('반려동물 이름'),
              const SizedBox(height: 8),
              _field(_petNameCtrl, '이름 (선택)'),
              const SizedBox(height: 16),
            ],

            _label('반려동물 종류'),
            const SizedBox(height: 8),
            Row(
              children: [
                _petChip('cat', '🐱 고양이'),
                const SizedBox(width: 10),
                _petChip('dog', '🐶 강아지'),
              ],
            ),
            const SizedBox(height: 16),

            if (isLost) ...[
              _label('실종 위치'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field(_addressCtrl, '주소 입력 또는 GPS')),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _gettingLocation ? null : _getCurrentLocation,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _latitude != null
                            ? AppColors.primary
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _gettingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary))
                          : Icon(
                              Icons.my_location_rounded,
                              color: _latitude != null
                                  ? Colors.white
                                  : AppColors.primary,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              _label('장소/지역'),
              const SizedBox(height: 8),
              _field(_locationCtrl, '예) 서울 강남구 (선택)',
                  icon: Icons.location_on_outlined),
              const SizedBox(height: 16),
            ],

            _label('상세 내용'),
            const SizedBox(height: 8),
            _field(_contentCtrl, '자세한 내용을 입력해주세요', maxLines: 5),
            const SizedBox(height: 16),

            _label('연락처'),
            const SizedBox(height: 8),
            _field(_contactCtrl, '전화번호 또는 카카오 오픈채팅 (선택)',
                icon: Icons.phone_outlined),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary));

  Widget _field(TextEditingController ctrl, String hint,
      {int maxLines = 1, IconData? icon}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.textHint, size: 20)
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _petChip(String value, String label) {
    final selected = _petType == value;
    return GestureDetector(
      onTap: () => setState(() => _petType = selected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.brownLight,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary)),
      ),
    );
  }
}
