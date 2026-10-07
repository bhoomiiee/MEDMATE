import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static SupabaseClient get client => _client;

  // ── Auth helpers ──────────────────────────────────────────────────────────
  static User? get currentUser => _client.auth.currentUser;
  static String? get currentUserId => _client.auth.currentUser?.id;
  static Session? get currentSession => _client.auth.currentSession;

  // ── Profile ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final res = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return res;
  }

  static Future<void> upsertProfile(Map<String, dynamic> data) async {
    await _client.from('profiles').upsert(data);
  }

  // ── Family Members ────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await _client
        .from('family_members')
        .select()
        .eq('owner_id', userId)
        .order('full_name');
  }

  static Future<Map<String, dynamic>> addFamilyMember(
      Map<String, dynamic> data) async {
    final res = await _client
        .from('family_members')
        .insert(data)
        .select()
        .single();
    return res;
  }

  static Future<void> updateFamilyMember(
      String id, Map<String, dynamic> data) async {
    await _client.from('family_members').update(data).eq('id', id);
  }

  static Future<void> deleteFamilyMember(String id) async {
    await _client.from('family_members').delete().eq('id', id);
  }

  // ── User Medicines ────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getUserMedicines({
    String? familyMemberId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];
    var query = _client
        .from('user_medicines')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true);
    if (familyMemberId != null) {
      query = query.eq('family_member_id', familyMemberId);
    } else {
      query = query.isFilter('family_member_id', null);
    }
    return await query.order('name');
  }

  static Future<Map<String, dynamic>?> getMedicine(String id) async {
    return await _client
        .from('user_medicines')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  static Future<Map<String, dynamic>> addMedicine(
      Map<String, dynamic> data) async {
    final res = await _client
        .from('user_medicines')
        .insert(data)
        .select()
        .single();
    return res;
  }

  static Future<void> updateMedicine(
      String id, Map<String, dynamic> data) async {
    await _client
        .from('user_medicines')
        .update(data)
        .eq('id', id);
  }

  static Future<void> deleteMedicine(String id) async {
    await _client
        .from('user_medicines')
        .update({'is_active': false})
        .eq('id', id);
  }

  // ── Schedules ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getSchedules(
      String medicineid) async {
    return await _client
        .from('schedules')
        .select()
        .eq('user_medicine_id', medicineid)
        .eq('is_active', true)
        .order('created_at');
  }

  static Future<List<Map<String, dynamic>>> getAllActiveSchedules() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await _client
        .from('schedules')
        .select('*, user_medicines(name, form, dosage, color)')
        .eq('user_id', userId)
        .eq('is_active', true);
  }

  static Future<Map<String, dynamic>> addSchedule(
      Map<String, dynamic> data) async {
    final res = await _client
        .from('schedules')
        .insert(data)
        .select()
        .single();
    return res;
  }

  static Future<void> updateSchedule(
      String id, Map<String, dynamic> data) async {
    await _client.from('schedules').update(data).eq('id', id);
  }

  static Future<void> deleteSchedule(String id) async {
    await _client
        .from('schedules')
        .update({'is_active': false})
        .eq('id', id);
  }

  // ── Reminder Logs ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getReminderLogs({
    DateTime? from,
    DateTime? to,
    String? scheduleId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];
    var query = _client
        .from('reminder_logs')
        .select('*, schedules(user_medicines(name, form, dosage, color))')
        .eq('user_id', userId);
    if (from != null) query = query.gte('scheduled_at', from.toIso8601String());
    if (to != null) query = query.lte('scheduled_at', to.toIso8601String());
    if (scheduleId != null) query = query.eq('schedule_id', scheduleId);
    return await query.order('scheduled_at', ascending: false);
  }

  static Future<void> upsertReminderLog(Map<String, dynamic> data) async {
    await _client.from('reminder_logs').upsert(data);
  }

  static Future<void> markReminderTaken(String logId) async {
    await _client.from('reminder_logs').update({
      'status': 'taken',
      'taken_at': DateTime.now().toIso8601String(),
    }).eq('id', logId);
  }

  static Future<void> markReminderSkipped(String logId) async {
    await _client
        .from('reminder_logs')
        .update({'status': 'skipped'})
        .eq('id', logId);
  }

  // ── Prescriptions ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPrescriptions({
    String? familyMemberId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];
    var query = _client
        .from('prescriptions')
        .select('*, prescription_items(*)')
        .eq('user_id', userId);
    if (familyMemberId != null) {
      query = query.eq('family_member_id', familyMemberId);
    }
    return await query.order('prescribed_date', ascending: false);
  }

  static Future<Map<String, dynamic>?> getPrescription(String id) async {
    return await _client
        .from('prescriptions')
        .select('*, prescription_items(*)')
        .eq('id', id)
        .maybeSingle();
  }

  static Future<Map<String, dynamic>> addPrescription(
      Map<String, dynamic> data) async {
    final res = await _client
        .from('prescriptions')
        .insert(data)
        .select()
        .single();
    return res;
  }

  static Future<void> addPrescriptionItems(
      List<Map<String, dynamic>> items) async {
    await _client.from('prescription_items').insert(items);
  }

  static Future<void> deletePrescription(String id) async {
    await _client.from('prescriptions').delete().eq('id', id);
  }

  // ── Medical Documents ─────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMedicalDocuments({
    String? familyMemberId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];
    var query = _client
        .from('medical_documents')
        .select()
        .eq('user_id', userId);
    if (familyMemberId != null) {
      query = query.eq('family_member_id', familyMemberId);
    }
    return await query.order('created_at', ascending: false);
  }

  static Future<Map<String, dynamic>> addMedicalDocument(
      Map<String, dynamic> data) async {
    final res = await _client
        .from('medical_documents')
        .insert(data)
        .select()
        .single();
    return res;
  }

  static Future<void> deleteMedicalDocument(String id) async {
    await _client.from('medical_documents').delete().eq('id', id);
  }

  // ── Vaccinations ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getVaccinations({
    String? familyMemberId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];
    var query = _client
        .from('vaccinations')
        .select()
        .eq('user_id', userId);
    if (familyMemberId != null) {
      query = query.eq('family_member_id', familyMemberId);
    }
    return await query.order('administered_date', ascending: false);
  }

  static Future<Map<String, dynamic>> addVaccination(
      Map<String, dynamic> data) async {
    final res = await _client
        .from('vaccinations')
        .insert(data)
        .select()
        .single();
    return res;
  }

  static Future<void> updateVaccination(
      String id, Map<String, dynamic> data) async {
    await _client.from('vaccinations').update(data).eq('id', id);
  }

  // ── Health Vitals ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getVitals({
    String? vitalType,
    String? familyMemberId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];
    var query = _client
        .from('health_vitals')
        .select()
        .eq('user_id', userId);
    if (vitalType != null) query = query.eq('vital_type', vitalType);
    if (familyMemberId != null) {
      query = query.eq('family_member_id', familyMemberId);
    }
    return await query.order('recorded_at', ascending: false);
  }

  static Future<Map<String, dynamic>> addVital(
      Map<String, dynamic> data) async {
    final res = await _client
        .from('health_vitals')
        .insert(data)
        .select()
        .single();
    return res;
  }

  // ── Caregiver ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCaregiverConnections() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await _client
        .from('caregiver_connections')
        .select('*, profiles!caregiver_connections_caregiver_id_fkey(full_name, avatar_url)')
        .or('patient_id.eq.$userId,caregiver_id.eq.$userId')
        .order('created_at', ascending: false);
  }

  static Future<List<Map<String, dynamic>>> getCaregiverAlerts() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await _client
        .from('caregiver_alerts')
        .select()
        .eq('patient_id', userId)
        .eq('is_read', false)
        .order('created_at', ascending: false);
  }

  static Future<void> markAlertRead(String alertId) async {
    await _client
        .from('caregiver_alerts')
        .update({'is_read': true})
        .eq('id', alertId);
  }

  static Future<Map<String, dynamic>> sendCaregiverInvite(
      String caregiverEmail) async {
    // Look up caregiver profile by email via auth (handled server-side with Edge Function)
    // For now return placeholder; real implementation needs an Edge Function
    throw UnimplementedError('Requires Supabase Edge Function for email lookup');
  }

  // ── Medicine Search ───────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> searchMedicineDatabase(
      String query) async {
    return await _client
        .from('medicine_database')
        .select()
        .or('name.ilike.%$query%,generic_name.ilike.%$query%')
        .order('name')
        .limit(20);
  }

  // ── File Upload ───────────────────────────────────────────────────────────
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    Uint8List? bytes,
    File? file,
    String? contentType,
  }) async {
    final opts = FileOptions(
      contentType: contentType ?? 'application/octet-stream',
      upsert: true,
    );

    Future<void> doUpload() async {
      if (bytes != null) {
        await _client.storage.from(bucket).uploadBinary(path, bytes, fileOptions: opts);
      } else if (file != null) {
        await _client.storage.from(bucket).upload(path, file, fileOptions: opts);
      } else {
        throw Exception('Neither bytes nor file provided for upload');
      }
    }

    try {
      await doUpload();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('bucket not found') || msg.contains('not found')) {
        try {
          await _client.storage.createBucket(bucket, const BucketOptions(public: true));
          await doUpload();
        } catch (_) {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  static Future<void> deleteFile(String bucket, String path) async {
    await _client.storage.from(bucket).remove([path]);
  }

  // ── Refill Reminders ──────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getLowStockMedicines() async {
    final userId = currentUserId;
    if (userId == null) return [];
    return await _client
        .from('user_medicines')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .filter('current_stock', 'lte', 'refill_threshold');
  }

  static Future<void> updateStock(String medicineId, int newStock) async {
    await _client
        .from('user_medicines')
        .update({'current_stock': newStock})
        .eq('id', medicineId);
  }
}
