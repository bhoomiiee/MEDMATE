import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../health_database.dart';

class HealthReportsScreen extends StatefulWidget {
  const HealthReportsScreen({super.key});

  @override
  State<HealthReportsScreen> createState() => _HealthReportsScreenState();
}

class _HealthReportsScreenState extends State<HealthReportsScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> activities = [];

  int selectedPeriod = 1;

  List<Map<String, dynamic>> get dailyRecords {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(now.year, now.month, now.day - 6);
    final latest = <DateTime, Map<String, dynamic>>{};
    final sorted = [
      ...activities
    ]..sort((a, b) => (DateTime.tryParse(b['recorded_at'].toString()) ??
            DateTime(1970))
        .compareTo(
            DateTime.tryParse(a['recorded_at'].toString()) ?? DateTime(1970)));
    for (final record in sorted) {
      final date =
          DateTime.tryParse(record['recorded_at'].toString())?.toLocal();
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (day.isAfter(today)) continue;
      if (selectedPeriod == 0 && day != today) continue;
      if (selectedPeriod == 1 && day.isBefore(start)) continue;
      latest.putIfAbsent(day, () => record);
    }
    return latest.values.toList();
  }

  Widget buildPeriodSelector() {
    return Wrap(
      spacing: 8,
      children: List.generate(
          3,
          (index) => ChoiceChip(
                label: Text(['Today', 'Last 7 Days', 'All Time'][index]),
                selected: selectedPeriod == index,
                onSelected: (_) => setState(() => selectedPeriod = index),
              )),
    );
  }

  Widget buildWellnessSummary() {
    final water = calculateAverage('water_ml');
    final sleep = calculateAverage('sleep_hours');
    final exercise = calculateAverage('exercise_minutes');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wellness Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
                'Water: ${water >= 2000 ? "At or above example goal" : "Below example goal"} (2000 ml).'),
            Text(
                'Sleep: ${sleep >= 8 ? "At or above example goal" : "Below example goal"} (8 hours).'),
            Text(
                'Exercise: ${exercise >= 30 ? "At or above example goal" : "Below example goal"} (30 min).'),
            const SizedBox(height: 12),
            const Text(
                'These are illustrative goals, not medical advice. Individual needs vary.'),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final records = await HealthDatabase.getDailyActivities();

      if (!mounted) return;

      setState(() {
        activities = records;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  double getValue(
    Map<String, dynamic> activity,
    String field,
  ) {
    return double.tryParse(
          activity[field].toString(),
        ) ??
        0;
  }

  double calculateAverage(String field) {
    final records = dailyRecords;
    if (records.isEmpty) return 0;

    double total = 0;

    for (final activity in records) {
      total += getValue(activity, field);
    }

    return total / records.length;
  }

  Widget buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildChart({
    required String title,
    required String field,
    required Color color,
    required double defaultMax,
    required String unit,
  }) {
    final recentActivities = dailyRecords.take(7).toList().reversed.toList();

    double maxValue = defaultMax;

    for (final activity in recentActivities) {
      final value = getValue(activity, field);

      if (value > maxValue) {
        maxValue = value;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Latest recorded days in selected period ($unit)'),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxValue * 1.2,
                  barGroups: List.generate(
                    recentActivities.length,
                    (index) {
                      final value = getValue(
                        recentActivities[index],
                        field,
                      );

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: value,
                            color: color,
                            width: 20,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();

                          if (index < 0 || index >= recentActivities.length) {
                            return const SizedBox.shrink();
                          }

                          final date = DateTime.tryParse(
                            recentActivities[index]['recorded_at'].toString(),
                          )?.toLocal();

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              date == null
                                  ? '${index + 1}'
                                  : '${date.day}/${date.month}',
                              style: const TextStyle(
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Reports'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadReports,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 50,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 180,
                          child: ElevatedButton(
                            onPressed: loadReports,
                            child: const Text('Try Again'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: AppColors.elevatedShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.bar_chart_rounded,
                                    color: Colors.white,
                                    size: 44,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Your Health Overview',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Understand your daily habits and wellness trends.',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Recorded days: ${dailyRecords.length}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            buildPeriodSelector(),
                            const SizedBox(height: 16),
                            if (dailyRecords.isEmpty)
                              const Text(
                                  'No health activities recorded for this period.')
                            else ...[
                              buildSummaryCard(
                                title: 'Average Water Intake',
                                value:
                                    '${calculateAverage('water_ml').toStringAsFixed(0)} ml',
                                icon: Icons.water_drop,
                                color: AppColors.teal,
                              ),
                              buildSummaryCard(
                                title: 'Average Sleep Duration',
                                value:
                                    '${calculateAverage('sleep_hours').toStringAsFixed(1)} hours',
                                icon: Icons.bedtime,
                                color: AppColors.primary,
                              ),
                              buildSummaryCard(
                                title: 'Average Exercise',
                                value:
                                    '${calculateAverage('exercise_minutes').toStringAsFixed(0)} min',
                                icon: Icons.directions_run,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(height: 24),
                              buildChart(
                                title: 'Water Intake Report',
                                field: 'water_ml',
                                color: AppColors.teal,
                                defaultMax: 3000,
                                unit: 'ml',
                              ),
                              const SizedBox(height: 16),
                              buildChart(
                                title: 'Sleep Duration Report',
                                field: 'sleep_hours',
                                color: AppColors.primary,
                                defaultMax: 12,
                                unit: 'hours',
                              ),
                              const SizedBox(height: 16),
                              buildChart(
                                title: 'Exercise Report',
                                field: 'exercise_minutes',
                                color: AppColors.secondary,
                                defaultMax: 60,
                                unit: 'minutes',
                              ),
                              const SizedBox(height: 24),
                              buildWellnessSummary(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
