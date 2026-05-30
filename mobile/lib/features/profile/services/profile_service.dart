import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final _supabase = Supabase.instance.client;

  Future<void> updateProfile({
    required String name,
    File? photoFile,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    String? photoUrl;

    if (photoFile != null) {
      final ext = photoFile.path.split('.').last.toLowerCase();
      final path = 'avatars/$userId.$ext';
      await _supabase.storage
          .from('pet-photos')
          .upload(path, photoFile,
              fileOptions: const FileOptions(upsert: true));
      photoUrl =
          _supabase.storage.from('pet-photos').getPublicUrl(path);
    }

    // 1. auth 메타데이터 업데이트 (현재 세션 + 피드 내 이름 주입용)
    final metaUpdate = <String, dynamic>{'full_name': name};
    if (photoUrl != null) metaUpdate['avatar_url'] = photoUrl;
    await _supabase.auth.updateUser(UserAttributes(data: metaUpdate));

    // 2. profiles 테이블 업데이트 (display_name — 다른 유저에게 보이는 이름)
    final profileUpdate = <String, dynamic>{
      'id': userId,
      'display_name': name,
    };
    if (photoUrl != null) profileUpdate['avatar_url'] = photoUrl;
    await _supabase.from('profiles').upsert(profileUpdate);
  }
}
