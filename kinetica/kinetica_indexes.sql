-- ==========================================
-- KINETICA INDEXES
-- ==========================================
-- Note: In Kinetica, indexes are created separately from table creation
-- Kinetica uses column indexes (B-tree) for performance optimization

-- Critical for login performance
CREATE INDEX idx_appuser_username ON AppUser(Username);
CREATE INDEX idx_appuser_role ON AppUser(RoleId);

-- Critical for doctor-patient relationships
CREATE INDEX idx_patient_doctor ON Patient(DoctorId);
CREATE INDEX idx_prescription_patient ON Prescription(PatientId);
CREATE INDEX idx_prescription_doctor ON Prescription(DoctorId);

-- Critical for medication lookups
CREATE INDEX idx_prescription_med_prescription ON PrescriptionMedication(PrescriptionId);
CREATE INDEX idx_prescription_med_medication ON PrescriptionMedication(MedicationId);
-- Note: Cannot create composite index on (IsCurrent, Status) in single statement
CREATE INDEX idx_prescription_med_current ON PrescriptionMedication(IsCurrent);
CREATE INDEX idx_prescription_med_status ON PrescriptionMedication(Status);

-- Critical for audit searches
CREATE INDEX idx_audit_table ON AuditLog(TableName);
CREATE INDEX idx_audit_action ON AuditLog(Action);
CREATE INDEX idx_audit_timestamp ON AuditLog(ChangedAt);

-- Additional indexes for common queries
CREATE INDEX idx_patient_compliance ON Patient(ComplianceStatus);
CREATE INDEX idx_patient_active ON Patient(IsActive);
CREATE INDEX idx_doctor_active ON Doctor(IsActive);
CREATE INDEX idx_medication_active ON Medication(IsActive);

-- Indexes for side effects and symptoms
CREATE INDEX idx_patsideeff_patient ON PatientSideEffect(PatientId);
CREATE INDEX idx_patsideeff_presmed ON PatientSideEffect(PressMedId);
CREATE INDEX idx_patsideeff_review ON PatientSideEffect(RequiresDoctorReview);
CREATE INDEX idx_patobssym_patient ON PatientObservedSymptom(PatientId);

-- Indexes for reminder and compliance
CREATE INDEX idx_reminder_patient ON Reminder(PatientId);
CREATE INDEX idx_reminder_presmed ON Reminder(PressMedId);
CREATE INDEX idx_reminder_status ON Reminder(Status);
CREATE INDEX idx_compliance_reminder ON Compliance(ReminderId);
CREATE INDEX idx_compliance_status ON Compliance(Status);

-- Schedule indexes
CREATE INDEX idx_schedule_presmed ON PrescriptionSchedule(PressMedId);
CREATE INDEX idx_schedule_day ON PrescriptionSchedule(DayOfWeek);
