# MEDMATE – Setup Guide

## 1. Create the Flutter project scaffold

Open a terminal in the MEDMATE folder and run:

```bash
flutter create . --org com.yourcompany --project-name medmate
```

This generates the `android/`, `ios/`, `web/` folders without overwriting your existing `lib/` code.

---

## 2. Configure Supabase

1. Go to [https://supabase.com](https://supabase.com) and create a new project.
2. Run `supabase/schema.sql` in the Supabase SQL Editor (Dashboard → SQL Editor → New Query → paste → Run).
3. Open `lib/core/constants/app_constants.dart` and replace:
   ```dart
   static const String supabaseUrl    = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```
   with your project URL and anon key from **Project Settings → API**.

---

## 3. Create Supabase Storage Buckets

In Supabase Dashboard → Storage → New Bucket, create **four public buckets**:

| Bucket name        | Public |
|--------------------|--------|
| `prescriptions`    | ✅     |
| `medical-documents`| ✅     |
| `avatars`          | ✅     |
| `vaccinations`     | ✅     |

---

## 4. Android Permissions

Add these to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

Also add inside the `<application>` tag (required for awesome_notifications):

```xml
<receiver
    android:name="me.codebell.awesomenotifications.AwesomeNotificationsBroadcastReceiver"
    android:enabled="true"
    android:exported="false">
</receiver>
```

---

## 5. iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>MEDMATE needs access to upload medical documents.</string>
<key>NSCameraUsageDescription</key>
<string>MEDMATE needs camera access to scan prescriptions.</string>
```

---

## 6. Install Dependencies

```bash
flutter pub get
```

---

## 7. Run the App

```bash
flutter run
```

---

## App Architecture

```
lib/
├── main.dart                        # App entry point
├── core/
│   ├── constants/app_constants.dart # Supabase keys, enums, lists
│   ├── routing/app_router.dart      # go_router with ShellRoute
│   ├── services/
│   │   ├── supabase_service.dart    # All DB CRUD operations
│   │   ├── auth_service.dart        # Auth (signUp/signIn/signOut)
│   │   └── notification_service.dart# awesome_notifications
│   ├── theme/app_theme.dart         # Colors + ThemeData
│   └── widgets/                     # Shared widgets
└── features/
    ├── auth/          # Splash, Login, Register, Profile Setup
    ├── home/          # Dashboard with today's schedule & stats
    ├── medicines/     # List, Add/Edit, Detail + stock management
    ├── reminders/     # Calendar view, Add Schedule
    ├── prescriptions/ # List, Add, Detail
    ├── documents/     # Upload & manage medical files
    ├── family/        # Family members, Caregivers, Alerts
    ├── search/        # Medicine database search
    ├── history/       # Dose adherence history & stats
    ├── vaccinations/  # Track & get reminders
    ├── vitals/        # Blood pressure, sugar, weight, etc.
    └── profile/       # View & edit profile
```

---

## Database Tables (Supabase)

| Table                   | Purpose                                  |
|-------------------------|------------------------------------------|
| `profiles`              | User profile data                        |
| `family_members`        | Dependents managed by the user           |
| `medicine_database`     | Global medicine reference (seeded)       |
| `user_medicines`        | User's personal medicine list            |
| `schedules`             | Reminder schedules per medicine          |
| `reminder_logs`         | Taken / skipped history per dose         |
| `prescriptions`         | Digital prescription records             |
| `prescription_items`    | Medicines within a prescription          |
| `medical_documents`     | Uploaded files (PDF, images)             |
| `vaccinations`          | Vaccination history + due dates          |
| `health_vitals`         | BP, sugar, weight, temp, HR, SpO2        |
| `caregiver_connections` | Patient ↔ caregiver relationships        |
| `caregiver_alerts`      | Missed dose / low stock alerts           |
| `refill_reminders`      | Automated refill reminders               |

---

> MEDMATE is a supportive tool and does not replace professional medical advice.
