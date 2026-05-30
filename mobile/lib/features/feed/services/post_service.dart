import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';

class PostService {
  final _supabase = Supabase.instance.client;

  static const _postSelect =
      '*, profiles:owner_id(display_name, avatar_url), pets:pet_id(name, type)';
  static const _commentSelect =
      '*, profiles:owner_id(display_name, avatar_url)';

  Future<List<Post>> getPosts() async {
    final userId = _supabase.auth.currentUser?.id;

    final data = await _supabase
        .from('posts')
        .select(_postSelect)
        .order('created_at', ascending: false);

    Set<String> myLikes = {};
    if (userId != null) {
      final likesData = await _supabase
          .from('likes')
          .select('post_id')
          .eq('owner_id', userId);
      myLikes =
          (likesData as List).map((e) => e['post_id'] as String).toSet();
    }

    return (data as List)
        .map((e) =>
            Post.fromJson(e, isLikedByMe: myLikes.contains(e['id'])))
        .toList();
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
      final path = _storagePath(imageUrl, 'post-images');
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

  Future<Comment> addComment(String postId, String content) async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('comments')
        .insert({'post_id': postId, 'owner_id': userId, 'content': content})
        .select(_commentSelect)
        .single();
    return Comment.fromJson(data);
  }

  Future<void> deleteComment(String commentId) async {
    await _supabase.from('comments').delete().eq('id', commentId);
  }

  /// Supabase public URL에서 storage path 추출
  /// e.g. ".../object/public/post-images/uid/file.jpg" → "uid/file.jpg"
  String? _storagePath(String url, String bucket) {
    final marker = '/object/public/$bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    return url.substring(idx + marker.length);
  }
}
