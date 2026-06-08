import 'package:supabase_flutter/supabase_flutter.dart';
import '../../feed/models/post_model.dart';

class SearchService {
  final _supabase = Supabase.instance.client;

  static const _postSelect =
      '*, profiles:owner_id(display_name, avatar_url), pets:pet_id(name, type)';

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final myId = _supabase.auth.currentUser?.id ?? '';
    final data = await _supabase
        .from('profiles')
        .select('id, display_name, avatar_url')
        .ilike('display_name', '%$query%')
        .neq('id', myId)
        .limit(30);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Post>> searchPosts(String query) async {
    final myId = _supabase.auth.currentUser?.id;
    final raw = await _supabase
        .from('posts')
        .select(_postSelect)
        .ilike('content', '%$query%')
        .eq('is_hidden', false)
        .order('created_at', ascending: false)
        .limit(30);

    final data = raw as List;

    Set<String> myLikes = {};
    if (myId != null && data.isNotEmpty) {
      final postIds = data.map((e) => e['id'] as String).toList();
      final likesData = await _supabase
          .from('likes')
          .select('post_id')
          .eq('owner_id', myId)
          .inFilter('post_id', postIds);
      myLikes =
          (likesData as List).map((e) => e['post_id'] as String).toSet();
    }

    return data
        .map((e) => Post.fromJson(
              e as Map<String, dynamic>,
              isLikedByMe: myLikes.contains(e['id']),
            ))
        .toList();
  }
}
