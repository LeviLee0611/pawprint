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

  Future<List<Post>> getPosts({
    int offset = 0,
    String? petType,
    List<String>? followingIds,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    final select = petType != null ? _postSelectPetFilter : _postSelect;
    var query = _supabase.from('posts').select(select).eq('is_hidden', false);

    // 팔로잉 필터: 내 글 + 팔로우한 사람 글
    if (followingIds != null) {
      final ids = [...followingIds, ?userId];
      query = query.inFilter('owner_id', ids);
    }

    // 펫 타입 필터: !inner JOIN으로 서버에서 완전히 제외
    if (petType != null) {
      query = query.eq('pets.type', petType);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + _pageSize - 1);

    final postIds = (data as List).map((e) => e['id'] as String).toList();
    Set<String> myLikes = {};
    Set<String> mySaves = {};
    if (userId != null && postIds.isNotEmpty) {
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
      myLikes = (results[0] as List).map((e) => e['post_id'] as String).toSet();
      mySaves = (results[1] as List).map((e) => e['post_id'] as String).toSet();
    }

    return (data as List)
        .map((e) => Post.fromJson(e,
            isLikedByMe: myLikes.contains(e['id']),
            isSavedByMe: mySaves.contains(e['id'])))
        .toList();
  }

  Future<List<Post>> getPopularPosts({
    int offset = 0,
    List<String>? blockedIds,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    var query = _supabase.from('posts').select(_postSelect).eq('is_hidden', false);

    // 차단 유저 게시글 제외
    if (blockedIds != null && blockedIds.isNotEmpty) {
      query = query.not('owner_id', 'in', '(${blockedIds.join(',')})');
    }

    final data = await query
        .order('likes_count', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + _pageSize - 1);

    final postIds = (data as List).map((e) => e['id'] as String).toList();
    Set<String> myLikes = {};
    Set<String> mySaves = {};
    if (userId != null && postIds.isNotEmpty) {
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
      myLikes = (results[0] as List).map((e) => e['post_id'] as String).toSet();
      mySaves = (results[1] as List).map((e) => e['post_id'] as String).toSet();
    }

    return (data as List)
        .map((e) => Post.fromJson(e,
            isLikedByMe: myLikes.contains(e['id']),
            isSavedByMe: mySaves.contains(e['id'])))
        .toList();
  }

  Future<List<Post>> getSavedPosts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final savesData = await _supabase
        .from('saves')
        .select('post_id, posts($_postSelect)')
        .eq('owner_id', userId)
        .eq('posts.is_hidden', false)
        .order('created_at', ascending: false);

    final postIds = (savesData as List).map((e) => e['post_id'] as String).toList();
    Set<String> myLikes = {};
    if (postIds.isNotEmpty) {
      final likesData = await _supabase
          .from('likes')
          .select('post_id')
          .eq('owner_id', userId)
          .inFilter('post_id', postIds);
      myLikes = (likesData as List).map((e) => e['post_id'] as String).toSet();
    }

    return (savesData as List)
        .where((e) => e['posts'] != null)
        .map((e) => Post.fromJson(
              e['posts'] as Map<String, dynamic>,
              isLikedByMe: myLikes.contains(e['post_id']),
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

    final results = await Future.wait([
      _supabase
          .from('posts')
          .select(_postSelect)
          .eq('owner_id', userId)
          .eq('is_hidden', false)
          .order('created_at', ascending: false),
      if (myId != null)
        _supabase.from('likes').select('post_id').eq('owner_id', myId),
    ]);

    final data = results[0] as List;
    final myLikes = myId != null
        ? (results[1] as List).map((e) => e['post_id'] as String).toSet()
        : <String>{};

    return data
        .map((e) => Post.fromJson(e, isLikedByMe: myLikes.contains(e['id'])))
        .toList();
  }

  Future<List<Post>> getMyPosts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final results = await Future.wait([
      _supabase
          .from('posts')
          .select(_postSelect)
          .eq('owner_id', userId)
          .eq('is_hidden', false)
          .order('created_at', ascending: false),
      _supabase.from('likes').select('post_id').eq('owner_id', userId),
    ]);

    final data = results[0] as List;
    final myLikes =
        (results[1] as List).map((e) => e['post_id'] as String).toSet();

    return data
        .map((e) => Post.fromJson(e, isLikedByMe: myLikes.contains(e['id'])))
        .toList();
  }

  Future<Post> updatePost({
    required String postId,
    required String content,
    List<String> keptImageUrls = const [],
    List<File> newImageFiles = const [],
    List<String> removedImageUrls = const [],
  }) async {
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

    bool isLiked = false;
    if (myId != null) {
      final like = await _supabase
          .from('likes')
          .select('id')
          .eq('post_id', postId)
          .eq('owner_id', myId)
          .maybeSingle();
      isLiked = like != null;
    }
    return Post.fromJson(data, isLikedByMe: isLiked);
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
    await _supabase.from('posts').delete().eq('id', postId);
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
