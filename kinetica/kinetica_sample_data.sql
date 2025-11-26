-- ==========================================
-- SAMPLE DATA FOR TESTING (KINETICA VERSION)
-- ==========================================
-- Note: All IDs must be manually managed in Kinetica
-- Encryption must be handled at application level

-- Create sample users
-- Note: Password hashing should be done at application level
INSERT INTO AppUser (AppUserId, Username, PasswordHash, RoleId, IsLocked, FailedAttempts, CreatedAt, UpdatedAt) VALUES
(1, 'admin01', 'hashed_password_here', 1, FALSE, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 'dralice', 'hashed_password_here', 2, FALSE, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(3, 'drbob', 'hashed_password_here', 2, FALSE, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO Admin (AdminId, Name, AppUserId, IsActive, CreatedAt) VALUES
(1, 'System Administrator', 1, TRUE, CURRENT_TIMESTAMP);

-- Note: ContactInfoEncrypted should be encrypted at application level
-- For testing, you can insert NULL or use application-level encryption
INSERT INTO Doctor (DoctorId, Name, Specialization, ContactInfoEncrypted, AppUserId, AdminId, IsActive, CreatedAt) VALUES
(1, 'Dr. Alice Smith', 'Cardiology', NULL, 2, 1, TRUE, CURRENT_TIMESTAMP),
(2, 'Dr. Bob Wilson', 'Pediatrics', NULL, 3, 1, TRUE, CURRENT_TIMESTAMP);

-- Create sample patients
-- Note: Sensitive data encryption must be handled at application level
INSERT INTO Patient (PatientId, Name, DateOfBirth, Gender, PhoneEncrypted, EmailEncrypted, 
                     AddressEncrypted, EmergencyContactEncrypted, DataHash, ComplianceStatus,
                     DoctorId, IsActive, CreatedAt) VALUES
(1, 'John Doe', DATE '1985-06-15', 'Male', NULL, NULL, NULL, NULL, NULL, 'Good', 1, TRUE, CURRENT_TIMESTAMP),
(2, 'Jane Smith', DATE '1990-08-22', 'Female', NULL, NULL, NULL, NULL, NULL, 'Good', 2, TRUE, CURRENT_TIMESTAMP);

-- Create sample medications
INSERT INTO Medication (MedicationId, Name, DosageForm, Strength, Instructions, IsActive) VALUES
(1, 'Lisinopril', 'Tablet', '10mg', 'Take once daily with water', TRUE),
(2, 'Metformin', 'Tablet', '500mg', 'Take with meals twice daily', TRUE),
(3, 'Ibuprofen', 'Tablet', '200mg', 'Take as needed for pain', TRUE);

-- Create sample prescriptions
INSERT INTO Prescription (PrescriptionId, DoctorId, PatientId, CreatedAt, Notes, Status) VALUES
(1, 1, 1, CURRENT_TIMESTAMP, 'Hypertension management', 'Active'),
(2, 2, 2, CURRENT_TIMESTAMP, 'Diabetes management', 'Active');

INSERT INTO PrescriptionMedication (PressMedId, PrescriptionId, MedicationId, DosageAmount, 
                                    TimingId, StartDate, EndDate, Status, Version, IsCurrent) VALUES
(1, 1, 1, 1, 1, DATE '2024-01-01', DATE '2024-06-01', 'Active', 1, TRUE),
(2, 2, 2, 1, 1, DATE '2024-01-01', DATE '2024-06-01', 'Active', 1, TRUE);

-- Create sample schedules
INSERT INTO PrescriptionSchedule (ScheduleId, PressMedId, DayOfWeek, TimeOfDay, DosageAmount, IsActive) VALUES
(1, 1, 'Monday', TIME '09:00:00', 1, TRUE),
(2, 1, 'Monday', TIME '14:00:00', 1, TRUE),
(3, 1, 'Monday', TIME '18:00:00', 1, TRUE),
(4, 1, 'Wednesday', TIME '09:00:00', 1, TRUE),
(5, 1, 'Wednesday', TIME '14:00:00', 1, TRUE),
(6, 1, 'Wednesday', TIME '18:00:00', 1, TRUE),
(7, 1, 'Friday', TIME '09:00:00', 1, TRUE),
(8, 1, 'Friday', TIME '14:00:00', 1, TRUE),
(9, 1, 'Friday', TIME '18:00:00', 1, TRUE);

-- Create sample symptoms and side effects
INSERT INTO Symptom (SymptomId, Name, Description, IsActive) VALUES
(1, 'Headache', 'Pain in the head region', TRUE),
(2, 'Nausea', 'Feeling of sickness with inclination to vomit', TRUE),
(3, 'Dizziness', 'Feeling of spinning or loss of balance', TRUE);

INSERT INTO SideEffect (SideEffectId, Name, Description, IsActive) VALUES
(1, 'Dry Cough', 'Persistent cough without mucus', TRUE),
(2, 'Fatigue', 'Extreme tiredness and lack of energy', TRUE),
(3, 'Upset Stomach', 'Gastrointestinal discomfort', TRUE);

-- Create sample reminders
INSERT INTO Reminder (ReminderId, PatientId, PressMedId, TimingId, Status, ReminderTime) VALUES
(1, 1, 1, 1, 'Active', TIME '09:00:00'),
(2, 2, 2, 1, 'Active', TIME '09:00:00');

-- Create sample compliance records
INSERT INTO Compliance (ComplianceId, ReminderId, TakenAt, DosageTaken, Status, Notes) VALUES
(1, 1, CURRENT_TIMESTAMP, 1, 'Taken', 'Medication taken on time'),
(2, 2, CURRENT_TIMESTAMP, 1, 'Taken', 'Medication taken on time');

-- Sample audit log entry
INSERT INTO AuditLog (AuditId, ChangedAt, AppUserId, TableName, Action, RowPrimaryKey, NewData, Notes) VALUES
(1, CURRENT_TIMESTAMP, 1, 'Patient', 'INSERT', 'PatientId=1', '{"Name":"John Doe"}', 'Initial patient record');

SELECT 'Kinetica database schema created successfully!' AS Status;
SELECT 'Note: Stored procedures, triggers, and auto-increment must be handled in application code' AS Important;
