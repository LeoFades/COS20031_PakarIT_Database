SET @enc_key = 'a4335fc26a205a398bd3e185a88f3987ab2688ee2279f825ca7054c042c231e0';

-- ==========================================
-- DATABASE SETUP & CLEANUP
-- ==========================================
CREATE DATABASE IF NOT EXISTS PakarIT;
USE PakarIT;

SET FOREIGN_KEY_CHECKS = 0;

-- Drop views
DROP VIEW IF EXISTS AlertDashboard;
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

-- 4) Patient table (simplified with ENUM for gender + automatic monitoring)
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
    -- Automatic compliance monitoring
    ComplianceStatus ENUM('Good','Warning','Critical') DEFAULT 'Good',
    LastComplianceCheck DATETIME NULL,
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
    -- Automatic alert fields
    RequiresDoctorReview BOOLEAN DEFAULT FALSE,
    ReviewedAt DATETIME NULL,
    ReviewedBy INT NULL,
    Notes TEXT,
    FOREIGN KEY (PatientId) REFERENCES Patient(PatientId) ON DELETE CASCADE,
    FOREIGN KEY (SideEffectId) REFERENCES SideEffect(SideEffectId) ON DELETE CASCADE,
    FOREIGN KEY (PressMedId) REFERENCES PrescriptionMedication(PressMedId) ON DELETE CASCADE,
    FOREIGN KEY (SeverityId) REFERENCES SeverityLevel(SeverityId),
    FOREIGN KEY (ActionTakenId) REFERENCES SideEffectAction(ActionId),
    FOREIGN KEY (ReviewedBy) REFERENCES Doctor(DoctorId) ON DELETE SET NULL,
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