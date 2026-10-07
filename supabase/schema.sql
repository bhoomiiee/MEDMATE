-- ============================================================
-- MEDMATE - Supabase Database Schema
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- PROFILES
-- ============================================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  date_of_birth DATE,
  gender TEXT CHECK (gender IN ('male', 'female', 'other')),
  phone TEXT,
  blood_group TEXT,
  allergies TEXT[],
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FAMILY MEMBERS
-- ============================================================
CREATE TABLE family_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  relation TEXT NOT NULL,
  phone TEXT,
  date_of_birth DATE,
  gender TEXT CHECK (gender IN ('male', 'female', 'other')),
  blood_group TEXT,
  allergies TEXT[],
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MEDICINES DATABASE (global reference)
-- ============================================================
CREATE TABLE medicine_database (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  generic_name TEXT,
  category TEXT,
  form TEXT CHECK (form IN ('tablet', 'capsule', 'syrup', 'injection', 'drops', 'cream', 'inhaler', 'patch', 'other')),
  description TEXT,
  uses TEXT[],
  side_effects TEXT[],
  precautions TEXT[],
  contraindications TEXT[],
  manufacturer TEXT,
  requires_prescription BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- USER MEDICINES (medicines added by a user for themselves or family)
-- ============================================================
CREATE TABLE user_medicines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  family_member_id UUID REFERENCES family_members(id) ON DELETE CASCADE,
  medicine_db_id UUID REFERENCES medicine_database(id),
  name TEXT NOT NULL,
  generic_name TEXT,
  form TEXT CHECK (form IN ('tablet', 'capsule', 'syrup', 'injection', 'drops', 'cream', 'inhaler', 'patch', 'other')),
  dosage TEXT NOT NULL,
  unit TEXT DEFAULT 'mg',
  color TEXT,
  notes TEXT,
  current_stock INTEGER DEFAULT 0,
  refill_threshold INTEGER DEFAULT 5,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SCHEDULES (reminder schedules per medicine)
-- ============================================================
CREATE TABLE schedules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_medicine_id UUID NOT NULL REFERENCES user_medicines(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'twice_daily', 'thrice_daily', 'every_x_hours', 'specific_days', 'as_needed')),
  times TEXT[] NOT NULL,            -- e.g. ['08:00', '20:00']
  days_of_week INTEGER[],           -- 0=Mon..6=Sun, null means every day
  interval_hours INTEGER,           -- for every_x_hours
  start_date DATE NOT NULL,
  end_date DATE,
  with_food BOOLEAN DEFAULT FALSE,
  instructions TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- REMINDER LOGS (actual reminder events)
-- ============================================================
CREATE TABLE reminder_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  scheduled_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'taken', 'skipped', 'snoozed')),
  taken_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PRESCRIPTIONS
-- ============================================================
CREATE TABLE prescriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  family_member_id UUID REFERENCES family_members(id) ON DELETE CASCADE,
  doctor_name TEXT,
  hospital_clinic TEXT,
  prescribed_date DATE,
  diagnosis TEXT,
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PRESCRIPTION ITEMS (medicines in a prescription)
-- ============================================================
CREATE TABLE prescription_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  prescription_id UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
  medicine_name TEXT NOT NULL,
  dosage TEXT,
  frequency TEXT,
  duration TEXT,
  instructions TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MEDICAL DOCUMENTS (uploaded files)
-- ============================================================
CREATE TABLE medical_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  family_member_id UUID REFERENCES family_members(id) ON DELETE CASCADE,
  prescription_id UUID REFERENCES prescriptions(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  doc_type TEXT CHECK (doc_type IN ('prescription', 'lab_report', 'scan', 'vaccination', 'insurance', 'other')),
  file_url TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size INTEGER,
  mime_type TEXT,
  notes TEXT,
  document_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- VACCINATIONS
-- ============================================================
CREATE TABLE vaccinations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  family_member_id UUID REFERENCES family_members(id) ON DELETE CASCADE,
  vaccine_name TEXT NOT NULL,
  dose_number INTEGER DEFAULT 1,
  administered_date DATE,
  next_due_date DATE,
  hospital_clinic TEXT,
  notes TEXT,
  certificate_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- HEALTH VITALS (optional health tracking)
-- ============================================================
CREATE TABLE health_vitals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  family_member_id UUID REFERENCES family_members(id) ON DELETE CASCADE,
  vital_type TEXT NOT NULL CHECK (vital_type IN ('blood_pressure', 'blood_sugar', 'weight', 'temperature', 'heart_rate', 'oxygen_saturation', 'other')),
  value_1 NUMERIC,   -- systolic / fasting / main value
  value_2 NUMERIC,   -- diastolic / post-prandial / secondary
  unit TEXT,
  notes TEXT,
  recorded_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- CAREGIVER CONNECTIONS
-- ============================================================
CREATE TABLE caregiver_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  caregiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'revoked')),
  permissions TEXT[] DEFAULT ARRAY['view_medicines', 'view_reminders'],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(patient_id, caregiver_id)
);

-- ============================================================
-- CAREGIVER ALERTS
-- ============================================================
CREATE TABLE caregiver_alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  connection_id UUID NOT NULL REFERENCES caregiver_connections(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  alert_type TEXT NOT NULL CHECK (alert_type IN ('missed_dose', 'low_stock', 'refill_due', 'vaccination_due', 'general')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- REFILL REMINDERS
-- ============================================================
CREATE TABLE refill_reminders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_medicine_id UUID NOT NULL REFERENCES user_medicines(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  remind_at TIMESTAMPTZ NOT NULL,
  is_sent BOOLEAN DEFAULT FALSE,
  is_dismissed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminder_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE vaccinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_vitals ENABLE ROW LEVEL SECURITY;
ALTER TABLE caregiver_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE caregiver_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE refill_reminders ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "Users can manage own profile"
  ON profiles FOR ALL USING (auth.uid() = id);

-- Family members
CREATE POLICY "Users manage own family members"
  ON family_members FOR ALL USING (auth.uid() = owner_id);

-- User medicines
CREATE POLICY "Users manage own medicines"
  ON user_medicines FOR ALL USING (auth.uid() = user_id);

-- Schedules
CREATE POLICY "Users manage own schedules"
  ON schedules FOR ALL USING (auth.uid() = user_id);

-- Reminder logs
CREATE POLICY "Users manage own reminder logs"
  ON reminder_logs FOR ALL USING (auth.uid() = user_id);

-- Prescriptions
CREATE POLICY "Users manage own prescriptions"
  ON prescriptions FOR ALL USING (auth.uid() = user_id);

-- Prescription items (via prescription ownership)
CREATE POLICY "Users manage own prescription items"
  ON prescription_items FOR ALL
  USING (prescription_id IN (SELECT id FROM prescriptions WHERE user_id = auth.uid()));

-- Medical documents
CREATE POLICY "Users manage own documents"
  ON medical_documents FOR ALL USING (auth.uid() = user_id);

-- Vaccinations
CREATE POLICY "Users manage own vaccinations"
  ON vaccinations FOR ALL USING (auth.uid() = user_id);

-- Health vitals
CREATE POLICY "Users manage own vitals"
  ON health_vitals FOR ALL USING (auth.uid() = user_id);

-- Caregiver connections
CREATE POLICY "Users view own caregiver connections"
  ON caregiver_connections FOR ALL
  USING (auth.uid() = patient_id OR auth.uid() = caregiver_id);

-- Caregiver alerts
CREATE POLICY "Caregivers view own alerts"
  ON caregiver_alerts FOR ALL
  USING (
    connection_id IN (
      SELECT id FROM caregiver_connections
      WHERE caregiver_id = auth.uid() OR patient_id = auth.uid()
    )
  );

-- Refill reminders
CREATE POLICY "Users manage own refill reminders"
  ON refill_reminders FOR ALL USING (auth.uid() = user_id);

-- Medicine database is public read
ALTER TABLE medicine_database ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read medicine database"
  ON medicine_database FOR SELECT USING (TRUE);

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER family_members_updated_at BEFORE UPDATE ON family_members
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER user_medicines_updated_at BEFORE UPDATE ON user_medicines
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER schedules_updated_at BEFORE UPDATE ON schedules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER prescriptions_updated_at BEFORE UPDATE ON prescriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER vaccinations_updated_at BEFORE UPDATE ON vaccinations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER caregiver_connections_updated_at BEFORE UPDATE ON caregiver_connections
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- SEED: Sample Medicine Database
-- ============================================================
INSERT INTO medicine_database (name, generic_name, category, form, description, uses, side_effects, precautions, requires_prescription) VALUES
('Paracetamol 500mg', 'Paracetamol', 'Analgesic/Antipyretic', 'tablet', 'Common pain reliever and fever reducer.',
  ARRAY['Headache', 'Fever', 'Body pain', 'Mild arthritis'],
  ARRAY['Nausea', 'Stomach upset (rare)', 'Liver damage (overdose)'],
  ARRAY['Do not exceed 4g/day', 'Avoid alcohol', 'Caution in liver disease'],
  FALSE),
('Amoxicillin 500mg', 'Amoxicillin', 'Antibiotic', 'capsule', 'Broad-spectrum antibiotic for bacterial infections.',
  ARRAY['Respiratory infections', 'Ear infections', 'UTI', 'Skin infections'],
  ARRAY['Diarrhea', 'Rash', 'Nausea', 'Allergic reaction'],
  ARRAY['Complete the full course', 'Check for penicillin allergy', 'Take with food'],
  TRUE),
('Metformin 500mg', 'Metformin Hydrochloride', 'Antidiabetic', 'tablet', 'First-line medication for type 2 diabetes.',
  ARRAY['Type 2 diabetes', 'Prediabetes', 'PCOS'],
  ARRAY['Nausea', 'Diarrhea', 'Stomach upset', 'Lactic acidosis (rare)'],
  ARRAY['Take with meals', 'Monitor kidney function', 'Avoid in severe kidney disease'],
  TRUE),
('Amlodipine 5mg', 'Amlodipine Besylate', 'Antihypertensive', 'tablet', 'Calcium channel blocker for high blood pressure.',
  ARRAY['Hypertension', 'Angina', 'Coronary artery disease'],
  ARRAY['Ankle swelling', 'Flushing', 'Headache', 'Dizziness'],
  ARRAY['Do not stop suddenly', 'Avoid grapefruit juice', 'Monitor blood pressure'],
  TRUE),
('Omeprazole 20mg', 'Omeprazole', 'Proton Pump Inhibitor', 'capsule', 'Reduces stomach acid production.',
  ARRAY['GERD', 'Peptic ulcer', 'Acid reflux', 'Heartburn'],
  ARRAY['Headache', 'Diarrhea', 'Nausea', 'Vitamin B12 deficiency (long-term)'],
  ARRAY['Take 30 min before meal', 'Short-term use preferred', 'Check for drug interactions'],
  FALSE),
('Cetirizine 10mg', 'Cetirizine Hydrochloride', 'Antihistamine', 'tablet', 'Second-generation antihistamine for allergies.',
  ARRAY['Allergic rhinitis', 'Urticaria', 'Hay fever', 'Itching'],
  ARRAY['Drowsiness', 'Dry mouth', 'Headache'],
  ARRAY['Caution when driving', 'Avoid alcohol', 'Reduce dose in kidney disease'],
  FALSE),
('Vitamin D3 1000 IU', 'Cholecalciferol', 'Supplement', 'tablet', 'Vitamin D supplement for bone health.',
  ARRAY['Vitamin D deficiency', 'Bone health', 'Immune support', 'Calcium absorption'],
  ARRAY['Nausea (high doses)', 'Constipation (high doses)'],
  ARRAY['Do not exceed recommended dose', 'Monitor calcium levels'],
  FALSE),
('Iron Ferrous Sulfate 325mg', 'Ferrous Sulfate', 'Supplement', 'tablet', 'Iron supplement for anemia.',
  ARRAY['Iron deficiency anemia', 'Pregnancy supplementation'],
  ARRAY['Constipation', 'Nausea', 'Dark stools', 'Stomach cramps'],
  ARRAY['Take on empty stomach or with vitamin C', 'Avoid with antacids', 'Keep away from children'],
  FALSE);

-- ============================================================
-- STORAGE BUCKETS (for medical documents, prescriptions, avatars)
-- ============================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('medical-documents', 'medical-documents', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('prescriptions', 'prescriptions', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('vaccinations', 'vaccinations', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies
CREATE POLICY "Public Read Access" 
ON storage.objects FOR SELECT 
USING (true);

CREATE POLICY "Authenticated Uploads" 
ON storage.objects FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update their files" 
ON storage.objects FOR UPDATE 
USING (auth.uid() = owner);

CREATE POLICY "Users can delete their files" 
ON storage.objects FOR DELETE 
USING (auth.uid() = owner);

-- Migration updates
ALTER TABLE family_members ADD COLUMN IF NOT EXISTS phone TEXT;

