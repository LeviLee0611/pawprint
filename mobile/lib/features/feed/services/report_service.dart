import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final _supabase = Supabase.instance.client;

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('reports').insert({
      'reporter_id': userId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
    });
  }
}
