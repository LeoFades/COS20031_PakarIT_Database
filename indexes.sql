USE PakarIT;

-- ==========================================
-- OPTIMIZED INDEXES (Read-heavy operations only)
-- ==========================================

-- Critical for login performance
CREATE INDEX idx_appuser_username ON AppUser(Username);
CREATE INDEX idx_appuser_role ON AppUser(RoleId);

-- Critical for doctor-patient relationships
CREATE INDEX idx_patient_doctor ON Patient(DoctorId);
CREATE INDEX idx_prescription_patient ON Prescription(PatientId);
CREATE INDEX idx_prescription_doctor ON Prescription(DoctorId);

-- Critical for medication lookups
CREATE INDEX idx_prescription_med_prescription ON PrescriptionMedication(PrescriptionId);
CREATE INDEX idx_prescription_med_current ON PrescriptionMedication(IsCurrent, Status);

-- Critical for audit searches
CREATE INDEX idx_audit_table_action ON AuditLog(TableName, Action);
CREATE INDEX idx_audit_timestamp ON AuditLog(ChangedAt);
