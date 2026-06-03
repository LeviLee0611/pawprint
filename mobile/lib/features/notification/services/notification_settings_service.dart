import 'package:supabase_flutter/supabase_flutter.dart';

enum NotifLevel { everyone, followingOnly, off }

extension NotifLevelX on NotifLevel {
  String toJson() {
    switch (this) {
      case NotifLevel.everyone: return 'everyone';
      case NotifLevel.followingOnly: return 'following_only';
      case NotifLevel.off: return 'off';
    }
  }

  static NotifLevel fromJson(String? v) {
    switch (v) {
      case 'following_only': return NotifLevel.followingOnly;
      case 'off': return NotifLevel.off;
      default: return NotifLevel.everyone;
    }
  }

  String get label {
    switch (this) {
      case NotifLevel.everyone: return '모든 사람';
      case NotifLevel.followingOnly: return '팔로우한 사람만';
      case NotifLevel.off: return '끄기';
    }
  }
}

class NotificationSettings {
  final NotifLevel likeSetting;
  final NotifLevel commentSetting;
  final bool followEnabled;
  final bool newPostEnabled;

  const NotificationSettings({
    this.likeSetting = NotifLevel.everyone,
    this.commentSetting = NotifLevel.everyone,
    this.followEnabled = true,
    this.newPostEnabled = true,
  });

  NotificationSettings copyWith({
    NotifLevel? likeSetting,
    NotifLevel? commentSetting,
    bool? followEnabled,
    bool? newPostEnabled,
  }) =>
      NotificationSettings(
        likeSetting: likeSetting ?? this.likeSetting,
        commentSetting: commentSetting ?? this.commentSetting,
        followEnabled: followEnabled ?? this.followEnabled,
        newPostEnabled: newPostEnabled ?? this.newPostEnabled,
      );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        likeSetting: NotifLevelX.fromJson(json['like_setting'] as String?),
        commentSetting: NotifLevelX.fromJson(json['comment_setting'] as String?),
        followEnabled: json['follow_enabled'] as bool? ?? true,
        newPostEnabled: json['new_post_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'like_setting': likeSetting.toJson(),
        'comment_setting': commentSetting.toJson(),
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
