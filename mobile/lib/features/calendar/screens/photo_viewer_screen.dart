import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record_model.dart';
import '../../pet/models/pet_model.dart';

class PhotoViewerScreen extends StatelessWidget {
  final Record record;
  final Pet? pet;

  const PhotoViewerScreen({super.key, required this.record, this.pet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 핀치 줌 가능한 전체화면 사진
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                record.photoUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),

          // 하단 정보 오버레이
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
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
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('yyyy년 M월 d일 (E)', 'ko').format(record.date),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                  if (record.notes != null && record.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      record.notes!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
