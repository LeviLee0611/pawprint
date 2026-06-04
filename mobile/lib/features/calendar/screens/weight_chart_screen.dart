import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../pet/models/pet_model.dart';
import '../models/record_model.dart';
import '../services/record_service.dart';

class WeightChartScreen extends StatefulWidget {
  final Pet pet;
  const WeightChartScreen({super.key, required this.pet});

  @override
  State<WeightChartScreen> createState() => _WeightChartScreenState();
}

class _WeightChartScreenState extends State<WeightChartScreen> {
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
    try {
      final records = await _recordService.getWeightRecords(widget.pet.id);
      if (mounted) setState(() => _records = records);
    } catch (e) {
      debugPrint('WeightChart load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.pet.name} 체중 변화'),
        backgroundColor: const Color(0xFFFFF0DC),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('⚖️', style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      const Text('몸무게 기록이 없어요',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      const Text('캘린더에서 몸무게를 기록해보세요',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textHint)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildChart(),
                      const SizedBox(height: 24),
                      _buildRecordList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final latest = _records.last.value!;
    final first = _records.first.value!;
    final diff = latest - first;
    final diffText = diff >= 0 ? '+${diff.toStringAsFixed(1)}' : diff.toStringAsFixed(1);
    final diffColor = diff > 0
        ? const Color(0xFFE53935)
        : diff < 0
            ? Colors.blue
            : AppColors.textHint;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: '현재',
            value: '${latest.toStringAsFixed(1)} kg',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: '변화',
            value: '$diffText kg',
            color: diffColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: '기록 수',
            value: '${_records.length}회',
            color: AppColors.brown,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final spots = _records.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value!);
    }).toList();

    final minY = (_records.map((r) => r.value!).reduce((a, b) => a < b ? a : b) - 0.5)
        .clamp(0.0, double.infinity);
    final maxY = _records.map((r) => r.value!).reduce((a, b) => a > b ? a : b) + 0.5;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.brownLight.withValues(alpha: 0.5),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: _records.length > 6
                      ? (_records.length / 4).ceilToDouble()
                      : 1,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= _records.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('M/d').format(_records[i].date),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textHint),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.primary,
                getTooltipItems: (spots) => spots.map((s) {
                  final i = s.x.toInt();
                  final r = _records[i];
                  return LineTooltipItem(
                    '${r.value!.toStringAsFixed(1)} kg\n${DateFormat('M/d').format(r.date)}',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('전체 기록',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...(_records.reversed.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('⚖️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('yyyy년 M월 d일', 'ko').format(r.date),
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '${r.value!.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ))),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }
}
