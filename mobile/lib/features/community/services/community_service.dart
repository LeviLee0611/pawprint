import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/content_filter.dart';
import '../../../core/utils/storage_path_util.dart';
import '../models/community_post_model.dart';
import '../models/sighting_report_model.dart';

class CommunityService {
  final _supabase = Supabase.instance.client;
  static const _select = '*, profiles:owner_id(display_name, avatar_url)';
  static const pageSize = 30;

  Future<List<CommunityPost>> getPosts({List<String>? categories, int offset = 0}) async {
    var query = _supabase
        .from('community_posts')
        .select(_select)
        .neq('status', 'hidden');

    if (categories != null && categories.isNotEmpty) {
      query = query.inFilter('category', categories);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1);
    return (data as List)
        .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SightingReport>> getSightings(String postId) async {
    final data = await _supabase
        .from('sighting_reports')
        .select('*, profiles:reporter_id(display_name, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => SightingReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addSighting({
    required String postId,
    String? address,
    double? latitude,
    double? longitude,
    String? note,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요해요');
    await _supabase.from('sighting_reports').insert({
      'post_id': postId,
      'reporter_id': userId,
      if (address != null && address.isNotEmpty) 'address': address,
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> addPost({
    required String category,
    required String title,
    required String content,
    String? petName,
    String? petType,
    String? location,
    String? contact,
    String? address,
    double? latitude,
    double? longitude,
    List<File>? imageFiles,
  }) async {
    final filtered = ContentFilter.check('$title $content');
    if (filtered != null) throw Exception(filtered);

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요해요');

    final uploadedPaths = <String>[];
    final uploadedUrls = <String>[];

    try {
      if (imageFiles != null && imageFiles.isNotEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final results = await Future.wait(
          List.generate(imageFiles.length, (i) async {
            final file = imageFiles[i];
            final ext = file.path.split('.').last.toLowerCase();
            final path = '$userId/${timestamp}_$i.$ext';
            await _supabase.storage.from('post-images').upload(path, file);
            return MapEntry(path, _supabase.storage.from('post-images').getPublicUrl(path));
          }),
        );
        for (final e in results) {
          uploadedPaths.add(e.key);
          uploadedUrls.add(e.value);
        }
      }

      // 이미지 부적절 콘텐츠 검사
      if (uploadedUrls.isNotEmpty) {
        try {
          final result = await _supabase.functions.invoke(
            'moderate-images',
            body: {'imageUrls': uploadedUrls},
          );
          final body = result.data as Map<String, dynamic>?;
          if (body != null && body['safe'] == false) {
            await _supabase.storage.from('post-images').remove(uploadedPaths);
            throw Exception(body['reason'] ?? '부적절한 콘텐츠가 감지됐어요');
          }
        } catch (e) {
          if (e is Exception && e.toString().contains('부적절한')) rethrow;
        }
      }

      await _supabase.from('community_posts').insert({
        'owner_id': userId,
        'category': category,
        'title': title,
        'content': content,
        'image_urls': uploadedUrls,
        if (petName != null && petName.isNotEmpty) 'pet_name': petName,
        'pet_type': ?petType,
        if (location != null && location.isNotEmpty) 'location': location,
        if (contact != null && contact.isNotEmpty) 'contact': contact,
        if (address != null && address.isNotEmpty) 'address': address,
        'latitude': ?latitude,
        'longitude': ?longitude,
      });
    } catch (e) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _supabase.storage.from('post-images').remove(uploadedPaths);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<CommunityPost> updatePost({
    required String postId,
    required String title,
    required String content,
    String? petName,
    String? petType,
    String? location,
    String? contact,
    String? address,
    double? latitude,
    double? longitude,
    String? status,
  }) async {
    final data = await _supabase
        .from('community_posts')
        .update({
          'title': title,
          'content': content,
          'pet_name': petName?.isNotEmpty == true ? petName : null,
          'pet_type': petType,
          'location': location?.isNotEmpty == true ? location : null,
          'contact': contact?.isNotEmpty == true ? contact : null,
          'address': address?.isNotEmpty == true ? address : null,
          'latitude': ?latitude,
          'longitude': ?longitude,
          'status': ?status,
        })
        .eq('id', postId)
        .select('*, profiles:owner_id(display_name, avatar_url)')
        .single();
    return CommunityPost.fromJson(data);
  }

  Future<void> resolvePost(String postId) async {
    await _supabase
        .from('community_posts')
        .update({'status': 'resolved'})
        .eq('id', postId);
  }

  Future<CommunityPost?> getPostById(String postId) async {
    final data = await _supabase
        .from('community_posts')
        .select(_select)
        .eq('id', postId)
        .maybeSingle();
    if (data == null) return null;
    return CommunityPost.fromJson(data);
  }

  Future<void> deletePost(String postId, {List<String>? imageUrls}) async {
    if (imageUrls != null && imageUrls.isNotEmpty) {
      final paths = imageUrls
          .map((url) => StoragePathUtil.fromUrl(url, 'post-images'))
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        try {
          await _supabase.storage.from('post-images').remove(paths);
        } catch (_) {}
      }
    }
    await _supabase.from('community_posts').delete().eq('id', postId);
  }
}
