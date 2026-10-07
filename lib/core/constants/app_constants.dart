class AppConstants {
  // Supabase — replace with your project values from supabase.com → Settings → API
  static const String supabaseUrl = 'https://wilzmxpfbdzfcebtlhed.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndpbHpteHBmYmR6ZmNlYnRsaGVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3NzgwMDksImV4cCI6MjEwNjM1NDAwOX0.ODAX4Jvon8L5NF-4zBz_IaXr0EvBqC-jG-4xWESJPGY';

  // App Info
  static const String appName = 'MEDMATE';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your Smart Medicine Companion';

  // Storage Buckets
  static const String prescriptionsBucket = 'prescriptions';
  static const String medicalDocsBucket = 'medical-documents';
  static const String avatarsBucket = 'avatars';
  static const String vaccinationsBucket = 'vaccinations';

  // Notification Channel IDs
  static const String medicineReminderChannelId = 'medicine_reminder';
  static const String refillReminderChannelId = 'refill_reminder';
  static const String caregiverAlertChannelId = 'caregiver_alert';
  static const String vaccinationReminderChannelId = 'vaccination_reminder';

  // SharedPreferences Keys
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefThemeMode = 'theme_mode';
  static const String prefSelectedProfile = 'selected_profile';

  // Medicine Forms
  static const List<String> medicineForms = [
    'tablet', 'capsule', 'syrup', 'injection',
    'drops', 'cream', 'inhaler', 'patch', 'other'
  ];

  // Frequency Options
  static const List<String> frequencyOptions = [
    'daily', 'twice_daily', 'thrice_daily',
    'every_x_hours', 'specific_days', 'as_needed'
  ];

  // Frequency Display Names
  static const Map<String, String> frequencyDisplayNames = {
    'daily': 'Once Daily',
    'twice_daily': 'Twice Daily',
    'thrice_daily': 'Three Times Daily',
    'every_x_hours': 'Every X Hours',
    'specific_days': 'Specific Days',
    'as_needed': 'As Needed',
  };

  // Days of Week
  static const List<String> daysOfWeek = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  // Blood Groups
  static const List<String> bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  // Vital Types
  static const Map<String, String> vitalTypeLabels = {
    'blood_pressure': 'Blood Pressure',
    'blood_sugar': 'Blood Sugar',
    'weight': 'Weight',
    'temperature': 'Temperature',
    'heart_rate': 'Heart Rate',
    'oxygen_saturation': 'SpO₂',
    'other': 'Other',
  };

  // Document Types
  static const Map<String, String> docTypeLabels = {
    'prescription': 'Prescription',
    'lab_report': 'Lab Report',
    'scan': 'Scan / X-Ray',
    'vaccination': 'Vaccination',
    'insurance': 'Insurance',
    'other': 'Other',
  };
}
