import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/healthcare_access/screens/government_schemes_screen.dart';
import '../../features/healthcare_access/screens/nearby_healthcare_screen.dart';

import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/email_confirm_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/medicines/screens/medicines_list_screen.dart';
import '../../features/medicines/screens/add_edit_medicine_screen.dart';
import '../../features/medicines/screens/medicine_detail_screen.dart';
import '../../features/reminders/screens/reminders_screen.dart';
import '../../features/reminders/screens/add_schedule_screen.dart';
import '../../features/prescriptions/screens/prescriptions_screen.dart';
import '../../features/prescriptions/screens/add_prescription_screen.dart';
import '../../features/prescriptions/screens/prescription_detail_screen.dart';
import '../../features/documents/screens/documents_screen.dart';
import '../../features/family/screens/family_screen.dart';
import '../../features/family/screens/add_family_member_screen.dart';
import '../../features/family/screens/caregiver_screen.dart';
import '../../features/search/screens/medicine_search_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/vaccinations/screens/vaccinations_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/vitals/screens/vitals_screen.dart';
import '../../features/vitals/screens/add_vital_screen.dart';

// Objective 4 - Health Tracking and Reports
import '../../features/health_tracking/screens/daily_health_screen.dart';
import '../../features/health_tracking/screens/health_reports_screen.dart';

// Objective 5 - Maternal and Child Health
import '../../features/maternal_child_health/screens/maternal_child_health_screen.dart';
import '../../features/maternal_child_health/screens/womens_wellness_screen.dart';
import '../../features/maternal_child_health/screens/supplement_reminders_screen.dart';
import '../../features/maternal_child_health/screens/child_growth_screen.dart';
import '../../features/maternal_child_health/screens/development_milestones_screen.dart';

import '../../core/widgets/main_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,

    initialLocation: '/home',

    // Health features - Use original MedMate authentication
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;

      final path = state.uri.path;

      final requiresHealthLogin = path == '/daily-health' ||
          path == '/health-reports' ||
          path == '/maternal-child-health' ||
          path == '/womens-wellness' ||
          path == '/supplement-reminders' ||
          path == '/child-growth' ||
          path == '/development-milestones';

      if (requiresHealthLogin && session == null) {
        return '/login';
      }

      // Preserve existing routing for other features
      return null;
    },

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/confirm-email',
        builder: (context, state) => EmailConfirmScreen(
          email: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          // Home
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),

          // Medicines
          GoRoute(
            path: '/medicines',
            builder: (context, state) => const MedicinesListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const AddEditMedicineScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => AddEditMedicineScreen(
                  medicineId: state.pathParameters['id'],
                ),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => MedicineDetailScreen(
                  medicineId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          // Reminders
          GoRoute(
            path: '/reminders',
            builder: (context, state) => const RemindersScreen(),
            routes: [
              GoRoute(
                path: 'add/:medicineId',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => AddScheduleScreen(
                  medicineId: state.pathParameters['medicineId']!,
                ),
              ),
            ],
          ),

          // Prescriptions
          GoRoute(
            path: '/prescriptions',
            builder: (context, state) => const PrescriptionsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const AddPrescriptionScreen(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => PrescriptionDetailScreen(
                  prescriptionId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          // Medical Documents
          GoRoute(
            path: '/documents',
            builder: (context, state) => const DocumentsScreen(),
          ),

          // Family and Caregiver
          GoRoute(
            path: '/family',
            builder: (context, state) => const FamilyScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const AddFamilyMemberScreen(),
              ),
              GoRoute(
                path: 'caregiver',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const CaregiverScreen(),
              ),
            ],
          ),

          // Medicine Search
          GoRoute(
            path: '/search',
            builder: (context, state) => const MedicineSearchScreen(),
          ),

          // Dose History
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),

          // Vaccinations
          GoRoute(
            path: '/vaccinations',
            builder: (context, state) => const VaccinationsScreen(),
          ),

          // User Profile
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const EditProfileScreen(),
              ),
            ],
          ),

          // Existing Health Vitals
          GoRoute(
            path: '/vitals',
            builder: (context, state) => const VitalsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const AddVitalScreen(),
              ),
            ],
          ),

          // Objective 4 - Daily Health Tracking
          GoRoute(
            path: '/daily-health',
            builder: (context, state) => const DailyHealthScreen(),
          ),

          // Objective 4 - Health Reports and Charts
          GoRoute(
            path: '/health-reports',
            builder: (context, state) => const HealthReportsScreen(),
          ),

          // Objective 4 - Nearby Healthcare
          GoRoute(
            path: '/nearby-healthcare',
            builder: (context, state) => const NearbyHealthcareScreen(),
          ),

          // Objective 4 - Government Healthcare Schemes
          GoRoute(
            path: '/government-schemes',
            builder: (context, state) => const GovernmentSchemesScreen(),
          ),

          // Objective 5 - Maternal and Child Health
          GoRoute(
            path: '/maternal-child-health',
            builder: (context, state) => const MaternalChildHealthScreen(),
          ),

          // Objective 5 - Women's Wellness
          GoRoute(
            path: '/womens-wellness',
            builder: (context, state) => const WomensWellnessScreen(),
          ),

// Objective 5 - Supplement Reminders
          GoRoute(
            path: '/supplement-reminders',
            builder: (context, state) => const SupplementRemindersScreen(),
          ),

          // Objective 5 - Child Growth Tracking
          GoRoute(
            path: '/child-growth',
            builder: (context, state) => const ChildGrowthScreen(),
          ),

          // Objective 5 - Development Milestones
          GoRoute(
            path: '/development-milestones',
            builder: (context, state) => const DevelopmentMilestonesScreen(),
          ),
        ],
      ),
    ],
  );
}
