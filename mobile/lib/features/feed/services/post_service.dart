import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/content_filter.dart';
import '../../../core/utils/storage_path_util.dart';
import '../models/post_model.dart';

class PostService {
  final _supabase = Supabase.instance.client;

  static const _postSelect =
      '*, profiles:owner_id(display_name, avatar_url), pets:pet_id(name, type)';
  // petType 필터 시 !inner JOIN → pet 없거나 타입 불일치 게시글 서버에서 제외
  static const _postSelectPetFilter =
      '*, profiles:owner_id(display_name, avatar_url), pets!inner(name, type)';
  static const _commentSelect =
      '*, profiles:owner_id(display_name, avatar_url)';

  static const _pageSize = 20;

  /// 게시글 ID 목록에 대해 내 좋아요/저장 여부를 병렬로 조회
  Future<({Set<String> likes, Set<String> saves})> _fetchReactions(
      String userId, List<String> postIds) async {
    if (postIds.isEmpty) return (likes: <String>{}, saves: <String>{});
    final results = await Future.wait([
      _supabase
          .from('likes')
          .select('post_id')
          .eq('owner_id', userId)
          .inFilter('post_id', postIds),
      _supabase
          .from('saves')
          .select('post_id')
          .eq('owner_id', userId)
          .inFilter('post_id', postIds),
    ]);
    return (
      likes: (results[0] as List).map((e) => e['post_id'] as String).toSet(),
      saves: (results[1] as List).map((e) => e['post_id'] as String).toSet(),
    );
  }

  List<Post> _mapWithReactions(
    List data, {
    required Set<String> likes,
    required Set<String> saves,
  }) =>
      data
          .map((e) => Post.fromJson(e,
              isLikedByMe: likes.contains(e['id']),
              isSavedByMe: saves.contains(e['id'])))
          .toList();

  Future<List<Post>> getPosts({
    int offset = 0,
    String? petType,
    List<String>? followingIds,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    final select = petType != null ? _postSelectPetFilter : _postSelect;
    var query = _supabase.from('posts').select(select).eq('is_hidden', false);

    if (followingIds != null) {
      final ids = [...followingIds, ?userId];
      query = query.inFilter('owner_id', ids);
    }

    if (petType != null) {
      query = query.eq('pets.type', petType);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + _pageSize - 1) as List;

    final postIds = data.map((e) => e['id'] as String).toList();
    final reactions = userId != null
        ? await _fetchReactions(userId, postIds)
        : (likes: <String>{}, saves: <String>{});

    return _mapWithReactions(data, likes: reactions.likes, saves: reactions.saves);
  }

  Future<List<Post>> getPopularPosts({
    int offset = 0,
    List<String>? blockedIds,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    var query = _supabase.from('posts').select(_postSelect).eq('is_hidden', false);

    if (blockedIds != null && blockedIds.isNotEmpty) {
      query = query.not('owner_id', 'in', '(${blockedIds.join(',')})');
    }

    final data = await query
        .order('popular_score', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + _pageSize - 1) as List;

    final postIds = data.map((e) => e['id'] as String).toList();
    final reactions = userId != null
        ? await _fetchReactions(userId, postIds)
        : (likes: <String>{}, saves: <String>{});

    return _mapWithReactions(data, likes: reactions.likes, saves: reactions.saves);
  }

  Future<List<Post>> getSavedPosts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final savesData = await _supabase
        .from('saves')
        .select('post_id, posts($_postSelect)')
        .eq('owner_id', userId)
        .eq('posts.is_hidden', false)
        .order('created_at', ascending: false) as List;

    final visible = savesData.where((e) => e['posts'] != null).toList();
    final postIds = visible.map((e) => e['post_id'] as String).toList();
    final reactions = await _fetchReactions(userId, postIds);

    return visible
        .map((e) => Post.fromJson(
              e['posts'] as Map<String, dynamic>,
              isLikedByMe: reactions.likes.contains(e['post_id']),
              isSavedByMe: true,
            ))
        .toList();
  }

  Future<bool> toggleSave(String postId) async {
    final userId = _supabase.auth.currentUser!.id;
    final existing = await _supabase
        .from('saves')
        .select('id')
        .eq('post_id', postId)
        .eq('owner_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _supabase.from('saves').delete().eq('id', existing['id']);
      return false;
    } else {
      await _supabase.from('saves').insert({'post_id': postId, 'owner_id': userId});
      return true;
    }
  }

  Future<List<Post>> getPostsByUser(String userId) async {
    final myId = _supabase.auth.currentUser?.id;

    final data = await _supabase
        .from('posts')
        .select(_postSelect)
        .eq('owner_id', userId)
        .eq('is_hidden', false)
        .order('created_at', ascending: false) as List;

    final postIds = data.map((e) => e['id'] as String).toList();
    final reactions = myId != null
        ? await _fetchReactions(myId, postIds)
        : (likes: <String>{}, saves: <String>{});

    return _mapWithReactions(data, likes: reactions.likes, saves: reactions.saves);
  }

  Future<List<Post>> getMyPosts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _supabase
        .from('posts')
        .select(_postSelect)
        .eq('owner_id', userId)
        .eq('is_hidden', false)
        .order('created_at', ascending: false) as List;

    final postIds = data.map((e) => e['id'] as String).toList();
    final reactions = await _fetchReactions(userId, postIds);

    return _mapWithReactions(data, likes: reactions.likes, saves: reactions.saves);
  }

  Future<Post> updatePost({
    required String postId,
    required String content,
    List<String> keptImageUrls = const [],
    List<File> newImageFiles = const [],
    List<String> removedImageUrls = const [],
  }) async {
    final filtered = ContentFilter.check(content);
    if (filtered != null) throw Exception(filtered);

    final userId = _supabase.auth.currentUser!.id;
    final uploadedUrls = <String>[];
    final uploadedPaths = <String>[];

    if (newImageFiles.isNotEmpty) {
      // 새 이미지 병렬 업로드
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final results = await Future.wait(
        List.generate(newImageFiles.length, (i) async {
          final file = newImageFiles[i];
          final ext = file.path.split('.').last.toLowerCase();
          final path = '$userId/${timestamp}_edit_$i.$ext';
          await _supabase.storage.from('post-images').upload(path, file);
          return MapEntry(
              path, _supabase.storage.from('post-images').getPublicUrl(path));
        }),
      );
      for (final e in results) {
        uploadedPaths.add(e.key);
        uploadedUrls.add(e.value);
      }

      // 새 이미지 검열
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

    final finalUrls = [...keptImageUrls, ...uploadedUrls];

    try {
      final data = await _supabase
          .from('posts')
          .update({
            'content': content,
            'image_url': finalUrls.isNotEmpty ? finalUrls.first : null,
            'image_urls': finalUrls,
          })
          .eq('id', postId)
          .select(_postSelect)
          .single();

      // DB 성공 후 삭제된 이미지 Storage에서 제거
      if (removedImageUrls.isNotEmpty) {
        final paths = removedImageUrls
            .map((url) => StoragePathUtil.fromUrl(url, 'post-images'))
            .whereType<String>()
            .toList();
        if (paths.isNotEmpty) {
          try { await _supabase.storage.from('post-images').remove(paths); } catch (_) {}
        }
      }

      return Post.fromJson(data);
    } catch (e) {
      if (uploadedPaths.isNotEmpty) {
        try { await _supabase.storage.from('post-images').remove(uploadedPaths); } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Post?> getPostById(String postId) async {
    final myId = _supabase.auth.currentUser?.id;
    final data = await _supabase
        .from('posts')
        .select(_postSelect)
        .eq('id', postId)
        .eq('is_hidden', false)
        .maybeSingle();
    if (data == null) return null;

    final reactions = myId != null
        ? await _fetchReactions(myId, [postId])
        : (likes: <String>{}, saves: <String>{});

    return Post.fromJson(data,
        isLikedByMe: reactions.likes.contains(postId),
        isSavedByMe: reactions.saves.contains(postId));
  }

  Future<Post> addPost({
    required String? petId,
    required String content,
    List<File>? imageFiles,
  }) async {
    final filtered = ContentFilter.check(content);
    if (filtered != null) throw Exception(filtered);

    final userId = _supabase.auth.currentUser!.id;
    final uploadedUrls = <String>[];
    final uploadedPaths = <String>[];

    final files = imageFiles ?? [];
    if (files.isNotEmpty) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final results = await Future.wait(
        List.generate(files.length, (i) async {
          final file = files[i];
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
        // Vision API 오류는 무시하고 진행
      }
    }

    try {
      final data = await _supabase
          .from('posts')
          .insert({
            'owner_id': userId,
            'pet_id': petId,
            'content': content,
            'image_url': uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
            'image_urls': uploadedUrls,
          })
          .select(_postSelect)
          .single();
      final post = Post.fromJson(data);
      _notifyNewPost(userId, post.ownerName);
      return post;
    } catch (e) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _supabase.storage.from('post-images').remove(uploadedPaths);
        } catch (_) {}
      }
      rethrow;
    }
  }

  void _notifyNewPost(String ownerId, String? ownerName) {
    unawaited(_sendNewPostNotification(ownerId, ownerName));
  }

  Future<void> _sendNewPostNotification(String ownerId, String? ownerName) async {
    try {
      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'trigger_type': 'new_post',
          'post_owner_id': ownerId,
          'owner_name': ownerName ?? '누군가',
        },
      );
    } catch (_) {}
  }

  Future<void> deletePost(String postId, {List<String>? imageUrls}) async {
    await _supabase.from('posts').delete().eq('id', postId);
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
  }

  /// Returns true if newly liked, false if unliked.
  Future<bool> toggleLike(String postId) async {
    final userId = _supabase.auth.currentUser!.id;
    final existing = await _supabase
        .from('likes')
        .select('id')
        .eq('post_id', postId)
        .eq('owner_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _supabase.from('likes').delete().eq('id', existing['id']);
      return false;
    } else {
      await _supabase
          .from('likes')
          .insert({'post_id': postId, 'owner_id': userId});
      return true;
    }
  }

  Future<List<Comment>> getComments(String postId) async {
    final data = await _supabase
        .from('comments')
        .select(_commentSelect)
        .eq('post_id', postId)
        .order('created_at');
    return (data as List).map((e) => Comment.fromJson(e)).toList();
  }

  Future<Comment> addComment(String postId, String content,
      {String? parentId}) async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('comments')
        .insert({
          'post_id': postId,
          'owner_id': userId,
          'content': content,
          // ignore: use_null_aware_elements
          if (parentId != null) 'parent_id': parentId,
        })
        .select(_commentSelect)
        .single();
    return Comment.fromJson(data);
  }

  Future<void> deleteComment(String commentId) async {
    await _supabase.from('comments').delete().eq('id', commentId);
  }

}
