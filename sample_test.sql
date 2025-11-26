USE PakarIT;


-- ==========================================
-- SAMPLE DATA FOR TESTING
-- ==========================================

-- Create sample users
INSERT INTO AppUser (Username, PasswordHash, RoleId) VALUES
('admin01', SHA2('adminpass123', 256), (SELECT RoleId FROM UserRole WHERE RoleCode = 'admin')),
('dralice', SHA2('doctorpass123', 256), (SELECT RoleId FROM UserRole WHERE RoleCode = 'doctor')),
('drbob', SHA2('doctorpass456', 256), (SELECT RoleId FROM UserRole WHERE RoleCode = 'doctor'));

INSERT INTO Admin (Name, AppUserId) VALUES
('System Administrator', (SELECT AppUserId FROM AppUser WHERE Username = 'admin01'));

INSERT INTO Doctor (Name, Specialization, ContactInfoEncrypted, AppUserId, AdminId) VALUES
('Dr. Alice Smith', 'Cardiology', AES_ENCRYPT('alice@hospital.com|123-456-7890', @enc_key), 
 (SELECT AppUserId FROM AppUser WHERE Username = 'dralice'), 1),
('Dr. Bob Wilson', 'Pediatrics', AES_ENCRYPT('bob@hospital.com|123-456-7891', @enc_key),
 (SELECT AppUserId FROM AppUser WHERE Username = 'drbob'), 1);

-- Create sample patient using secure procedure
CALL sp_create_secure_patient('John Doe', '1985-06-15', 'Male', '123-456-7890', 'john@email.com', '123 Main St', '987-654-3210', 1);
CALL sp_create_secure_patient('Jane Smith', '1990-08-22', 'Female', '123-456-7891', 'jane@email.com', '456 Oak Ave', '987-654-3211', 2);

-- Create sample medications
INSERT INTO Medication (Name, DosageForm, Strength, Instructions) VALUES
('Lisinopril', 'Tablet', '10mg', 'Take once daily with water'),
('Metformin', 'Tablet', '500mg', 'Take with meals twice daily'),
('Ibuprofen', 'Tablet', '200mg', 'Take as needed for pain');

-- Create sample prescription
INSERT INTO Prescription (DoctorId, PatientId, Notes) VALUES
(1, 1, 'Hypertension management'),
(2, 2, 'Diabetes management');

INSERT INTO PrescriptionMedication (PrescriptionId, MedicationId, DosageAmount, TimingId, StartDate, EndDate) VALUES
(1, 1, 1, (SELECT TimingId FROM MedicationTiming WHERE Name = 'Morning'), '2024-01-01', '2024-06-01'),
(2, 2, 1, (SELECT TimingId FROM MedicationTiming WHERE Name = 'Morning'), '2024-01-01', '2024-06-01');

-- Create complex schedule: Mon/Wed/Fri at 9am, 2pm, 6pm
CALL sp_record_medication_schedule(1, 'Monday', '["09:00:00", "14:00:00", "18:00:00"]');
CALL sp_record_medication_schedule(1, 'Wednesday', '["09:00:00", "14:00:00", "18:00:00"]');
CALL sp_record_medication_schedule(1, 'Friday', '["09:00:00", "14:00:00", "18:00:00"]');

-- Test prescription versioning
CALL sp_update_prescription_dosage(1, 2, 'Increased dosage due to blood pressure readings', 1);

SELECT 'Database schema created successfully with simplified structure, automatic alerts, and optimized indexes!' AS Status;