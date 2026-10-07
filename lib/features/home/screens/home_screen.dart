import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/reminder_overlay_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _todayReminders = [];
  List<Map<String, dynamic>> _lowStockMedicines = [];
  List<Map<String, dynamic>> _upcomingVaccinations = [];
  bool _loading = true;
  String _selectedTimeFilter = 'All';

  /// Fires every minute to catch reminders as they become due
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();

    // Check immediately after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkReminders();
    });

    // Then check every 60 seconds
    _reminderTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkReminders(),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check reminders when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkReminders();
    }
  }

  Future<void> _checkReminders() async {
    if (!mounted) return;
    await ReminderOverlayService.checkAndShow(context);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _profile = {'full_name': 'Guest'};
          _todayReminders = [];
          _lowStockMedicines = [];
          _upcomingVaccinations = [];
        });
        return;
      }

      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final results = await Future.wait([
        SupabaseService.getProfile(userId),
        SupabaseService.getAllActiveSchedules(),
        SupabaseService.getVaccinations(),
        SupabaseService.getReminderLogs(from: dayStart, to: dayEnd),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final schedules = results[1] as List<Map<String, dynamic>>;
      final vaccinations = results[2] as List<Map<String, dynamic>>;
      final logs = results[3] as List<Map<String, dynamic>>;

      // Build today's reminders with real log status
      final todayReminders = _buildTodayReminders(schedules, logs);

      // Low stock
      final medicines = await SupabaseService.getUserMedicines();
      final lowStock = medicines.where((m) {
        final stock = (m['current_stock'] as int?) ?? 0;
        final threshold = (m['refill_threshold'] as int?) ?? 5;
        return stock <= threshold && stock > 0;
      }).toList();

      // Upcoming vaccinations (next 30 days)
      final upcoming = vaccinations.where((v) {
        final nextDue = v['next_due_date'];
        if (nextDue == null) return false;
        final dueDate = DateTime.parse(nextDue);
        return dueDate.isAfter(now) &&
            dueDate.isBefore(now.add(const Duration(days: 30)));
      }).toList();

      setState(() {
        _profile = profile;
        _todayReminders = todayReminders;
        _lowStockMedicines = lowStock;
        _upcomingVaccinations = upcoming;
      });
    } catch (e) {
      debugPrint('Home load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _buildTodayReminders(
      List<Map<String, dynamic>> schedules, List<Map<String, dynamic>> logs) {
    final now = DateTime.now();
    final reminders = <Map<String, dynamic>>[];

    for (final schedule in schedules) {
      final times = List<String>.from(schedule['times'] ?? []);
      final startDate = schedule['start_date'] as String?;
      final endDate = schedule['end_date'] as String?;
      if (startDate == null) continue;
      if (DateTime.parse(startDate).isAfter(now)) continue;
      if (endDate != null && DateTime.parse(endDate).isBefore(now)) continue;

      for (final time in times) {
        final parts = time.split(':');
        if (parts.length < 2) continue;
        final dt = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));

        final formattedDtPrefix =
            DateFormat('yyyy-MM-ddTHH:mm').format(dt).substring(0, 16);
        final log = logs.cast<Map<String, dynamic>?>().firstWhere(
              (l) =>
                  l != null &&
                  l['schedule_id'] == schedule['id'] &&
                  (l['scheduled_at'] as String).startsWith(formattedDtPrefix),
              orElse: () => null,
            );

        reminders.add({
          ...schedule,
          'reminder_time': time,
          'reminder_datetime': dt,
          'is_past': dt.isBefore(now),
          'status': log?['status'] ?? 'pending',
          'log': log,
        });
      }
    }

    reminders.sort((a, b) => (a['reminder_datetime'] as DateTime)
        .compareTo(b['reminder_datetime'] as DateTime));
    return reminders;
  }

  List<Map<String, dynamic>> get _filteredReminders {
    if (_selectedTimeFilter == 'All') return _todayReminders;

    return _todayReminders.where((r) {
      final dt = r['reminder_datetime'] as DateTime;
      final hour = dt.hour;
      switch (_selectedTimeFilter) {
        case 'Morning':
          return hour >= 5 && hour < 12;
        case 'Afternoon':
          return hour >= 12 && hour < 17;
        case 'Evening':
          return hour >= 17 && hour < 21;
        case 'Night':
          return hour >= 21 || hour < 5;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _quickMarkTaken(Map<String, dynamic> reminder) async {
    final dt = reminder['reminder_datetime'] as DateTime;
    final isAlreadyTaken = reminder['status'] == 'taken';
    final newStatus = isAlreadyTaken ? 'pending' : 'taken';

    try {
      await SupabaseService.upsertReminderLog({
        'schedule_id': reminder['id'],
        'medicine_id': reminder['medicine_id'],
        'user_id': reminder['user_id'] ?? AuthService.currentUser?.id,
        'scheduled_at': dt.toIso8601String(),
        'status': newStatus,
        'taken_at': newStatus == 'taken' ? DateTime.now().toIso8601String() : null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                newStatus == 'taken'
                    ? Icons.check_circle_rounded
                    : Icons.refresh_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(newStatus == 'taken'
                  ? 'Dose marked as taken! 🎉'
                  : 'Dose unmarked.'),
            ],
          ),
          backgroundColor:
              newStatus == 'taken' ? AppColors.secondary : AppColors.textSecondary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _loadData();
    } catch (e) {
      debugPrint('Mark status error: $e');
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (_profile?['full_name'] as String?)?.split(' ').first ?? 'there';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Lush Hero App Bar
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient Backdrop
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                    // Ambient Light Circles
                    Positioned(
                      top: -40,
                      right: -30,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: 20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    // Header Content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.18),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 11,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  DateFormat('EEEE, d MMM')
                                                      .format(DateTime.now()),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_greeting()}, $name ✨',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.go('/profile'),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.white,
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: const TextStyle(
                                          color: AppColors.primaryDark,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_active_outlined,
                      color: Colors.white),
                  tooltip: 'Check Reminders',
                  onPressed: _checkReminders,
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                  tooltip: 'Search Medicines',
                  onPressed: () => context.go('/search'),
                ),
              ],
            ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Guest Mode Banner
                    if (AuthService.currentUser == null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person_outline_rounded,
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Browsing as Guest',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Sign in to save medicines & sync schedules',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Sign In',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Hero Adherence Progress Ring Card
                    _buildAdherenceCard(isDark),
                    const SizedBox(height: 18),

                    // Quick Stats Row
                    _buildStatsRow(isDark),
                    const SizedBox(height: 22),

                    // Quick Actions Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quick Services',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActions(isDark),
                    const SizedBox(height: 26),

                    // Today's Schedule Header & Filters
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Schedule",
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${_todayReminders.length} doses scheduled',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => context.go('/reminders'),
                          icon: const Text('Full View'),
                          label: const Icon(Icons.arrow_forward_rounded, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Filter Pills
                    _buildTimeFilterPills(isDark),
                    const SizedBox(height: 14),

                    // Today's Reminders List
                    if (_todayReminders.isEmpty)
                      _buildEmptyCard(
                        Icons.alarm_on_rounded,
                        'All caught up for today!',
                        'No pending medicine reminders scheduled.',
                        isDark,
                      )
                    else if (_filteredReminders.isEmpty)
                      _buildEmptyCard(
                        Icons.wb_sunny_outlined,
                        'No doses in this period',
                        'Select another time of day or view all.',
                        isDark,
                      )
                    else
                      ..._filteredReminders
                          .take(5)
                          .map((r) => _buildReminderCard(r, isDark)),

                    if (_todayReminders.length > 5) ...[
                      const SizedBox(height: 8),
                      _buildViewAllButton(
                        'View all ${_todayReminders.length} reminders',
                        () => context.go('/reminders'),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Low Stock Alert
                    if (_lowStockMedicines.isNotEmpty) ...[
                      _buildSectionHeader(
                        '⚠️ Refill Alerts',
                        '${_lowStockMedicines.length} medicine(s) running low',
                        () => context.go('/medicines'),
                      ),
                      const SizedBox(height: 12),
                      ..._lowStockMedicines
                          .take(3)
                          .map((m) => _buildLowStockCard(m, isDark)),
                      const SizedBox(height: 24),
                    ],

                    // Upcoming Vaccinations
                    if (_upcomingVaccinations.isNotEmpty) ...[
                      _buildSectionHeader(
                        '💉 Upcoming Vaccinations',
                        'Next 30 days',
                        () => context.go('/vaccinations'),
                      ),
                      const SizedBox(height: 12),
                      ..._upcomingVaccinations
                          .take(2)
                          .map((v) => _buildVaccinationCard(v, isDark)),
                      const SizedBox(height: 24),
                    ],

                    // Explore More Grid
                    _buildFeaturesGrid(isDark),
                    const SizedBox(height: 20),

                    // Medical Disclaimer Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'MEDMATE is an adherence companion. Always follow your prescribing doctor\'s instructions.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/medicines/add'),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Add Medicine',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.primary,
        elevation: 6,
      ),
    );
  }

  Widget _buildAdherenceCard(bool isDark) {
    final taken = _todayReminders.where((r) => r['status'] == 'taken').length;
    final total = _todayReminders.length;
    final ratio = total > 0 ? (taken / total) : 1.0;
    final percent = (ratio * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          // Circular Progress Indicator
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 7,
                  backgroundColor: isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.primarySurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percent == 100
                        ? AppColors.secondary
                        : (percent > 0 ? AppColors.primary : AppColors.textMuted),
                  ),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Today\'s Adherence',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (percent == 100 && total > 0)
                      const Icon(Icons.stars_rounded,
                          color: AppColors.secondary, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? 'No medicines scheduled today'
                      : '$taken of $total doses completed',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  percent == 100 && total > 0
                      ? '🎉 Amazing! You\'ve completed all doses today.'
                      : (total > 0
                          ? '${total - taken} dose(s) remaining today.'
                          : 'Tap below to add your first medicine.'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: percent == 100 && total > 0
                        ? AppColors.secondary
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final taken = _todayReminders.where((r) => r['status'] == 'taken').length;
    final total = _todayReminders.length;

    return Row(
      children: [
        _buildStatCard(
          'Doses',
          '$taken/$total',
          'taken today',
          AppColors.primary,
          Icons.medication_rounded,
          isDark,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          'Low Stock',
          '${_lowStockMedicines.length}',
          'refill alerts',
          AppColors.warning,
          Icons.inventory_2_rounded,
          isDark,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          'Vaccines',
          '${_upcomingVaccinations.length}',
          'upcoming',
          AppColors.teal,
          Icons.vaccines_rounded,
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    const actions = [
      _QuickAction('Add Med', Icons.add_circle_outline_rounded,
          AppColors.primary, '/medicines/add'),
      _QuickAction('Schedule', Icons.alarm_rounded, AppColors.teal, '/reminders'),
      _QuickAction('Rx Scripts', Icons.description_rounded, AppColors.warning,
          '/prescriptions'),
      _QuickAction('Family', Icons.people_alt_rounded, AppColors.violet, '/family'),
      _QuickAction('Documents', Icons.folder_shared_rounded, Color(0xFFA855F7),
          '/documents'),
      _QuickAction('Vitals', Icons.favorite_rounded, AppColors.error, '/vitals'),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: actions.map((a) => _buildQuickActionTile(a, isDark)).toList(),
    );
  }

  Widget _buildQuickActionTile(_QuickAction action, bool isDark) {
    return GestureDetector(
      onTap: () => context.go(action.route),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    action.color.withValues(alpha: 0.18),
                    action.color.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: action.color.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterPills(bool isDark) {
    final filters = ['All', 'Morning', 'Afternoon', 'Evening', 'Night'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedTimeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTimeFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkSurface
                          : AppColors.surface),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.borderSubtle),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder, bool isDark) {
    final medicine = reminder['user_medicines'];
    final name = medicine?['name'] ?? reminder['name'] ?? 'Medicine';
    final dosage = medicine?['dosage'] ?? '';
    final time = reminder['reminder_time'] as String? ?? '';
    final isPast = reminder['is_past'] as bool? ?? false;
    final status = reminder['status'] as String? ?? 'pending';
    final isTaken = status == 'taken';

    final Color statusColor = isTaken
        ? AppColors.secondary
        : (isPast ? AppColors.warning : AppColors.primary);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTaken
              ? AppColors.secondary.withValues(alpha: 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.borderSubtle),
          width: isTaken ? 1.5 : 1,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status Icon Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor.withValues(alpha: 0.2),
                    statusColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                isTaken
                    ? Icons.check_circle_rounded
                    : (isPast ? Icons.access_time_filled_rounded : Icons.alarm_rounded),
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.2,
                      decoration:
                          isTaken ? TextDecoration.lineThrough : null,
                      color: isTaken
                          ? AppColors.textMuted
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (dosage.isNotEmpty)
                        Text(
                          dosage,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (reminder['with_food'] == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.restaurant_rounded,
                                  size: 10, color: AppColors.textMuted),
                              SizedBox(width: 3),
                              Text(
                                'With food',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Time & One-Tap Take Action Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _quickMarkTaken(reminder),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isTaken
                          ? AppColors.secondarySurface
                          : (isPast
                              ? AppColors.warningSurface
                              : AppColors.primarySurface),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTaken ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 13,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isTaken ? 'Taken' : 'Take',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockCard(Map<String, dynamic> medicine, bool isDark) {
    final stock = (medicine['current_stock'] as int?) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${medicine['dosage'] ?? ''} • ${medicine['form'] ?? 'Medicine'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warningSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$stock left',
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccinationCard(Map<String, dynamic> vaccination, bool isDark) {
    final dueDate = vaccination['next_due_date'] != null
        ? DateTime.parse(vaccination['next_due_date'])
        : null;
    final daysLeft = dueDate?.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.3),
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.vaccines_rounded,
              color: AppColors.teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vaccination['vaccine_name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                if (dueDate != null)
                  Text(
                    'Due: ${DateFormat('d MMM yyyy').format(dueDate)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (daysLeft != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.tealSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
              ),
              child: Text(
                '$daysLeft days left',
                style: const TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Explore More', null, null),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildFeatureTile(
              'Medicine\nSearch',
              Icons.search_rounded,
              AppColors.primary,
              () => context.go('/search'),
              isDark,
            ),
            const SizedBox(width: 12),
            _buildFeatureTile(
              'Vaccination\nTracker',
              Icons.vaccines_rounded,
              AppColors.teal,
              () => context.go('/vaccinations'),
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildFeatureTile(
              'Health\nVitals',
              Icons.favorite_rounded,
              AppColors.error,
              () => context.go('/vitals'),
              isDark,
            ),
            const SizedBox(width: 12),
            _buildFeatureTile(
              'Dose\nHistory',
              Icons.history_rounded,
              AppColors.warning,
              () => context.go('/history'),
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureTile(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
            ),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, String? subtitle, VoidCallback? onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('See all'),
          ),
      ],
    );
  }

  Widget _buildEmptyCard(
      IconData icon, String title, String subtitle, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _QuickAction(this.label, this.icon, this.color, this.route);
}
