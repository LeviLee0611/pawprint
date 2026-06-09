import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';

class ChatService {
  final _client = Supabase.instance.client;

  String? get myId => _client.auth.currentUser?.id;

  Future<ChatRoom> getOrCreateRoom({
    required String postId,
    required String authorId,
  }) async {
    final uid = myId;
    if (uid == null) throw Exception('로그인이 필요해요');

    // 이미 존재하는 방 찾기
    final existing = await _client
        .from('chat_rooms')
        .select()
        .eq('post_id', postId)
        .eq('helper_id', uid)
        .maybeSingle();

    if (existing != null) return ChatRoom.fromJson(existing);

    // 새 방 생성
    final created = await _client
        .from('chat_rooms')
        .insert({
          'post_id': postId,
          'author_id': authorId,
          'helper_id': uid,
        })
        .select()
        .single();
    return ChatRoom.fromJson(created);
  }

  Future<List<ChatRoom>> getMyRooms() async {
    final uid = myId;
    if (uid == null) return [];

    final roomsData = await _client
        .from('chat_rooms')
        .select()
        .or('author_id.eq.$uid,helper_id.eq.$uid')
        .order('last_message_at', ascending: false) as List;

    if (roomsData.isEmpty) return [];

    final userIds = <String>{};
    final postIds = <String>{};
    for (final r in roomsData) {
      userIds.add(r['author_id'] as String);
      userIds.add(r['helper_id'] as String);
      postIds.add(r['post_id'] as String);
    }

    final profilesData = await _client
        .from('profiles')
        .select('id, display_name, avatar_url')
        .inFilter('id', userIds.toList()) as List;
    final profiles = {for (final p in profilesData) p['id']: p};

    final postsData = await _client
        .from('community_posts')
        .select('id, title, category')
        .inFilter('id', postIds.toList()) as List;
    final posts = {for (final p in postsData) p['id']: p};

    return roomsData.map((r) {
      final post = posts[r['post_id']];
      final author = profiles[r['author_id']];
      final helper = profiles[r['helper_id']];
      return ChatRoom.fromJson({
        ...r,
        'post_title': post?['title'],
        'post_category': post?['category'],
        'author_name': author?['display_name'],
        'author_avatar': author?['avatar_url'],
        'helper_name': helper?['display_name'],
        'helper_avatar': helper?['avatar_url'],
      });
    }).toList();
  }

  Future<List<ChatMessage>> getMessages(String roomId) async {
    final data = await _client
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at') as List;
    return data.map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<void> sendMessage(
    String roomId,
    String content, {
    String? recipientId,
    String? senderName,
    String? postTitle,
  }) async {
    final uid = myId;
    if (uid == null) throw Exception('로그인이 필요해요');
    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': uid,
      'content': content.trim(),
    });
    // last_message_at은 DB trigger(trg_chat_messages_last_message)가 자동 갱신
    if (recipientId != null) {
      _notifyChatMessage(
        recipientId: recipientId,
        senderName: senderName ?? '누군가',
        postTitle: postTitle,
      );
    }
  }

  Future<void> _notifyChatMessage({
    required String recipientId,
    required String senderName,
    String? postTitle,
  }) async {
    try {
      await _client.functions.invoke(
        'send-notification',
        body: {
          'trigger_type': 'new_chat_message',
          'recipient_id': recipientId,
          'sender_name': senderName,
          'post_title': postTitle,
        },
      );
    } catch (_) {}
  }

  RealtimeChannel subscribeToRoom(
      String roomId, void Function(ChatMessage) onMessage) {
    return _client
        .channel('chat_$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            try {
              final msg = ChatMessage.fromJson(payload.newRecord);
              onMessage(msg);
            } catch (_) {}
          },
        )
        .subscribe();
  }
}
