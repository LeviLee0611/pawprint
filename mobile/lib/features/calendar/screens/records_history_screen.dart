import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/record_model.dart';
import '../services/record_service.dart';

class RecordsHistoryScreen extends StatefulWidget {
  const RecordsHistoryScreen({super.key});

  @override
  State<RecordsHistoryScreen> createState() => _RecordsHistoryScreenState();
}

class _RecordsHistoryScreenState extends State<RecordsHistoryScreen> {
  final _recordService = RecordService();
  List<Record> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await _recordService.getAllRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _delete(Record r) async {
    await _recordService.deleteRecord(r.id);
    if (!mounted) return;
    setState(() => _records.removeWhere((x) => x.id == r.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('전체 기록')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _records.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📝', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('아직 기록이 없어요',
                          style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, i) {
                      final r = _records[i];
                      final showDate = i == 0 ||
                          !isSameDay(_records[i - 1].date, r.date);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDate)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 12, bottom: 6),
                              child: Text(
                                DateFormat('yyyy년 M월 d일 (E)', 'ko')
                                    .format(r.date),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textHint,
                                    letterSpacing: 0.3),
                              ),
                            ),
                          _RecordCard(
                            record: r,
                            onDelete: () => _delete(r),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _RecordCard extends StatelessWidget {
  final Record record;
  final VoidCallback onDelete;

  const _RecordCard({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(record.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                if (record.value != null)
                  Text('${record.value} kg',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                if (record.notes != null && record.notes!.isNotEmpty)
                  Text(record.notes!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child:
                  Icon(Icons.close, size: 16, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }
}
