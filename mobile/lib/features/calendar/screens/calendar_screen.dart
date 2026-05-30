import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/record_model.dart';
import '../services/record_service.dart';
import '../screens/add_record_screen.dart';
import '../widgets/record_bottom_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../pet/models/pet_model.dart';
import '../../pet/screens/add_pet_screen.dart';
import '../../pet/services/pet_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _petService = PetService();
  final _recordService = RecordService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Pet? _currentPet;
  bool _loadingPet = true;
  Map<DateTime, List<Record>> _recordsByDate = {};

  @override
  void initState() {
    super.initState();
    _loadPet();
  }

  Future<void> _loadPet() async {
    final pets = await _petService.getMyPets();
    if (!mounted) return;
    setState(() {
      _currentPet = pets.isNotEmpty ? pets.first : null;
      _loadingPet = false;
    });
    if (_currentPet != null) {
      await _loadRecords(_focusedDay.year, _focusedDay.month);
    }
  }

  Future<void> _loadRecords(int year, int month) async {
    if (_currentPet == null) return;
    final records =
        await _recordService.getRecordsForMonth(_currentPet!.id, year, month);
    if (!mounted) return;
    final map = <DateTime, List<Record>>{};
    for (final r in records) {
      final key = DateTime(r.date.year, r.date.month, r.date.day);
      (map[key] ??= []).add(r);
    }
    setState(() => _recordsByDate = map);
  }

  List<Record> _getEventsForDay(DateTime day) {
    return _recordsByDate[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  Future<void> _showRecordSheet(DateTime date) async {
    final selectedType = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RecordBottomSheet(date: date),
    );

    if (selectedType == null || !mounted) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecordScreen(
          date: date,
          pet: _currentPet!,
          type: selectedType,
        ),
      ),
    );

    if (saved == true) {
      await _loadRecords(_focusedDay.year, _focusedDay.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPet) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🐾 냥발도장'),
            if (_currentPet != null) ...[
              const SizedBox(width: 8),
              Text(
                '${_currentPet!.emoji} ${_currentPet!.name}',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
        actions: [
          if (_currentPet != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.primary,
              tooltip: '기록 추가',
              onPressed: () =>
                  _showRecordSheet(_selectedDay ?? DateTime.now()),
            ),
        ],
      ),
      body: _currentPet == null ? _buildNoPetState() : _buildCalendar(),
    );
  }

  Widget _buildNoPetState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🐾', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              '아직 등록된 아이가 없어요',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              '펫을 등록하고 매일 기록을 남겨보세요',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddPetScreen(isOnboarding: false)),
                );
                await _loadPet();
              },
              child: const Text('펫 등록하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final selectedRecords =
        _selectedDay != null ? _getEventsForDay(_selectedDay!) : <Record>[];

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TableCalendar<Record>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            eventLoader: _getEventsForDay,
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadRecords(focusedDay.year, focusedDay.month);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                  color: AppColors.primaryDark, fontWeight: FontWeight.bold),
              weekendTextStyle: TextStyle(color: AppColors.peach),
              markersMaxCount: 1,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              leftChevronIcon:
                  Icon(Icons.chevron_left, color: AppColors.brown),
              rightChevronIcon:
                  Icon(Icons.chevron_right, color: AppColors.brown),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12),
              weekendStyle: TextStyle(color: AppColors.peach, fontSize: 12),
            ),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16,
            color: Color(0xFFEDE8E3)),
        Expanded(
          child: _selectedDay == null
              ? _buildNoDateSelected()
              : selectedRecords.isEmpty
                  ? _buildEmptyDayState(_selectedDay!)
                  : _buildDayRecords(selectedRecords),
        ),
      ],
    );
  }

  Widget _buildNoDateSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 36, color: AppColors.textHint),
          const SizedBox(height: 10),
          const Text('날짜를 선택하면 기록을 볼 수 있어요',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState(DateTime day) {
    final label = DateFormat('M월 d일', 'ko').format(day);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🐾', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text('$label 기록이 없어요',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _showRecordSheet(day),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('기록 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primaryLight),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRecords(List<Record> records) {
    final dateLabel = _selectedDay != null
        ? DateFormat('M월 d일', 'ko').format(_selectedDay!)
        : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          children: [
            Text(
              '$dateLabel 기록',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showRecordSheet(_selectedDay!),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('추가'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...records.map((r) => _RecordTile(
              record: r,
              onDelete: () async {
                await RecordService().deleteRecord(r.id);
                if (mounted) {
                  await _loadRecords(
                      _focusedDay.year, _focusedDay.month);
                }
              },
            )),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final Record record;
  final VoidCallback? onDelete;

  const _RecordTile({required this.record, this.onDelete});

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
                Text(
                  record.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14),
                ),
                if (record.value != null)
                  Text(
                    '${record.value} kg',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                if (record.notes != null && record.notes!.isNotEmpty)
                  Text(
                    record.notes!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close,
                    size: 16, color: AppColors.textHint),
              ),
            ),
        ],
      ),
    );
  }
}
