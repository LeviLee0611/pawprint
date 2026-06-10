import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_util.dart';
import '../models/record_model.dart';
import '../services/record_service.dart';
import '../../pet/models/pet_model.dart';
import '../../pet/services/pet_service.dart';
import 'photo_viewer_screen.dart';

class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  final _recordService = RecordService();
  final _petService = PetService();

  List<Record> _photos = [];
  Map<String, Pet> _petMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _recordService.getPhotoRecords(),
      _petService.getMyPets(),
    ]);
    if (!mounted) return;
    final photos = results[0] as List<Record>;
    final pets = results[1] as List<Pet>;
    setState(() {
      _photos = photos;
      _petMap = {for (final p in pets) p.id: p};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('사진 기록'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEDE8E3)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _photos.isEmpty
              ? _buildEmpty()
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    final r = _photos[index];
                    final pet = _petMap[r.petId];
                    return _PhotoCell(
                      record: r,
                      pet: pet,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PhotoViewerScreen(record: r, pet: pet),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📷', style: TextStyle(fontSize: 56)),
          SizedBox(height: 16),
          Text('아직 사진 기록이 없어요',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Text('캘린더에서 사진 기록을 남겨보세요',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  final Record record;
  final Pet? pet;
  final VoidCallback onTap;

  const _PhotoCell(
      {required this.record, required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: toTransformUrl(record.photoUrl, width: 400, quality: 80),
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Container(
              color: AppColors.primaryLight,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppColors.primary),
            ),
          ),
          // 하단 그라디언트 오버레이
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pet != null)
                    Text(
                      '${pet!.emoji} ${pet!.name}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  Text(
                    DateFormat('M/d', 'ko').format(record.date),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
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
