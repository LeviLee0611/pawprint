import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/storage_path_util.dart';
import '../models/post_model.dart';

class PostService {
  final _supabase = Supabase.instance.client;

  static const _postSelect =
      '*, profiles:owner_id(display_name, avatar_url), pets:pet_id(name, type)';
  static const _commentSelect =
      '*, profiles:owner_id(display_name, avatar_url)';

  static const _pageSize = 20;

  Future<List<Post>> getPosts({
    int offset = 0,
    String? petType,
    List<String>? followingIds,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    var query = _supabase.from('posts').select(_postSelect);

    // 팔로잉 필터: 내 글 + 팔로우한 사람 글
    if (followingIds != null) {
      final ids = [...followingIds, ?userId];
      query = query.inFilter('owner_id', ids);
    }

    // 펫 타입 필터: pets 테이블 join 기준
    if (petType != null) {
      query = query.eq('pets.type', petType);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + _pageSize - 1);

    // 로드된 게시글 ID에 한해서만 좋아요 조회 (전체 X)
    Set<String> myLikes = {};
    if (userId != null && (data as List).isNotEmpty) {
      final postIds = data.map((e) => e['id'] as String).toList();
      final likesData = await _supabase
          .from('likes')
          .select('post_id')
          .eq('owner_id', userId)
          .inFilter('post_id', postIds);
      myLikes =
          (likesData as List).map((e) => e['post_id'] as String).toSet();
    }

    return (data as List)
        .map((e) =>
            Post.fromJson(e, isLikedByMe: myLikes.contains(e['id'])))
        .toList();
  }

  Future<List<Post>> getPostsByUser(String userId) async {
    final myId = _supabase.auth.currentUser?.id;

    final results = await Future.wait([
      _supabase
          .from('posts')
          .select(_postSelect)
          .eq('owner_id', userId)
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
    File? newImageFile,
    String? existingImageUrl,
    bool removeImage = false,
  }) async {
    String? newImageUrl = existingImageUrl;
    String? newStoragePath;

    if (newImageFile != null) {
      final userId = _supabase.auth.currentUser!.id;
      final ext = newImageFile.path.split('.').last.toLowerCase();
      newStoragePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage
          .from('post-images')
          .upload(newStoragePath, newImageFile);
      newImageUrl =
          _supabase.storage.from('post-images').getPublicUrl(newStoragePath);
    } else if (removeImage && existingImageUrl != null) {
      newImageUrl = null;
    }

    try {
      final data = await _supabase
          .from('posts')
          .update({'content': content, 'image_url': newImageUrl})
          .eq('id', postId)
          .select(_postSelect)
          .single();

      // DB 성공 후 기존 이미지 삭제
      if (newImageFile != null && existingImageUrl != null) {
        final oldPath = StoragePathUtil.fromUrl(existingImageUrl, 'post-images');
        if (oldPath != null) {
          try { await _supabase.storage.from('post-images').remove([oldPath]); } catch (_) {}
        }
      } else if (removeImage && existingImageUrl != null) {
        final path = StoragePathUtil.fromUrl(existingImageUrl, 'post-images');
        if (path != null) {
          try { await _supabase.storage.from('post-images').remove([path]); } catch (_) {}
        }
      }

      return Post.fromJson(data);
    } catch (e) {
      if (newStoragePath != null) {
        try {
          await _supabase.storage.from('post-images').remove([newStoragePath]);
        } catch (_) {}
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
    File? imageFile,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    String? imageUrl;
    String? storagePath;

    if (imageFile != null) {
      final ext = imageFile.path.split('.').last.toLowerCase();
      storagePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage
          .from('post-images')
          .upload(storagePath, imageFile);
      imageUrl = _supabase.storage
          .from('post-images')
          .getPublicUrl(storagePath);
    }

    try {
      final data = await _supabase
          .from('posts')
          .insert({
            'owner_id': userId,
            'pet_id': petId,
            'content': content,
            'image_url': imageUrl,
          })
          .select(_postSelect)
          .single();
      return Post.fromJson(data);
    } catch (e) {
      if (storagePath != null) {
        try {
          await _supabase.storage
              .from('post-images')
              .remove([storagePath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// imageUrl을 받아서 Storage 파일도 같이 삭제
  Future<void> deletePost(String postId, {String? imageUrl}) async {
    if (imageUrl != null) {
      final path = StoragePathUtil.fromUrl(imageUrl, 'post-images');
      if (path != null) {
        try {
          await _supabase.storage.from('post-images').remove([path]);
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
