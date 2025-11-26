SET @enc_key = 'MySuperSecretKey123';

-- ==========================================
-- DATABASE SETUP & CLEANUP
-- ==========================================
CREATE DATABASE IF NOT EXISTS MedicalManagementSystem;
USE MedicalManagementSystem;

SET FOREIGN_KEY_CHECKS = 0;

-- Drop views
DROP VIEW IF EXISTS PatientPublic;
DROP VIEW IF EXISTS DoctorPublic;
DROP VIEW IF EXISTS SystemOverview;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS AuditLog;
DROP TABLE IF EXISTS Compliance;
DROP TABLE IF EXISTS Reminder;
DROP TABLE IF EXISTS PrescriptionSchedule;
DROP TABLE IF EXISTS PatientSideEffect;
DROP TABLE IF EXISTS PatientObservedSymptom;
DROP TABLE IF EXISTS PatientVital;
DROP TABLE IF EXISTS PrescriptionMedication;
DROP TABLE IF EXISTS Prescription;
DROP TABLE IF EXISTS SideEffect;
DROP TABLE IF EXISTS Symptom;
DROP TABLE IF EXISTS Medication;
DROP TABLE IF EXISTS MedicationTiming;
DROP TABLE IF EXISTS Patient;
DROP TABLE IF EXISTS Doctor;
DROP TABLE IF EXISTS Admin;
DROP TABLE IF EXISTS AppUser;

-- Drop lookup tables
DROP TABLE IF EXISTS SideEffectAction;
DROP TABLE IF EXISTS SeverityLevel;
DROP TABLE IF EXISTS UserRole;

SET FOREIGN_KEY_CHECKS = 1;

-- ==========================================
-- ESSENTIAL LOOKUP TABLES (Keep only these)
-- ==========================================

-- User roles lookup (frequently extended)
CREATE TABLE UserRole (
    RoleId INT PRIMARY KEY AUTO_INCREMENT,
    RoleCode VARCHAR(20) UNIQUE NOT NULL,
    RoleName VARCHAR(50) NOT NULL,
    Description TEXT
);

-- Severity levels lookup (medical context needs metadata)
CREATE TABLE SeverityLevel (
    SeverityId INT PRIMARY KEY AUTO_INCREMENT,
    SeverityCode VARCHAR(10) UNIQUE NOT NULL,
    SeverityName VARCHAR(20) NOT NULL,
    ClinicalDescription TEXT
);

-- Side effect actions lookup (medical decisions need tracking)
CREATE TABLE SideEffectAction (
    ActionId INT PRIMARY KEY AUTO_INCREMENT,
    ActionCode VARCHAR(20) UNIQUE NOT NULL,
    ActionName VARCHAR(50) NOT NULL,
    Description TEXT
);

-- ==========================================
-- CORE TABLES
-- ==========================================

-- 1) Centralized authentication table
CREATE TABLE AppUser (
    AppUserId INT PRIMARY KEY AUTO_INCREMENT,
    Username VARCHAR(100) UNIQUE NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    RoleId INT NOT NULL,
    IsLocked BOOLEAN DEFAULT FALSE,
    FailedAttempts INT DEFAULT 0,
    LockedUntil DATETIME NULL,
    LastLogin DATETIME NULL,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_appuser_role FOREIGN KEY (RoleId) REFERENCES UserRole(RoleId)
);

-- 2) Admin table
CREATE TABLE Admin (
    AdminId INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    AppUserId INT NOT NULL UNIQUE,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_admin_appuser FOREIGN KEY (AppUserId) REFERENCES AppUser(AppUserId) ON DELETE CASCADE,
    CONSTRAINT chk_admin_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

-- 3) Doctor table
CREATE TABLE Doctor (
    DoctorId INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Specialization VARCHAR(100),
    ContactInfoEncrypted VARBINARY(1024) NULL,
    AppUserId INT NOT NULL UNIQUE,
    IsActive BOOLEAN DEFAULT TRUE,
    AdminId INT NULL,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_doctor_admin FOREIGN KEY (AdminId) REFERENCES Admin(AdminId) ON DELETE SET NULL,
    CONSTRAINT fk_doctor_appuser FOREIGN KEY (AppUserId) REFERENCES AppUser(AppUserId) ON DELETE CASCADE,
    CONSTRAINT chk_doctor_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

-- 4) Patient table (simplified with ENUM for gender)
CREATE TABLE Patient (
    PatientId INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Gender ENUM('Male','Female','Other') NOT NULL,
    -- Encrypted sensitive data
    PhoneEncrypted VARBINARY(255),
    EmailEncrypted VARBINARY(255),
    AddressEncrypted VARBINARY(512),
    EmergencyContactEncrypted VARBINARY(255),
    -- Data integrity
    DataHash VARBINARY(64),
    DoctorId INT NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_patient_doctor FOREIGN KEY (DoctorId) REFERENCES Doctor(DoctorId) ON DELETE SET NULL,
    CONSTRAINT chk_patient_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0),
    CONSTRAINT chk_patient_dob_reasonable CHECK (DateOfBirth BETWEEN '1900-01-01' AND CURDATE())
);

-- 5) Medication tables
CREATE TABLE Medication (
    MedicationId INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    DosageForm VARCHAR(50),
    Strength VARCHAR(50),
    Instructions TEXT,
    IsActive BOOLEAN DEFAULT TRUE,
    CONSTRAINT chk_medication_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

CREATE TABLE MedicationTiming (
    TimingId INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(50) NOT NULL UNIQUE,
    Description VARCHAR(100)
);

-- 6) Prescription system (SIMPLIFIED - single table versioning)
CREATE TABLE Prescription (
    PrescriptionId INT PRIMARY KEY AUTO_INCREMENT,
    DoctorId INT NOT NULL,
    PatientId INT NOT NULL,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    Notes TEXT,
    Status ENUM('Active','Completed','Cancelled') DEFAULT 'Active',
    FOREIGN KEY (DoctorId) REFERENCES Doctor(DoctorId) ON DELETE CASCADE,
    FOREIGN KEY (PatientId) REFERENCES Patient(PatientId) ON DELETE CASCADE
);

-- SINGLE TABLE for prescription medications with versioning
CREATE TABLE PrescriptionMedication (
    PressMedId INT PRIMARY KEY AUTO_INCREMENT,
    PrescriptionId INT NOT NULL,
    MedicationId INT NOT NULL,
    DosageAmount INT NOT NULL,
    TimingId INT NULL,
    StartDate DATE NULL,
    EndDate DATE NULL,
    Status ENUM('Active','Completed','Discontinued') DEFAULT 'Active',
    Brand VARCHAR(100),
    -- Versioning fields (SIMPLIFIED APPROACH)
    Version INT DEFAULT 1,
    IsCurrent BOOLEAN DEFAULT TRUE,
    PreviousVersionId INT NULL,
    ChangedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    ChangeReason TEXT,
    FOREIGN KEY (PrescriptionId) REFERENCES Prescription(PrescriptionId) ON DELETE CASCADE,
    FOREIGN KEY (MedicationId) REFERENCES Medication(MedicationId) ON DELETE CASCADE,
    FOREIGN KEY (TimingId) REFERENCES MedicationTiming(TimingId),
    FOREIGN KEY (PreviousVersionId) REFERENCES PrescriptionMedication(PressMedId),
    CONSTRAINT chk_presmed_dosage_positive CHECK (DosageAmount > 0),
    CONSTRAINT chk_presmed_dates CHECK (StartDate IS NULL OR EndDate IS NULL OR StartDate <= EndDate)
);

-- 7) SIMPLIFIED medication schedule (replaces frequency tables)
CREATE TABLE PrescriptionSchedule (
    ScheduleId INT PRIMARY KEY AUTO_INCREMENT,
    PressMedId INT NOT NULL,
    DayOfWeek ENUM('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday') NOT NULL,
    TimeOfDay TIME NOT NULL,
    DosageAmount INT NOT NULL DEFAULT 1,
    IsActive BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (PressMedId) REFERENCES PrescriptionMedication(PressMedId) ON DELETE CASCADE,
    CONSTRAINT chk_schedule_dosage_positive CHECK (DosageAmount > 0)
);

-- 8) Patient health monitoring
CREATE TABLE PatientVital (
    VitalId INT PRIMARY KEY AUTO_INCREMENT,
    PatientId INT NOT NULL,
    RecordedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    Temperature DECIMAL(4,2),
    BloodPressureSystolic INT,
    BloodPressureDiastolic INT,
    HeartRate INT,
    RespiratoryRate INT,
    OxygenSaturation DECIMAL(4,2),
    AlertLevel ENUM('NORMAL','WARNING','CRITICAL') DEFAULT 'NORMAL',
    Notes TEXT,
    FOREIGN KEY (PatientId) REFERENCES Patient(PatientId) ON DELETE CASCADE,
    CONSTRAINT chk_temperature_range CHECK (Temperature BETWEEN 30 AND 45),
    CONSTRAINT chk_heart_rate_range CHECK (HeartRate BETWEEN 30 AND 250),
    CONSTRAINT chk_oxygen_saturation CHECK (OxygenSaturation BETWEEN 70 AND 100)
);

-- 9) Symptoms and side effects
CREATE TABLE Symptom (
    SymptomId INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Description TEXT,
    IsActive BOOLEAN DEFAULT TRUE,
    CONSTRAINT chk_symptom_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

CREATE TABLE PatientObservedSymptom (
    PatientObsSymptomId INT PRIMARY KEY AUTO_INCREMENT,
    PatientId INT NOT NULL,
    SymptomId INT NOT NULL,
    PressMedId INT NULL,
    RecordedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    SeverityId INT NOT NULL,
    IsSideEffect BOOLEAN DEFAULT FALSE,
    Notes TEXT,
    FOREIGN KEY (PatientId) REFERENCES Patient(PatientId) ON DELETE CASCADE,
    FOREIGN KEY (SymptomId) REFERENCES Symptom(SymptomId) ON DELETE CASCADE,
    FOREIGN KEY (PressMedId) REFERENCES PrescriptionMedication(PressMedId) ON DELETE SET NULL,
    FOREIGN KEY (SeverityId) REFERENCES SeverityLevel(SeverityId)
);

CREATE TABLE SideEffect (
    SideEffectId INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Description TEXT,
    IsActive BOOLEAN DEFAULT TRUE,
    CONSTRAINT chk_sideeffect_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

CREATE TABLE PatientSideEffect (
    PatientSideEffectId INT PRIMARY KEY AUTO_INCREMENT,
    PatientId INT NOT NULL,
    SideEffectId INT NOT NULL,
    PressMedId INT NOT NULL,
    RecordedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    SeverityId INT NOT NULL,
    OnsetDate DATE,
    ResolutionDate DATE NULL,
    ActionTakenId INT NULL,
    Notes TEXT,
    FOREIGN KEY (PatientId) REFERENCES Patient(PatientId) ON DELETE CASCADE,
    FOREIGN KEY (SideEffectId) REFERENCES SideEffect(SideEffectId) ON DELETE CASCADE,
    FOREIGN KEY (PressMedId) REFERENCES PrescriptionMedication(PressMedId) ON DELETE CASCADE,
    FOREIGN KEY (SeverityId) REFERENCES SeverityLevel(SeverityId),
    FOREIGN KEY (ActionTakenId) REFERENCES SideEffectAction(ActionId),
    CONSTRAINT chk_sideeffect_dates CHECK (OnsetDate IS NULL OR ResolutionDate IS NULL OR OnsetDate <= ResolutionDate)
);

-- 10) Reminder and compliance system
CREATE TABLE Reminder (
    ReminderId INT PRIMARY KEY AUTO_INCREMENT,
    PatientId INT NOT NULL,
    PressMedId INT NOT NULL,
    TimingId INT NOT NULL,
    Status ENUM('Active','Inactive','Completed') DEFAULT 'Active',
    ReminderTime TIME NOT NULL,
    FOREIGN KEY (PatientId) REFERENCES Patient(PatientId) ON DELETE CASCADE,
    FOREIGN KEY (PressMedId) REFERENCES PrescriptionMedication(PressMedId) ON DELETE CASCADE,
    FOREIGN KEY (TimingId) REFERENCES MedicationTiming(TimingId)
);

CREATE TABLE Compliance (
    ComplianceId INT PRIMARY KEY AUTO_INCREMENT,
    ReminderId INT NOT NULL,
    TakenAt DATETIME,
    DosageTaken INT DEFAULT 0,
    Status ENUM('Taken','Partial','Missed','Skipped') NOT NULL,
    Notes TEXT,
    FOREIGN KEY (ReminderId) REFERENCES Reminder(ReminderId) ON DELETE CASCADE,
    CONSTRAINT chk_dosage_taken_non_negative CHECK (DosageTaken >= 0)
);

-- 11) Audit system
CREATE TABLE AuditLog (
    AuditId BIGINT PRIMARY KEY AUTO_INCREMENT,
    ChangedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    AppUserId INT NULL,
    TableName VARCHAR(128) NOT NULL,
    Action ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    RowPrimaryKey VARCHAR(255) NOT NULL,
    OldData JSON NULL,
    NewData JSON NULL,
    Notes TEXT NULL,
    FOREIGN KEY (AppUserId) REFERENCES AppUser(AppUserId) ON DELETE SET NULL
);

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

-- Critical for patient health monitoring
CREATE INDEX idx_patient_vital_patient ON PatientVital(PatientId);
CREATE INDEX idx_patient_vital_alert ON PatientVital(AlertLevel);

-- ==========================================
-- POPULATE LOOKUP TABLES
-- ==========================================

INSERT INTO UserRole (RoleCode, RoleName, Description) VALUES
('admin', 'Administrator', 'System administrator with full access'),
('doctor', 'Doctor', 'Medical doctor who can manage patients and prescriptions'),
('patient', 'Patient', 'Patient who receives medical care'),
('system', 'System', 'System/internal user for automated processes');

INSERT INTO SeverityLevel (SeverityCode, SeverityName, ClinicalDescription) VALUES
('mild', 'Mild', 'Noticeable but does not affect daily activities'),
('moderate', 'Moderate', 'Affects some daily activities, may require intervention'),
('severe', 'Severe', 'Significantly affects daily activities, requires immediate attention');

INSERT INTO SideEffectAction (ActionCode, ActionName, Description) VALUES
('none', 'None', 'No action taken, monitoring continued'),
('dosage_reduced', 'Dosage Reduced', 'Medication dosage was reduced'),
('medication_changed', 'Medication Changed', 'Switched to different medication'),
('treatment_stopped', 'Treatment Stopped', 'Medication was discontinued'),
('other_treatment', 'Other Treatment', 'Additional treatment given for side effect'),
('other', 'Other', 'Other action taken');

INSERT INTO MedicationTiming (Name, Description) VALUES
('Morning', 'Take in the morning, usually with breakfast'),
('Noon', 'Take around midday, with lunch'),
('Evening', 'Take in the evening, with dinner'),
('Bedtime', 'Take before going to sleep'),
('As Needed', 'Take only when symptoms occur');

-- ==========================================
-- SECURITY VIEWS (For data masking)
-- ==========================================

CREATE VIEW PatientPublic AS
SELECT
    PatientId,
    Name,
    DateOfBirth,
    Gender,
    'ENCRYPTED' AS ContactInfoMask,
    DoctorId
FROM Patient
WITH CASCADED CHECK OPTION;

CREATE VIEW DoctorPublic AS
SELECT
    DoctorId,
    Name,
    Specialization,
    'ENCRYPTED' AS ContactInfoMask
FROM Doctor
WITH CASCADED CHECK OPTION;

CREATE VIEW SystemOverview AS
SELECT 
    a.Name AS AdminName,
    d.Name AS DoctorName,
    d.Specialization AS DoctorSpecialty,
    p.Name AS PatientName,
    'ENCRYPTED' AS PatientContact
FROM Admin a
JOIN Doctor d ON a.AdminId = d.AdminId
LEFT JOIN Patient p ON d.DoctorId = p.DoctorId;

-- ==========================================
-- AUTOMATIC ALERT TRIGGERS
-- ==========================================

DELIMITER $$

CREATE TRIGGER trg_vital_alert_before_insert
BEFORE INSERT ON PatientVital
FOR EACH ROW
BEGIN
    -- Temperature alerts
    IF NEW.Temperature >= 39.5 THEN
        SET NEW.AlertLevel = 'CRITICAL';
    ELSEIF NEW.Temperature >= 38.0 THEN
        SET NEW.AlertLevel = 'WARNING';
    ELSEIF NEW.Temperature BETWEEN 36.1 AND 37.9 THEN
        SET NEW.AlertLevel = 'NORMAL';
    ELSE
        SET NEW.AlertLevel = 'WARNING'; -- Low temperature
    END IF;
    
    -- Blood pressure alerts
    IF NEW.BloodPressureSystolic > 180 OR NEW.BloodPressureDiastolic > 120 THEN
        SET NEW.AlertLevel = 'CRITICAL';
    ELSEIF NEW.BloodPressureSystolic > 140 OR NEW.BloodPressureDiastolic > 90 THEN
        IF NEW.AlertLevel = 'NORMAL' THEN
            SET NEW.AlertLevel = 'WARNING';
        END IF;
    END IF;
    
    -- Heart rate alerts
    IF NEW.HeartRate > 150 OR NEW.HeartRate < 40 THEN
        SET NEW.AlertLevel = 'CRITICAL';
    ELSEIF NEW.HeartRate > 120 OR NEW.HeartRate < 50 THEN
        IF NEW.AlertLevel = 'NORMAL' THEN
            SET NEW.AlertLevel = 'WARNING';
        END IF;
    END IF;
    
    -- Oxygen saturation alerts
    IF NEW.OxygenSaturation < 90 THEN
        SET NEW.AlertLevel = 'CRITICAL';
    ELSEIF NEW.OxygenSaturation < 95 THEN
        IF NEW.AlertLevel = 'NORMAL' THEN
            SET NEW.AlertLevel = 'WARNING';
        END IF;
    END IF;
END$$

-- ==========================================
-- PRESCRIPTION VERSIONING TRIGGER
-- ==========================================

CREATE TRIGGER trg_prescription_versioning
BEFORE UPDATE ON PrescriptionMedication
FOR EACH ROW
BEGIN
    -- If this is a significant change (not just status update), create new version
    IF OLD.DosageAmount != NEW.DosageAmount OR OLD.TimingId != NEW.TimingId 
       OR OLD.StartDate != NEW.StartDate OR OLD.EndDate != NEW.EndDate THEN
        
        -- Mark old version as not current
        SET NEW.IsCurrent = FALSE;
        
        -- Insert new version (this happens in application logic)
        -- Application will handle the actual version creation
        SET NEW.ChangeReason = IFNULL(NEW.ChangeReason, 'Medication adjustment');
    END IF;
END$$

-- ==========================================
-- AUDIT TRIGGERS (Simplified)
-- ==========================================

CREATE TRIGGER trg_audit_patient_changes
AFTER UPDATE ON Patient
FOR EACH ROW
BEGIN
    IF OLD.Name != NEW.Name OR OLD.DateOfBirth != NEW.DateOfBirth OR OLD.Gender != NEW.Gender THEN
        INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, OldData, NewData)
        VALUES('Patient', 'UPDATE', CONCAT('PatientId=', NEW.PatientId),
            JSON_OBJECT('Name', OLD.Name, 'DateOfBirth', CAST(OLD.DateOfBirth AS CHAR), 'Gender', OLD.Gender),
            JSON_OBJECT('Name', NEW.Name, 'DateOfBirth', CAST(NEW.DateOfBirth AS CHAR), 'Gender', NEW.Gender)
        );
    END IF;
END$$

CREATE TRIGGER trg_audit_prescription_changes
AFTER UPDATE ON PrescriptionMedication
FOR EACH ROW
BEGIN
    IF OLD.DosageAmount != NEW.DosageAmount OR OLD.Status != NEW.Status THEN
        INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, OldData, NewData)
        VALUES('PrescriptionMedication', 'UPDATE', CONCAT('PressMedId=', NEW.PressMedId),
            JSON_OBJECT('DosageAmount', OLD.DosageAmount, 'Status', OLD.Status),
            JSON_OBJECT('DosageAmount', NEW.DosageAmount, 'Status', NEW.Status)
        );
    END IF;
END$$

DELIMITER ;

-- ==========================================
-- SECURE STORED PROCEDURES (Input sanitization)
-- ==========================================

DELIMITER $$

CREATE PROCEDURE sp_create_secure_patient(
    IN p_name VARCHAR(100),
    IN p_dob DATE,
    IN p_gender ENUM('Male','Female','Other'),
    IN p_phone VARCHAR(20),
    IN p_email VARCHAR(100),
    IN p_doctor_id INT
)
BEGIN
    DECLARE v_doctor_exists INT;
    
    -- Input validation
    IF LENGTH(TRIM(p_name)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient name cannot be empty';
    END IF;
    
    IF p_dob > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Date of birth cannot be in future';
    END IF;
    
    IF p_doctor_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_doctor_exists FROM Doctor WHERE DoctorId = p_doctor_id AND IsActive = TRUE;
        IF v_doctor_exists = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid doctor ID';
        END IF;
    END IF;
    
    -- Sanitize and insert with encryption
    INSERT INTO Patient (
        Name, DateOfBirth, Gender, 
        PhoneEncrypted, EmailEncrypted, DoctorId
    ) VALUES (
        TRIM(p_name), p_dob, p_gender,
        AES_ENCRYPT(TRIM(p_phone), @enc_key),
        AES_ENCRYPT(TRIM(p_email), @enc_key),
        p_doctor_id
    );
END$$

CREATE PROCEDURE sp_update_prescription_dosage(
    IN p_press_med_id INT,
    IN p_new_dosage INT,
    IN p_reason TEXT,
    IN p_user_id INT
)
BEGIN
    DECLARE v_current_version INT;
    DECLARE v_prescription_id INT;
    
    -- Get current version and prescription info
    SELECT Version, PrescriptionId INTO v_current_version, v_prescription_id 
    FROM PrescriptionMedication 
    WHERE PressMedId = p_press_med_id AND IsCurrent = TRUE;
    
    IF v_current_version IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prescription medication not found or not current';
    END IF;
    
    IF p_new_dosage <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dosage must be positive';
    END IF;
    
    -- Mark old version as not current
    UPDATE PrescriptionMedication 
    SET IsCurrent = FALSE, ChangedAt = NOW()
    WHERE PressMedId = p_press_med_id;
    
    -- Insert new version
    INSERT INTO PrescriptionMedication (
        PrescriptionId, MedicationId, DosageAmount, TimingId, 
        StartDate, EndDate, Status, Brand,
        Version, IsCurrent, PreviousVersionId, ChangeReason
    )
    SELECT 
        PrescriptionId, MedicationId, p_new_dosage, TimingId,
        StartDate, EndDate, Status, Brand,
        Version + 1, TRUE, PressMedId, p_reason
    FROM PrescriptionMedication 
    WHERE PressMedId = p_press_med_id;
    
    -- Log the change
    INSERT INTO AuditLog (AppUserId, TableName, Action, RowPrimaryKey, NewData, Notes)
    VALUES (p_user_id, 'PrescriptionMedication', 'UPDATE', 
            CONCAT('PressMedId=', p_press_med_id, '->', LAST_INSERT_ID()),
            JSON_OBJECT('NewDosage', p_new_dosage, 'Reason', p_reason),
            'Dosage adjustment with versioning');
END$$

CREATE PROCEDURE sp_record_medication_schedule(
    IN p_press_med_id INT,
    IN p_day_of_week ENUM('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'),
    IN p_times JSON -- Array of times: ['09:00', '14:00', '18:00']
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_time_count INT;
    DECLARE v_current_time TIME;
    
    -- Validate prescription exists and is active
    IF NOT EXISTS (SELECT 1 FROM PrescriptionMedication WHERE PressMedId = p_press_med_id AND IsCurrent = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or inactive prescription medication';
    END IF;
    
    -- Get number of times
    SET v_time_count = JSON_LENGTH(p_times);
    
    -- Insert each time
    WHILE i < v_time_count DO
        SET v_current_time = TIME(JSON_UNQUOTE(JSON_EXTRACT(p_times, CONCAT('$[', i, ']'))));
        
        INSERT INTO PrescriptionSchedule (PressMedId, DayOfWeek, TimeOfDay, DosageAmount)
        VALUES (p_press_med_id, p_day_of_week, v_current_time, 1);
        
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

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
CALL sp_create_secure_patient('John Doe', '1985-06-15', 'Male', '123-456-7890', 'john@email.com', 1);
CALL sp_create_secure_patient('Jane Smith', '1990-08-22', 'Female', '123-456-7891', 'jane@email.com', 2);

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

-- Test vital recording with automatic alerts
INSERT INTO PatientVital (PatientId, Temperature, BloodPressureSystolic, BloodPressureDiastolic, HeartRate, OxygenSaturation) VALUES
(1, 38.5, 140, 90, 85, 98.0),  -- Should trigger WARNING (fever)
(2, 37.2, 110, 70, 72, 99.0);  -- Should be NORMAL

-- Test prescription versioning
CALL sp_update_prescription_dosage(1, 2, 'Increased dosage due to blood pressure readings', 1);

SELECT 'Database schema created successfully with simplified structure, automatic alerts, and optimized indexes!' AS Status;