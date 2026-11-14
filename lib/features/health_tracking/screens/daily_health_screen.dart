import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../health_database.dart';

class DailyHealthScreen extends StatefulWidget {
  const DailyHealthScreen({super.key});

  @override
  State<DailyHealthScreen> createState() => _DailyHealthScreenState();
}

class _DailyHealthScreenState extends State<DailyHealthScreen> {
  final waterController = TextEditingController();
  final sleepController = TextEditingController();
  final exerciseController = TextEditingController();

  bool isLoading = false;
  List<Map<String, dynamic>> activities = [];

  bool get isSignedIn => HealthDatabase.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();

    // Load records if already signed in.
    if (isSignedIn) {
      loadActivities();
    }
  }

  @override
  void dispose() {
    waterController.dispose();
    sleepController.dispose();
    exerciseController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Load saved activities
  Future<void> loadActivities() async {
    if (!isSignedIn) return;

    setState(() => isLoading = true);

    try {
      final records = await HealthDatabase.getDailyActivities();

      if (!mounted) return;

      setState(() {
        activities = records;
      });
    } catch (error) {
      showMessage('Could not load activities: $error');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Save daily health activity
  Future<void> saveHealthActivity() async {
    final water = int.tryParse(waterController.text.trim());

    final sleep = double.tryParse(sleepController.text.trim());

    final exercise = int.tryParse(exerciseController.text.trim());

    if (water == null ||
        water < 0 ||
        sleep == null ||
        !sleep.isFinite ||
        sleep < 0 ||
        sleep > 24 ||
        exercise == null ||
        exercise < 0 ||
        exercise > 1440) {
      showMessage(
        'Please enter valid health activity values',
      );
      return;
    }

    if (!isSignedIn) {
      showMessage('Please sign in before saving');
      return;
    }

    setState(() => isLoading = true);

    try {
      await HealthDatabase.saveDailyActivity(
        waterMl: water,
        sleepHours: sleep,
        exerciseMinutes: exercise,
      );

      final records = await HealthDatabase.getDailyActivities();

      if (!mounted) return;

      waterController.clear();
      sleepController.clear();
      exerciseController.clear();

      setState(() {
        activities = records;
      });

      showMessage(
        'Daily health activity saved successfully!',
      );
    } catch (error) {
      showMessage('Save failed: $error');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Reusable health input field
  Future<void> editActivity(Map<String, dynamic> activity) async {
    final water = TextEditingController(
      text: activity['water_ml'].toString(),
    );
    final sleep = TextEditingController(
      text: activity['sleep_hours'].toString(),
    );
    final exercise = TextEditingController(
      text: activity['exercise_minutes'].toString(),
    );

    try {
      final values = await showDialog<List<num>>(
        context: context,
        builder: (dialogContext) {
          String? errorMessage;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Edit Health Activity'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildHealthInput(
                        controller: water,
                        label: 'Water Intake (ml)',
                        icon: Icons.water_drop,
                      ),
                      buildHealthInput(
                        controller: sleep,
                        label: 'Sleep Duration (hours)',
                        icon: Icons.bedtime,
                        allowDecimal: true,
                      ),
                      buildHealthInput(
                        controller: exercise,
                        label: 'Exercise Duration (minutes)',
                        icon: Icons.directions_run,
                      ),
                      if (errorMessage != null)
                        Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final w = int.tryParse(water.text.trim());
                      final s = double.tryParse(sleep.text.trim());
                      final e = int.tryParse(exercise.text.trim());

                      if (w == null ||
                          w < 0 ||
                          s == null ||
                          !s.isFinite ||
                          s < 0 ||
                          s > 24 ||
                          e == null ||
                          e < 0 ||
                          e > 1440) {
                        setDialogState(() {
                          errorMessage = 'Please enter valid values.';
                        });
                        return;
                      }

                      Navigator.pop(dialogContext, <num>[w, s, e]);
                    },
                    child: const Text('Save Changes'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (values == null || !mounted) return;

      setState(() => isLoading = true);

      await HealthDatabase.updateDailyActivity(
        id: activity['id'].toString(),
        waterMl: values[0].toInt(),
        sleepHours: values[1].toDouble(),
        exerciseMinutes: values[2].toInt(),
      );

      showMessage('Activity updated successfully!');

      if (mounted) {
        await loadActivities();
      }
    } catch (error) {
      showMessage('Update failed: $error');
    } finally {
      water.dispose();
      sleep.dispose();
      exercise.dispose();

      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> deleteActivity(Map<String, dynamic> activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Health Activity?'),
        content: const Text(
          'Are you sure you want to delete this record? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => isLoading = true);

    try {
      await HealthDatabase.deleteDailyActivity(
        id: activity['id'].toString(),
      );

      showMessage('Activity deleted successfully!');

      if (mounted) {
        await loadActivities();
      }
    } catch (error) {
      showMessage('Delete failed: $error');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Each saved activity represents a daily total, not an increment.
  Map<String, dynamic>? get todaysActivity {
    final now = DateTime.now();
    Map<String, dynamic>? latest;
    DateTime? latestTime;
    for (final activity in activities) {
      final time = DateTime.tryParse(
        activity['recorded_at'].toString(),
      )?.toLocal();
      if (time == null ||
          time.year != now.year ||
          time.month != now.month ||
          time.day != now.day) {
        continue;
      }
      if (latestTime == null || time.isAfter(latestTime)) {
        latest = activity;
        latestTime = time;
      }
    }
    return latest;
  }

  Widget buildGoalProgress({
    required String label,
    required double value,
    required double target,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final progress = (value / target).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} / ${target.toStringAsFixed(0)} $unit'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  color: color,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${(progress * 100).round()}%'),
        ],
      ),
    );
  }

  Widget buildDailyGoals() {
    final activity = todaysActivity;
    double readValue(String key) =>
        double.tryParse(activity?[key]?.toString() ?? '') ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Health Goals",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(activity == null
                ? 'No activity recorded today.'
                : 'Based on your latest saved daily totals.'),
            buildGoalProgress(
                label: 'Water Intake',
                value: readValue('water_ml'),
                target: 2000,
                unit: 'ml',
                icon: Icons.water_drop,
                color: Colors.blue),
            buildGoalProgress(
                label: 'Sleep Duration',
                value: readValue('sleep_hours'),
                target: 8,
                unit: 'hours',
                icon: Icons.bedtime,
                color: Colors.deepPurple),
            buildGoalProgress(
                label: 'Exercise',
                value: readValue('exercise_minutes'),
                target: 30,
                unit: 'minutes',
                icon: Icons.directions_run,
                color: Colors.green),
            const Text(
                'Example wellness targets only. Individual needs may differ.',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget buildHealthInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool allowDecimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(
          decimal: allowDecimal,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Health Tracker'),
        backgroundColor: const Color(0xFF9B83F5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Track Your Daily Health',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Login screen
            if (!isSignedIn) ...[
              const Text(
                'Please log in to your MedMate account.',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Go to MedMate Login'),
              ),
            ] else ...[
              const Text(
                'Connected to your MedMate account',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed:
                    isLoading ? null : () => context.push('/health-reports'),
                icon: const Icon(Icons.bar_chart),
                label: const Text('View Health Reports'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B83F5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              buildDailyGoals(),
              const SizedBox(height: 24),
              buildHealthInput(
                controller: waterController,
                label: 'Water Intake (ml)',
                icon: Icons.water_drop,
              ),
              buildHealthInput(
                controller: sleepController,
                label: 'Sleep Duration (hours)',
                icon: Icons.bedtime,
                allowDecimal: true,
              ),
              buildHealthInput(
                controller: exerciseController,
                label: 'Exercise Duration (minutes)',
                icon: Icons.directions_run,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isLoading ? null : saveHealthActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B83F5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text(
                  'Save Daily Activity',
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Saved Health Activities',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading ? null : loadActivities,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Activities'),
              ),
              const SizedBox(height: 12),
              if (activities.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No saved activities yet.',
                  ),
                ),
              ...activities.map((activity) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.favorite,
                      color: Color(0xFF9B83F5),
                    ),
                    title: Text(
                      'Water: ${activity['water_ml']} ml',
                    ),
                    subtitle: Text(
                      'Sleep: ${activity['sleep_hours']} hours\n'
                      'Exercise: ${activity['exercise_minutes']} minutes\n'
                      'Recorded: ${activity['recorded_at']}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit Activity',
                          onPressed:
                              isLoading ? null : () => editActivity(activity),
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blue,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete Activity',
                          onPressed:
                              isLoading ? null : () => deleteActivity(activity),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],

            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
