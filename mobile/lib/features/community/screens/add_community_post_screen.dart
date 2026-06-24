import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../services/community_service.dart';

class AddCommunityPostScreen extends StatefulWidget {
  final String initialCategory;
  const AddCommunityPostScreen({super.key, required this.initialCategory});

  @override
  State<AddCommunityPostScreen> createState() => _AddCommunityPostScreenState();
}

class _AddCommunityPostScreenState extends State<AddCommunityPostScreen> {
  final _service = CommunityService();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _petNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  late String _category;
  String? _petType;
  final List<File> _imageFiles = [];
  bool _submitting = false;
  bool _gettingLocation = false;
  double? _latitude;
  double? _longitude;
  final _addressCtrl = TextEditingController();

  static const _categoryOptions = [
    ('lost',     '실종 신고',   AppColors.error,       Icons.location_searching_rounded),
    ('found',    '발견 신고',   AppColors.info,        Icons.search_rounded),
    ('rehome',   '입양 보내기', AppColors.success,     Icons.home_rounded),
    ('looking',  '입양 원해요', AppColors.warning,     Icons.favorite_rounded),
    ('tip',      '꿀팁/정보',   AppColors.catTip,      Icons.lightbulb_rounded),
    ('question', '질문/고민',   AppColors.catQuestion, Icons.chat_bubble_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    if (_category == 'lost' || _category == 'found') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          LocationService.ensurePermission(context,
              reason: '신고에 위치를 첨부하려면 위치 권한이 필요해요.');
        }
      });
    }
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
      final granted = await LocationService.ensurePermission(
        context,
        reason: '실종 신고에 위치를 첨부하려면 위치 권한이 필요해요.',
      );
      if (!granted) return;
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치를 가져올 수 없어요')),
          );
        }
        return;
      }
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
      final address = await _reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        _addressCtrl.text = address ??
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 가져올 수 없어요')),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=ko'));
      req.headers.set('User-Agent', 'pawprint-app/1.0');
      final res = await req.close();
      final body = await res.transform(const Utf8Decoder()).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final addr = json['address'] as Map<String, dynamic>?;
      if (addr != null) {
        final parts = [
          addr['city'] ?? addr['county'],
          addr['suburb'] ?? addr['neighbourhood'],
          addr['road'],
        ].whereType<String>().where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) return parts.join(' ');
      }
    } catch (_) {}
    return null;
  }

  bool get _showPetName =>
      _category != 'looking' && _category != 'tip' && _category != 'question';

  bool get _isPetCategory =>
      _category != 'tip' && _category != 'question';

  Future<void> _pickImages() async {
    if (_imageFiles.length >= 5) return;
    final picker = ImagePicker();
    final results = await picker.pickMultiImage(
      imageQuality: 85,
      limit: 5 - _imageFiles.length,
    );
    if (results.isEmpty) return;
    setState(() {
      _imageFiles.addAll(results.map((x) => File(x.path)));
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }
    if (_category == 'lost' && _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('실종 위치를 입력해주세요')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.addPost(
        category: _category,
        title: title,
        content: _contentCtrl.text.trim(),
        petName: _petNameCtrl.text.trim(),
        petType: _petType,
        location: _locationCtrl.text.trim(),
        contact: _contactCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        imageFiles: _imageFiles.isEmpty ? null : _imageFiles,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('글쓰기'),
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
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Text(
                      '등록',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 유형 선택
            _label('유형'),
            const SizedBox(height: 10),
            _buildCategoryGrid(),
            const SizedBox(height: 20),

            // 사진
            _label('사진 (최대 5장)'),
            const SizedBox(height: 8),
            _PhotoRow(
              files: _imageFiles,
              onAdd: _pickImages,
              onRemove: (i) => setState(() => _imageFiles.removeAt(i)),
            ),
            const SizedBox(height: 20),

            // 제목
            _label('제목 *'),
            const SizedBox(height: 8),
            _inputField(_titleCtrl, '제목을 입력해주세요', clearable: true),
            const SizedBox(height: 16),

            // 반려동물 이름 (입양원해요 제외)
            if (_showPetName) ...[
              _label('반려동물 이름'),
              const SizedBox(height: 8),
              _inputField(_petNameCtrl, '이름을 입력해주세요 (선택)'),
              const SizedBox(height: 16),
            ],

            // 종류 (펫 관련 카테고리만)
            if (_isPetCategory) ...[
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
            ],

            // 실종/발견 위치 (GPS 포함)
            if (_category == 'lost' || _category == 'found') ...[
              _label(_category == 'lost' ? '실종 위치 *' : '발견 위치'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addressCtrl,
                      decoration: InputDecoration(
                        hintText: '주소를 입력하거나 GPS로 가져오세요',
                        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                        prefixIcon: const Icon(Icons.location_on_outlined,
                            color: AppColors.textHint, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    ),
                  ),
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
                                  strokeWidth: 2, color: AppColors.primary),
                            )
                          : Icon(
                              Icons.my_location_rounded,
                              color: _latitude != null ? Colors.white : AppColors.primary,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 장소/지역 (나눔/입양 관련)
            if (_isPetCategory && _category != 'lost' && _category != 'found') ...[
              _label(_category == 'looking' ? '원하는 지역' : '장소/지역'),
              const SizedBox(height: 8),
              _inputField(
                _locationCtrl,
                '예) 서울 강남구, 홍대 근처 (선택)',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
            ],

            // 내용
            _label('상세 내용'),
            const SizedBox(height: 8),
            _inputField(_contentCtrl, '자세한 내용을 입력해주세요', maxLines: 5, clearable: true),
            const SizedBox(height: 16),

          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final tileW = (constraints.maxWidth - 16) / 3;
      Widget tile(int i) {
        final (value, label, color, icon) = _categoryOptions[i];
        final selected = _category == value;
        return GestureDetector(
          onTap: () {
            setState(() => _category = value);
            if (value == 'lost' || value == 'found') {
              LocationService.ensurePermission(context,
                  reason: '신고에 위치를 첨부하려면 위치 권한이 필요해요.');
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: tileW,
            height: 76,
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : AppColors.brownLight,
                width: 1.5,
              ),
              boxShadow: selected
                  ? [BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4))]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(icon,
                      key: ValueKey(selected),
                      color: selected ? Colors.white : color,
                      size: 26),
                ),
                const SizedBox(height: 7),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: selected ? Colors.white : AppColors.textSecondary)),
              ],
            ),
          ),
        );
      }

      return Column(
        children: [
          Row(children: [
            tile(0),
            const SizedBox(width: 8),
            tile(1),
            const SizedBox(width: 8),
            tile(2),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            tile(3),
            const SizedBox(width: 8),
            tile(4),
            const SizedBox(width: 8),
            tile(5),
          ]),
        ],
      );
    });
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary));
  }

  Widget _inputField(TextEditingController ctrl, String hint,
      {int maxLines = 1, IconData? icon, bool clearable = false}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textHint, size: 20) : null,
        suffixIcon: clearable
            ? ValueListenableBuilder<TextEditingValue>(
                valueListenable: ctrl,
                builder: (_, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textHint),
                        onPressed: ctrl.clear,
                        splashRadius: 16,
                      ),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.brownLight,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  final List<File> files;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _PhotoRow({required this.files, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (files.length < 5)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 88,
                height: 88,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brownLight, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.textHint, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      '${files.length}/5',
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            ),
          ...files.asMap().entries.map((e) {
            return Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  margin: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(e.value, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 14,
                  child: GestureDetector(
                    onTap: () => onRemove(e.key),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
