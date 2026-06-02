import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/storage_path_util.dart';
import '../models/pet_model.dart';

class PetService {
  final _supabase = Supabase.instance.client;

  static const _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  Future<void> deletePet(String petId, {String? photoUrl}) async {
    // 사진 파일 먼저 정리
    if (photoUrl != null) {
      final path = StoragePathUtil.fromUrl(photoUrl, 'pet-photos');
      if (path != null) {
        try {
          await _supabase.storage.from('pet-photos').remove([path]);
        } catch (_) {}
      }
    }
    await _supabase.from('pets').delete().eq('id', petId);
  }

  Future<List<Pet>> getMyPets() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _supabase
        .from('pets')
        .select()
        .eq('owner_id', userId)
        .order('created_at');

    return (data as List).map((e) => Pet.fromJson(e)).toList();
  }

  Future<List<Pet>> getPetsByUser(String userId) async {
    final myId = _supabase.auth.currentUser?.id;
    var query = _supabase.from('pets').select().eq('owner_id', userId);
    // 내 펫이 아닐 때 비공개 펫 제외
    if (userId != myId) query = query.eq('is_public', true);
    final data = await query.order('created_at');
    return (data as List).map((e) => Pet.fromJson(e)).toList();
  }

  Future<void> togglePublicity(String petId, {required bool isPublic}) async {
    await _supabase
        .from('pets')
        .update({'is_public': isPublic})
        .eq('id', petId);
  }

  Future<void> updatePet({
    required String petId,
    required String name,
    required String type,
    String? gender,
    DateTime? birthday,
    String? breed,
    File? newProfileImage,
    String? existingPhotoUrl,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    String? photoUrl = existingPhotoUrl;

    String? newStoragePath;
    if (newProfileImage != null) {
      final ext = newProfileImage.path.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        throw Exception('jpg, png 파일만 업로드할 수 있어요');
      }
      final size = await newProfileImage.length();
      if (size > _maxFileSizeBytes) {
        throw Exception('파일 크기는 5MB 이하여야 해요');
      }
      newStoragePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage
          .from('pet-photos')
          .upload(newStoragePath, newProfileImage);
      photoUrl =
          _supabase.storage.from('pet-photos').getPublicUrl(newStoragePath);
    }

    try {
      await _supabase.from('pets').update({
        'name': name,
        'type': type,
        'gender': gender,
        'birth_date': birthday?.toIso8601String().split('T').first,
        'breed': breed,
        'photo_url': photoUrl,
      }).eq('id', petId);
    } catch (e) {
      // DB 실패 시 새로 업로드한 파일 정리
      if (newStoragePath != null) {
        try {
          await _supabase.storage.from('pet-photos').remove([newStoragePath]);
        } catch (_) {}
      }
      rethrow;
    }

    // DB 성공 후 기존 사진 정리
    if (newProfileImage != null && existingPhotoUrl != null) {
      final oldPath = StoragePathUtil.fromUrl(existingPhotoUrl, 'pet-photos');
      if (oldPath != null) {
        try {
          await _supabase.storage.from('pet-photos').remove([oldPath]);
        } catch (_) {}
      }
    }
  }



  Future<Pet> addPet({
    required String name,
    required String type,
    String? gender,
    DateTime? birthday,
    String? breed,
    File? profileImage,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    // 이미지 검증
    if (profileImage != null) {
      final ext = profileImage.path.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        throw Exception('jpg, png 파일만 업로드할 수 있어요');
      }
      final size = await profileImage.length();
      if (size > _maxFileSizeBytes) {
        throw Exception('파일 크기는 5MB 이하여야 해요');
      }
    }

    String? storagePath;
    String? imageUrl;

    try {
      if (profileImage != null) {
        final ext = profileImage.path.split('.').last.toLowerCase();
        storagePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _supabase.storage.from('pet-photos').upload(storagePath, profileImage);
        imageUrl = _supabase.storage.from('pet-photos').getPublicUrl(storagePath);
      }

      final data = await _supabase.from('pets').insert({
        'owner_id': userId,
        'name': name,
        'type': type,
        'gender': gender,
        'birth_date': birthday?.toIso8601String().split('T').first,
        'breed': breed,
        'photo_url': imageUrl,
      }).select().single();

      return Pet.fromJson(data);
    } catch (e) {
      // DB 저장 실패 시 업로드된 이미지 정리
      if (storagePath != null) {
        try {
          await _supabase.storage.from('pet-photos').remove([storagePath]);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
