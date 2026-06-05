import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/record_model.dart';
import '../services/record_service.dart';
import '../screens/add_record_screen.dart';
import '../screens/record_detail_screen.dart';
import '../screens/photo_gallery_screen.dart';
import '../screens/photo_viewer_screen.dart';
import '../widgets/record_bottom_sheet.dart';
import '../services/reminder_service.dart';
import '../screens/reminder_screen.dart';
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
  final _reminderService = ReminderService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Pet> _pets = [];
  List<Map<String, dynamic>> _upcomingReminders = [];
  String? _selectedPetId; // null = 전체
  bool _loadingPet = true;
  Map<DateTime, List<Record>> _recordsByDate = {};

  static const _petColors = [
    AppColors.primary,
    AppColors.brown,
    AppColors.green,
    AppColors.peach,
  ];

  Color _petColorOf(String petId) {
    final index = _pets.indexWhere((p) => p.id == petId);
    return _petColors[(index < 0 ? 0 : index) % _petColors.length];
  }

  Pet? get _activePet {
    if (_selectedPetId == null || _pets.isEmpty) return null;
    return _pets.firstWhere((p) => p.id == _selectedPetId,
        orElse: () => _pets.first);
  }

  @override
  void initState() {
    super.initState();
    _loadPets();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    try {
      final data = await _reminderService.getMyReminders();
      if (mounted) setState(() => _upcomingReminders = data);
    } catch (_) {}
  }

  Future<void> _loadPets() async {
    try {
      final pets = await _petService.getMyPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _selectedPetId = null;
      });
      if (_pets.isNotEmpty) {
        await _loadRecords(_focusedDay.year, _focusedDay.month);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('펫 정보를 불러오지 못했어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPet = false);
    }
  }

  Future<void> _loadRecords(int year, int month) async {
    try {
      final records = _selectedPetId == null
          ? await _recordService.getRecordsForMonthAllPets(year, month)
          : await _recordService.getRecordsForMonth(
              _selectedPetId!, year, month);
      if (!mounted) return;
      final map = <DateTime, List<Record>>{};
      for (final r in records) {
        final key = DateTime(r.date.year, r.date.month, r.date.day);
        (map[key] ??= []).add(r);
      }
      setState(() => _recordsByDate = map);
    } catch (_) {
      if (mounted) setState(() => _recordsByDate = {});
    }
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

  Future<Pet?> _pickPet() async {
    if (_pets.length == 1) return _pets.first;
    return showDialog<Pet>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '어느 아이 기록인가요?',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        children: _pets
            .map((pet) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, pet),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Text(pet.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(pet.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ]),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _showRecordSheet(DateTime date) async {
    final pet = _selectedPetId != null ? _activePet : await _pickPet();
    if (pet == null || !mounted) return;

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
        builder: (_) =>
            AddRecordScreen(date: date, pet: pet, type: selectedType),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF0DC), Color(0xFFFFFAF5)],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(_activePet != null
                ? '${_activePet!.emoji} ${_activePet!.name}'
                : '댕냥스토리'),
            actions: [
              if (_pets.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.photo_library_rounded),
                  color: AppColors.primary,
                  tooltip: '사진 모아보기',
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const PhotoGalleryScreen())),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.vaccines_outlined),
                      color: AppColors.green,
                      tooltip: '예방접종 알림',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ReminderScreen()),
                        );
                        _loadReminders();
                      },
                    ),
                    if (_upcomingReminders.isNotEmpty)
                      Positioned(
                        top: 10,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.peach,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                  tooltip: '기록 추가',
                  onPressed: () =>
                      _showRecordSheet(_selectedDay ?? DateTime.now()),
                ),
              ],
            ],
          ),
        ),
      ),
      body: _pets.isEmpty ? _buildNoPetState() : _buildCalendar(),
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
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AddPetScreen(isOnboarding: false)),
                );
                await _loadPets();
              },
              child: const Text('펫 등록하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _PetFilterChip(
            label: '전체',
            emoji: '🐾',
            selected: _selectedPetId == null,
            color: AppColors.primary,
            onTap: () {
              if (_selectedPetId == null) return;
              setState(() => _selectedPetId = null);
              _loadRecords(_focusedDay.year, _focusedDay.month);
            },
          ),
          ..._pets.asMap().entries.map((e) => _PetFilterChip(
                label: e.value.name,
                emoji: e.value.emoji,
                selected: _selectedPetId == e.value.id,
                color: _petColors[e.key % _petColors.length],
                onTap: () {
                  if (_selectedPetId == e.value.id) return;
                  setState(() => _selectedPetId = e.value.id);
                  _loadRecords(_focusedDay.year, _focusedDay.month);
                },
              )),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final selectedRecords =
        _selectedDay != null ? _getEventsForDay(_selectedDay!) : <Record>[];
    final showPetBadge = _selectedPetId == null && _pets.length > 1;
    final petMap = {for (final p in _pets) p.id: p};

    return Column(
      children: [
        if (_pets.length > 1) ...[
          const SizedBox(height: 8),
          _buildPetFilterChips(),
          const SizedBox(height: 4),
        ],
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
                final petIds = events.map((e) => e.petId).toSet().toList();
                return Positioned(
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: petIds
                        .take(3)
                        .map((petId) => Container(
                              width: 5,
                              height: 5,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: _petColorOf(petId),
                                shape: BoxShape.circle,
                              ),
                            ))
                        .toList(),
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
              markersMaxCount: 3,
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
        const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFEDE8E3)),
        Expanded(
          child: _selectedDay == null
              ? _buildNoDateSelected()
              : selectedRecords.isEmpty
                  ? _buildEmptyDayState(_selectedDay!)
                  : _buildDayRecords(selectedRecords,
                      showPetBadge: showPetBadge, petMap: petMap),
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
              style: TextStyle(fontSize: 13, color: AppColors.textHint)),
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

  Widget _buildDayRecords(
    List<Record> records, {
    required bool showPetBadge,
    required Map<String, Pet> petMap,
  }) {
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...records.map((r) {
          final pet = petMap[r.petId] ?? _activePet;
          return _RecordTile(
            record: r,
            pet: showPetBadge ? petMap[r.petId] : null,
            onTap: pet == null
                ? null
                : () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RecordDetailScreen(record: r, pet: pet),
                      ),
                    );
                    if (updated == true && mounted) {
                      await _loadRecords(
                          _focusedDay.year, _focusedDay.month);
                    }
                  },
            onDelete: () async {
              await RecordService()
                  .deleteRecord(r.id, photoUrl: r.photoUrl);
              if (mounted) {
                await _loadRecords(_focusedDay.year, _focusedDay.month);
              }
            },
          );
        }),
      ],
    );
  }
}

class _PetFilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PetFilterChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.brownLight,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final Record record;
  final Pet? pet;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _RecordTile({required this.record, this.pet, this.onDelete, this.onTap});

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(record.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 14),
                    ),
                    if (pet != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${pet!.emoji} ${pet!.name}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                if (record.value != null)
                  Text('${record.value} kg',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                if (record.notes != null && record.notes!.isNotEmpty)
                  Text(record.notes!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (record.photoUrl != null)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PhotoViewerScreen(record: record, pet: pet),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    record.photoUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),
                ),
              ),
            ),
          if (onDelete != null)
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
      ),
    );
  }
}
