import 'package:supabase_flutter/supabase_flutter.dart';

class ReminderService {
  final _supabase = Supabase.instance.client;

  Future<void> addReminder({
    required String petId,
    required String title,
    required DateTime remindAt,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final dateStr =
        '${remindAt.year.toString().padLeft(4, '0')}-${remindAt.month.toString().padLeft(2, '0')}-${remindAt.day.toString().padLeft(2, '0')}';
    await _supabase.from('reminders').insert({
      'owner_id': userId,
      'pet_id': petId,
      'title': title,
      'remind_at': dateStr,
    });
  }

  Future<List<Map<String, dynamic>>> getMyReminders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _supabase
        .from('reminders')
        .select()
        .eq('owner_id', userId)
        .eq('sent', false)
        .order('remind_at');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> deleteReminder(String id) async {
    await _supabase.from('reminders').delete().eq('id', id);
  }
}
