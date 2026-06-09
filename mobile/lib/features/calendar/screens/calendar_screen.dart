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

class _CalendarScreenState extends State<CalendarScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
  int _streak = 0;

  static const _petColors = [
    AppColors.primary,
    AppColors.brown,
    AppColors.green,
    AppColors.peach,
  ];

  Widget _buildDayCell(DateTime day, {bool isSelected = false, bool isToday = false}) {
    final records = _getEventsForDay(day);
    final seen = <String>{};
    final unique = <Record>[];
    for (final r in records) {
      if (seen.add(r.type)) unique.add(r);
    }
    final shown = unique.take(2).toList();
    final count = records.length;

    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    Color textColor;
    BoxDecoration? decoration;
    if (isSelected) {
      textColor = Colors.white;
      decoration = const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle);
    } else if (isToday) {
      textColor = AppColors.primary;
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 1.5),
      );
    } else {
      textColor = isWeekend ? const Color(0xFFE57373) : AppColors.textPrimary;
    }

    return Stack(
      children: [
        Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: decoration,
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
        if (shown.isNotEmpty)
          Positioned(
            bottom: 3,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: shown.map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(e.emoji, style: const TextStyle(fontSize: 10)),
              )).toList(),
            ),
          ),
        if (count > 2)
          Positioned(
            top: 3,
            right: 3,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 7,
                    color: isSelected ? AppColors.primary : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _recordBubbleColor(String type) {
    switch (type) {
      case 'photo':   return AppColors.primary;
      case 'health':  return AppColors.green;
      case 'weight':  return AppColors.brown;
      case 'note':    return AppColors.peach;
      case 'bath':    return const Color(0xFF6BB8D4);
      case 'grooming': return const Color(0xFFB39DDB);
      default:        return AppColors.brownLight;
    }
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
    _calculateStreak();
  }

  Future<void> _calculateStreak() async {
    try {
      final all = await _recordService.getAllRecords();
      if (!mounted) return;
      final dates = all.map((r) => DateTime(r.date.year, r.date.month, r.date.day)).toSet();
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      DateTime check = dates.contains(today) ? today : today.subtract(const Duration(days: 1));
      int streak = 0;
      while (dates.contains(check)) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      }
      if (mounted) setState(() => _streak = streak);
    } catch (_) {}
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
      _calculateStreak();
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
        children: [
          // 공통 기록 옵션
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, Pet.household),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Text('🏠', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('공통 기록',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const Text('모래 교체, 전체 목욕 등',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint)),
                  ],
                ),
              ]),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ..._pets.map((pet) => SimpleDialogOption(
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
              )),
        ],
      ),
    );
  }

  Future<void> _showRecordSheet(DateTime date) async {
    final pet = await _pickPet();
    if (pet == null || !mounted) return;

    final selectedType = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RecordBottomSheet(date: date, isHousehold: pet.isHousehold),
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
    super.build(context);
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

  Future<void> _showDateJumper() async {
    int selYear = _focusedDay.year;
    int selMonth = _focusedDay.month;
    final now = DateTime.now();

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.brownLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.brown),
                    onPressed: () => setSheet(() => selYear--),
                  ),
                  Text('$selYear년',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
                    onPressed: () => setSheet(() => selYear++),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.0,
                children: List.generate(12, (i) {
                  final month = i + 1;
                  final isSelected = month == selMonth && selYear == _focusedDay.year;
                  final isNow = month == now.month && selYear == now.year;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      final newDay = DateTime(selYear, month);
                      setState(() {
                        _focusedDay = newDay;
                        selMonth = month;
                      });
                      _loadRecords(selYear, month);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : isNow
                                ? AppColors.primaryLight
                                : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '$month월',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected || isNow ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : isNow
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
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
              headerTitleBuilder: (context, day) {
                final total = _recordsByDate.values.fold(0, (s, l) => s + l.length);
                final days = _recordsByDate.keys.length;
                return GestureDetector(
                  onTap: _showDateJumper,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('yyyy년 M월', 'ko').format(day),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                        if (total > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$total개 · $days일 기록',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              if (_streak > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '🔥 $_streak일 연속',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
              dowBuilder: (context, day) {
                const labels = ['월', '화', '수', '목', '금', '토', '일'];
                final label = labels[day.weekday - 1];
                Color color;
                if (day.weekday == DateTime.sunday) {
                  color = const Color(0xFFE57373);
                } else if (day.weekday == DateTime.saturday) {
                  color = const Color(0xFF90CAF9);
                } else {
                  color = AppColors.textSecondary;
                }
                return Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, _) => _buildDayCell(day),
              selectedBuilder: (context, day, _) => _buildDayCell(day, isSelected: true),
              todayBuilder: (context, day, _) => _buildDayCell(day, isToday: true),
            ),
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              markersMaxCount: 0,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 0),
              leftChevronIcon: Icon(Icons.chevron_left_rounded, color: AppColors.brown, size: 20),
              rightChevronIcon: Icon(Icons.chevron_right_rounded, color: AppColors.brown, size: 20),
              headerPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.divider),
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
          final pet = r.petId == null
              ? Pet.household
              : (petMap[r.petId] ?? _activePet);
          return _RecordTile(
            record: r,
            accentColor: _recordBubbleColor(r.type),
            pet: showPetBadge ? (petMap[r.petId] ?? (r.petId == null ? Pet.household : null)) : null,
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
  final Color accentColor;
  final Pet? pet;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _RecordTile({required this.record, required this.accentColor, this.pet, this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Container(width: 4, color: accentColor),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
