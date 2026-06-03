import 'package:supabase_flutter/supabase_flutter.dart';

class FollowService {
  final _supabase = Supabase.instance.client;

  /// Returns true if newly followed, false if unfollowed.
  Future<bool> toggleFollow(String targetUserId) async {
    final myId = _supabase.auth.currentUser!.id;
    final existing = await _supabase
        .from('follows')
        .select('id')
        .eq('follower_id', myId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    if (existing != null) {
      await _supabase.from('follows').delete().eq('id', existing['id']);
      return false;
    } else {
      await _supabase.from('follows').insert({
        'follower_id': myId,
        'following_id': targetUserId,
      });
      return true;
    }
  }

  Future<bool> isFollowing(String targetUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return false;
    final result = await _supabase
        .from('follows')
        .select('id')
        .eq('follower_id', myId)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return result != null;
  }

  /// 팔로워 목록 (나를 팔로우하는 유저)
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final follows = await _supabase
        .from('follows')
        .select('follower_id')
        .eq('following_id', userId);
    final ids = (follows as List).map((e) => e['follower_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles = await _supabase
        .from('profiles')
        .select('id, display_name, avatar_url')
        .inFilter('id', ids);
    return (profiles as List).map((e) => {
      'id': e['id'] as String,
      'display_name': e['display_name'] as String? ?? '사용자',
      'avatar_url': e['avatar_url'] as String?,
    }).toList();
  }

  /// 팔로잉 목록 (내가 팔로우하는 유저)
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final follows = await _supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    final ids = (follows as List).map((e) => e['following_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles = await _supabase
        .from('profiles')
        .select('id, display_name, avatar_url')
        .inFilter('id', ids);
    return (profiles as List).map((e) => {
      'id': e['id'] as String,
      'display_name': e['display_name'] as String? ?? '사용자',
      'avatar_url': e['avatar_url'] as String?,
    }).toList();
  }

  Future<List<String>> getFollowingIds() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];
    final data = await _supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', myId);
    return (data as List)
        .map((e) => e['following_id'] as String)
        .toList();
  }

  /// Returns {followers: N, following: N} for the given user.
  Future<Map<String, int>> getFollowCounts(String userId) async {
    final results = await Future.wait([
      _supabase
          .from('follows')
          .select('id')
          .eq('following_id', userId)
          .count(CountOption.exact),
      _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .count(CountOption.exact),
    ]);
    return {
      'followers': (results[0] as PostgrestResponse).count,
      'following': (results[1] as PostgrestResponse).count,
    };
  }
}
