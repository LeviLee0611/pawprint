import 'package:supabase_flutter/supabase_flutter.dart';

class BlockService {
  final _supabase = Supabase.instance.client;

  Future<List<String>> getBlockedIds() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];
    final data = await _supabase
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', myId);
    return (data as List).map((e) => e['blocked_id'] as String).toList();
  }

  Future<bool> isBlocked(String userId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return false;
    final result = await _supabase
        .from('blocks')
        .select('id')
        .eq('blocker_id', myId)
        .eq('blocked_id', userId)
        .maybeSingle();
    return result != null;
  }

  /// true = 차단됨, false = 차단 해제됨
  Future<bool> toggleBlock(String userId) async {
    final myId = _supabase.auth.currentUser!.id;
    final existing = await _supabase
        .from('blocks')
        .select('id')
        .eq('blocker_id', myId)
        .eq('blocked_id', userId)
        .maybeSingle();

    if (existing != null) {
      // 차단 해제: 직접 삭제
      await _supabase.from('blocks').delete().eq('id', existing['id']);
      return false;
    } else {
      // 차단: RPC로 처리 (팔로우 관계 정리도 SECURITY DEFINER로 안전하게)
      await _supabase.rpc('block_user', params: {'blocked_user_id': userId});
      return true;
    }
  }
}
