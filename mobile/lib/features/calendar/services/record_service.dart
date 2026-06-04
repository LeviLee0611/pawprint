import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/storage_path_util.dart';
import '../models/record_model.dart';

class RecordService {
  final _supabase = Supabase.instance.client;

  static const _bucket = 'record-photos';
  static const _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  Future<List<Record>> getRecordsForMonth(
      String petId, int year, int month) async {
    final lastDay = DateTime(year, month + 1, 0).day;
    final start =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    final end =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    final data = await _supabase
        .from('records')
        .select()
        .eq('pet_id', petId)
        .gte('date', start)
        .lte('date', end)
        .order('created_at');

    return (data as List).map((e) => Record.fromJson(e)).toList();
  }

  Future<List<Record>> getRecordsForMonthAllPets(int year, int month) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final lastDay = DateTime(year, month + 1, 0).day;
    final start =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    final end =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    final data = await _supabase
        .from('records')
        .select()
        .eq('owner_id', userId)
        .gte('date', start)
        .lte('date', end)
        .order('created_at');

    return (data as List).map((e) => Record.fromJson(e)).toList();
  }

  Future<void> addRecord({
    required String petId,
    required DateTime date,
    required String type,
    String? notes,
    double? value,
    File? photo,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    String? photoUrl;
    String? storagePath;

    if (photo != null) {
      final ext = photo.path.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        throw Exception('jpg, png 파일만 업로드할 수 있어요');
      }
      final size = await photo.length();
      if (size > _maxFileSizeBytes) {
        throw Exception('파일 크기는 10MB 이하여야 해요');
      }
      storagePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from(_bucket).upload(storagePath, photo);
      photoUrl = _supabase.storage.from(_bucket).getPublicUrl(storagePath);
    }

    try {
      await _supabase.from('records').insert({
        'pet_id': petId,
        'owner_id': userId,
        'date': dateStr,
        'type': type,
        'notes': notes,
        'value': value,
        'photo_url': photoUrl,
      });
    } catch (e) {
      if (storagePath != null) {
        try {
          await _supabase.storage.from(_bucket).remove([storagePath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<int> getTotalRecordCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    final response = await _supabase
        .from('records')
        .select('id')
        .eq('owner_id', userId)
        .count(CountOption.exact);
    return response.count;
  }

  Future<List<Record>> getAllRecords() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _supabase
        .from('records')
        .select()
        .eq('owner_id', userId)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Record.fromJson(e)).toList();
  }

  Future<List<Record>> getPhotoRecords() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _supabase
        .from('records')
        .select()
        .eq('owner_id', userId)
        .eq('type', 'photo')
        .not('photo_url', 'is', null)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Record.fromJson(e)).toList();
  }

  Future<void> updateRecord({
    required String id,
    String? notes,
    double? value,
    File? newPhoto,
    String? oldPhotoUrl,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    String? newPhotoUrl;
    String? newStoragePath;

    if (newPhoto != null) {
      final ext = newPhoto.path.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        throw Exception('jpg, png 파일만 업로드할 수 있어요');
      }
      final size = await newPhoto.length();
      if (size > _maxFileSizeBytes) {
        throw Exception('파일 크기는 10MB 이하여야 해요');
      }
      newStoragePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from(_bucket).upload(newStoragePath, newPhoto);
      newPhotoUrl =
          _supabase.storage.from(_bucket).getPublicUrl(newStoragePath);

      // 기존 사진 삭제
      if (oldPhotoUrl != null) {
        final path = StoragePathUtil.fromUrl(oldPhotoUrl, _bucket);
        if (path != null) {
          try {
            await _supabase.storage.from(_bucket).remove([path]);
          } catch (_) {}
        }
      }
    }

    try {
      await _supabase.from('records').update({
        'notes': notes,
        'value': value,
        'photo_url': ?newPhotoUrl,
      }).eq('id', id);
    } catch (e) {
      if (newStoragePath != null) {
        try {
          await _supabase.storage.from(_bucket).remove([newStoragePath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<List<Record>> getWeightRecords(String petId) async {
    final data = await _supabase
        .from('records')
        .select()
        .eq('pet_id', petId)
        .eq('type', 'weight')
        .not('value', 'is', null)
        .order('date', ascending: true);
    return (data as List).map((e) => Record.fromJson(e)).toList();
  }

  Future<void> deleteRecord(String id, {String? photoUrl}) async {
    if (photoUrl != null) {
      final path = StoragePathUtil.fromUrl(photoUrl, _bucket);
      if (path != null) {
        try {
          await _supabase.storage.from(_bucket).remove([path]);
        } catch (_) {}
      }
    }
    await _supabase.from('records').delete().eq('id', id);
  }

}
