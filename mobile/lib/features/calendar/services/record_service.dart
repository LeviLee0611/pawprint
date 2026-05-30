import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/record_model.dart';

class RecordService {
  final _supabase = Supabase.instance.client;

  Future<List<Record>> getRecordsForMonth(
      String petId, int year, int month) async {
    final lastDay = DateTime(year, month + 1, 0).day;
    final start =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    final end =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    final data = await _supabase
        .from('records')
        .select()
        .eq('pet_id', petId)
        .gte('date', start)
        .lte('date', end)
        .order('created_at');

    return (data as List).map((e) => Record.fromJson(e)).toList();
  }

  Future<void> addRecord({
    required String petId,
    required DateTime date,
    required String type,
    String? notes,
    double? value,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    await _supabase.from('records').insert({
      'pet_id': petId,
      'owner_id': userId,
      'date': dateStr,
      'type': type,
      'notes': notes,
      'value': value,
    });
  }

  Future<int> getTotalRecordCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    final response = await _supabase
        .from('records')
        .select('id')
        .eq('owner_id', userId)
        .count(CountOption.exact);
    return response.count;
  }

  Future<List<Record>> getAllRecords() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _supabase
        .from('records')
        .select()
        .eq('owner_id', userId)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Record.fromJson(e)).toList();
  }

  Future<void> deleteRecord(String id) async {
    await _supabase.from('records').delete().eq('id', id);
  }
}
