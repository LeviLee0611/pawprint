import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettings {
  final bool likeEnabled;
  final bool commentEnabled;
  final bool followEnabled;
  final bool newPostEnabled;

  const NotificationSettings({
    this.likeEnabled = true,
    this.commentEnabled = true,
    this.followEnabled = true,
    this.newPostEnabled = true,
  });

  NotificationSettings copyWith({
    bool? likeEnabled,
    bool? commentEnabled,
    bool? followEnabled,
    bool? newPostEnabled,
  }) =>
      NotificationSettings(
        likeEnabled: likeEnabled ?? this.likeEnabled,
        commentEnabled: commentEnabled ?? this.commentEnabled,
        followEnabled: followEnabled ?? this.followEnabled,
        newPostEnabled: newPostEnabled ?? this.newPostEnabled,
      );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        likeEnabled: json['like_enabled'] as bool? ?? true,
        commentEnabled: json['comment_enabled'] as bool? ?? true,
        followEnabled: json['follow_enabled'] as bool? ?? true,
        newPostEnabled: json['new_post_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'like_enabled': likeEnabled,
        'comment_enabled': commentEnabled,
        'follow_enabled': followEnabled,
        'new_post_enabled': newPostEnabled,
      };
}

class NotificationSettingsService {
  final _supabase = Supabase.instance.client;

  Future<NotificationSettings> getSettings() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('notification_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return const NotificationSettings();
    return NotificationSettings.fromJson(data);
  }

  Future<void> saveSettings(NotificationSettings settings) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('notification_settings').upsert({
      'user_id': userId,
      ...settings.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
