import 'package:supabase_flutter/supabase_flutter.dart';

class ReminderService {
  final _supabase = Supabase.instance.client;

  Future<void> addReminder({
    required String petId,
    required String title,
    required DateTime remindAt,
    String? recordId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final iso = remindAt.toUtc().toIso8601String();
    await _supabase.from('reminders').insert({
      'owner_id': userId,
      'pet_id': petId,
      'title': title,
      'remind_at': iso,
      'sent': false,
      if (recordId != null) 'record_id': recordId,
    });
  }

  Future<List<Map<String, dynamic>>> getMyReminders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _supabase
        .from('reminders')
        .select('*, pets(name, type)')
        .eq('owner_id', userId)
        .or('sent.eq.false,sent.is.null')
        .order('remind_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateReminder(String id, {required DateTime remindAt, String? title}) async {
    final iso = remindAt.toUtc().toIso8601String();
    await _supabase.from('reminders').update({
      'remind_at': iso,
      if (title != null) 'title': title,
    }).eq('id', id);
  }

  Future<void> deleteReminder(String id) async {
    await _supabase.from('reminders').delete().eq('id', id);
  }
}
