import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackService {
  final _supabase = Supabase.instance.client;

  Future<void> submit({
    required String category,
    required String content,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase.from('app_feedback').insert({
      'user_id': userId,
      'category': category,
      'content': content,
    });
  }
}
