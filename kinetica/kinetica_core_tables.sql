-- ==========================================
-- KINETICA DATABASE SETUP
-- ==========================================
-- Note: Kinetica uses schemas instead of databases
-- CREATE SCHEMA IF NOT EXISTS PakarIT;
-- USE SCHEMA PakarIT;

-- For Kinetica, you would typically connect to a specific schema
-- Connection would be handled at the application/connection level

-- ==========================================
-- ESSENTIAL LOOKUP TABLES
-- ==========================================

-- User roles lookup (frequently extended)
-- Note: ENUM replaced with VARCHAR + CHECK constraint
CREATE TABLE UserRole (
    RoleId INT NOT NULL,  -- No AUTO_INCREMENT in Kinetica
    RoleCode VARCHAR(20) NOT NULL,
    RoleName VARCHAR(50) NOT NULL,
    Description VARCHAR(2000),  -- TEXT replaced with VARCHAR
    PRIMARY KEY (RoleId),
    CONSTRAINT uc_userrole_code UNIQUE (RoleCode)
);

-- Severity levels lookup (medical context needs metadata)
CREATE TABLE SeverityLevel (
    SeverityId INT NOT NULL,
    SeverityCode VARCHAR(10) NOT NULL,
    SeverityName VARCHAR(20) NOT NULL,
    ClinicalDescription VARCHAR(2000),
    PRIMARY KEY (SeverityId),
    CONSTRAINT uc_severity_code UNIQUE (SeverityCode)
);

-- Side effect actions lookup (medical decisions need tracking)
CREATE TABLE SideEffectAction (
    ActionId INT NOT NULL,
    ActionCode VARCHAR(20) NOT NULL,
    ActionName VARCHAR(50) NOT NULL,
    Description VARCHAR(2000),
    PRIMARY KEY (ActionId),
    CONSTRAINT uc_action_code UNIQUE (ActionCode)
);

-- ==========================================
-- CORE TABLES
-- ==========================================

-- 1) Centralized authentication table
-- Note: DATETIME replaced with TIMESTAMP
CREATE TABLE AppUser (
    AppUserId INT NOT NULL,
    Username VARCHAR(100) NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    RoleId INT NOT NULL,
    IsLocked BOOLEAN DEFAULT FALSE,
    FailedAttempts INT DEFAULT 0,
    LockedUntil TIMESTAMP NULL,
    LastLogin TIMESTAMP NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Note: ON UPDATE not supported in Kinetica
    PRIMARY KEY (AppUserId),
    CONSTRAINT uc_appuser_username UNIQUE (Username),
    FOREIGN KEY (RoleId) REFERENCES UserRole(RoleId)
);

-- 2) Admin table
CREATE TABLE Admin (
    AdminId INT NOT NULL,
    Name VARCHAR(100) NOT NULL,
    AppUserId INT NOT NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (AdminId),
    CONSTRAINT uc_admin_appuser UNIQUE (AppUserId),
    CONSTRAINT fk_admin_appuser FOREIGN KEY (AppUserId) REFERENCES AppUser(AppUserId),
    CONSTRAINT chk_admin_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

-- 3) Doctor table
-- Note: VARBINARY replaced with BYTES
CREATE TABLE Doctor (
    DoctorId INT NOT NULL,
    Name VARCHAR(100) NOT NULL,
    Specialization VARCHAR(100),
    ContactInfoEncrypted BYTES,  -- VARBINARY(1024) replaced with BYTES
    AppUserId INT NOT NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    AdminId INT NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (DoctorId),
    CONSTRAINT uc_doctor_appuser UNIQUE (AppUserId),
    CONSTRAINT fk_doctor_admin FOREIGN KEY (AdminId) REFERENCES Admin(AdminId),
    CONSTRAINT fk_doctor_appuser FOREIGN KEY (AppUserId) REFERENCES AppUser(AppUserId),
    CONSTRAINT chk_doctor_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

-- 4) Patient table
-- Gender as VARCHAR with CHECK constraint instead of ENUM
CREATE TABLE Patient (
    PatientId INT NOT NULL,
    Name VARCHAR(100) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Gender VARCHAR(10) NOT NULL,  -- ENUM replaced with VARCHAR
    -- Encrypted sensitive data - VARBINARY replaced with BYTES
    PhoneEncrypted BYTES,
    EmailEncrypted BYTES,
    AddressEncrypted BYTES,
    EmergencyContactEncrypted BYTES,
    -- Data integrity
    DataHash BYTES,
    -- Automatic compliance monitoring
    ComplianceStatus VARCHAR(10) DEFAULT 'Good',  -- ENUM replaced with VARCHAR
    LastComplianceCheck TIMESTAMP NULL,
    DoctorId INT NULL,
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (PatientId),
    CONSTRAINT fk_patient_doctor FOREIGN KEY (DoctorId) REFERENCES Doctor(DoctorId),
    CONSTRAINT chk_patient_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0),
    CONSTRAINT chk_patient_gender CHECK (Gender IN ('Male', 'Female', 'Other')),
    CONSTRAINT chk_patient_compliance CHECK (ComplianceStatus IN ('Good', 'Warning', 'Critical')),
    CONSTRAINT chk_patient_dob_reasonable CHECK (DateOfBirth BETWEEN DATE '1900-01-01' AND DATE '2100-12-31')
);

-- 5) Medication tables
CREATE TABLE Medication (
    MedicationId INT NOT NULL,
    Name VARCHAR(100) NOT NULL,
    DosageForm VARCHAR(50),
    Strength VARCHAR(50),
    Instructions VARCHAR(5000),  -- TEXT replaced with VARCHAR
    IsActive BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (MedicationId),
    CONSTRAINT chk_medication_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

CREATE TABLE MedicationTiming (
    TimingId INT NOT NULL,
    Name VARCHAR(50) NOT NULL,
    Description VARCHAR(100),
    PRIMARY KEY (TimingId),
    CONSTRAINT uc_timing_name UNIQUE (Name)
);

-- 6) Prescription system
CREATE TABLE Prescription (
    PrescriptionId INT NOT NULL,
    DoctorId INT NOT NULL,
    PatientId INT NOT NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Notes VARCHAR(10000),  -- TEXT replaced with VARCHAR
    Status VARCHAR(20) DEFAULT 'Active',  -- ENUM replaced with VARCHAR
    PRIMARY KEY (PrescriptionId),
    CONSTRAINT fk_prescription_doctor FOREIGN KEY (DoctorId) REFERENCES Doctor(DoctorId),
    CONSTRAINT fk_prescription_patient FOREIGN KEY (PatientId) REFERENCES Patient(PatientId),
    CONSTRAINT chk_prescription_status CHECK (Status IN ('Active', 'Completed', 'Cancelled'))
);

-- Prescription medications with versioning
CREATE TABLE PrescriptionMedication (
    PressMedId INT NOT NULL,
    PrescriptionId INT NOT NULL,
    MedicationId INT NOT NULL,
    DosageAmount INT NOT NULL,
    TimingId INT NULL,
    StartDate DATE NULL,
    EndDate DATE NULL,
    Status VARCHAR(20) DEFAULT 'Active',  -- ENUM replaced with VARCHAR
    Brand VARCHAR(100),
    -- Versioning fields
    Version INT DEFAULT 1,
    IsCurrent BOOLEAN DEFAULT TRUE,
    PreviousVersionId INT NULL,
    ChangedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ChangeReason VARCHAR(5000),  -- TEXT replaced with VARCHAR
    PRIMARY KEY (PressMedId),
    CONSTRAINT fk_presmed_prescription FOREIGN KEY (PrescriptionId) REFERENCES Prescription(PrescriptionId),
    CONSTRAINT fk_presmed_medication FOREIGN KEY (MedicationId) REFERENCES Medication(MedicationId),
    CONSTRAINT fk_presmed_timing FOREIGN KEY (TimingId) REFERENCES MedicationTiming(TimingId),
    CONSTRAINT fk_presmed_previous FOREIGN KEY (PreviousVersionId) REFERENCES PrescriptionMedication(PressMedId),
    CONSTRAINT chk_presmed_status CHECK (Status IN ('Active', 'Completed', 'Discontinued')),
    CONSTRAINT chk_presmed_dosage_positive CHECK (DosageAmount > 0),
    CONSTRAINT chk_presmed_dates CHECK (StartDate IS NULL OR EndDate IS NULL OR StartDate <= EndDate)
);

-- 7) Medication schedule
CREATE TABLE PrescriptionSchedule (
    ScheduleId INT NOT NULL,
    PressMedId INT NOT NULL,
    DayOfWeek VARCHAR(10) NOT NULL,  -- ENUM replaced with VARCHAR
    TimeOfDay TIME NOT NULL,
    DosageAmount INT NOT NULL DEFAULT 1,
    IsActive BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (ScheduleId),
    CONSTRAINT fk_schedule_presmed FOREIGN KEY (PressMedId) REFERENCES PrescriptionMedication(PressMedId),
    CONSTRAINT chk_schedule_day CHECK (DayOfWeek IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')),
    CONSTRAINT chk_schedule_dosage_positive CHECK (DosageAmount > 0)
);

-- 8) Symptoms and side effects
CREATE TABLE Symptom (
    SymptomId INT NOT NULL,
    Name VARCHAR(100) NOT NULL,
    Description VARCHAR(2000),  -- TEXT replaced with VARCHAR
    IsActive BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (SymptomId),
    CONSTRAINT chk_symptom_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

CREATE TABLE PatientObservedSymptom (
    PatientObsSymptomId INT NOT NULL,
    PatientId INT NOT NULL,
    SymptomId INT NOT NULL,
    PressMedId INT NULL,
    RecordedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    SeverityId INT NOT NULL,
    IsSideEffect BOOLEAN DEFAULT FALSE,
    Notes VARCHAR(5000),  -- TEXT replaced with VARCHAR
    PRIMARY KEY (PatientObsSymptomId),
    CONSTRAINT fk_patobssym_patient FOREIGN KEY (PatientId) REFERENCES Patient(PatientId),
    CONSTRAINT fk_patobssym_symptom FOREIGN KEY (SymptomId) REFERENCES Symptom(SymptomId),
    CONSTRAINT fk_patobssym_presmed FOREIGN KEY (PressMedId) REFERENCES PrescriptionMedication(PressMedId),
    CONSTRAINT fk_patobssym_severity FOREIGN KEY (SeverityId) REFERENCES SeverityLevel(SeverityId)
);

CREATE TABLE SideEffect (
    SideEffectId INT NOT NULL,
    Name VARCHAR(100) NOT NULL,
    Description VARCHAR(2000),  -- TEXT replaced with VARCHAR
    IsActive BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (SideEffectId),
    CONSTRAINT chk_sideeffect_name_not_empty CHECK (LENGTH(TRIM(Name)) > 0)
);

CREATE TABLE PatientSideEffect (
    PatientSideEffectId INT NOT NULL,
    PatientId INT NOT NULL,
    SideEffectId INT NOT NULL,
    PressMedId INT NOT NULL,
    RecordedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    SeverityId INT NOT NULL,
    OnsetDate DATE,
    ResolutionDate DATE NULL,
    ActionTakenId INT NULL,
    -- Automatic alert fields
    RequiresDoctorReview BOOLEAN DEFAULT FALSE,
    ReviewedAt TIMESTAMP NULL,
    ReviewedBy INT NULL,
    Notes VARCHAR(5000),  -- TEXT replaced with VARCHAR
    PRIMARY KEY (PatientSideEffectId),
    CONSTRAINT fk_patsideeff_patient FOREIGN KEY (PatientId) REFERENCES Patient(PatientId),
    CONSTRAINT fk_patsideeff_sideeffect FOREIGN KEY (SideEffectId) REFERENCES SideEffect(SideEffectId),
    CONSTRAINT fk_patsideeff_presmed FOREIGN KEY (PressMedId) REFERENCES PrescriptionMedication(PressMedId),
    CONSTRAINT fk_patsideeff_severity FOREIGN KEY (SeverityId) REFERENCES SeverityLevel(SeverityId),
    CONSTRAINT fk_patsideeff_action FOREIGN KEY (ActionTakenId) REFERENCES SideEffectAction(ActionId),
    CONSTRAINT fk_patsideeff_reviewer FOREIGN KEY (ReviewedBy) REFERENCES Doctor(DoctorId),
    CONSTRAINT chk_sideeffect_dates CHECK (OnsetDate IS NULL OR ResolutionDate IS NULL OR OnsetDate <= ResolutionDate)
);

-- 9) Reminder and compliance system
CREATE TABLE Reminder (
    ReminderId INT NOT NULL,
    PatientId INT NOT NULL,
    PressMedId INT NOT NULL,
    TimingId INT NOT NULL,
    Status VARCHAR(20) DEFAULT 'Active',  -- ENUM replaced with VARCHAR
    ReminderTime TIME NOT NULL,
    PRIMARY KEY (ReminderId),
    CONSTRAINT fk_reminder_patient FOREIGN KEY (PatientId) REFERENCES Patient(PatientId),
    CONSTRAINT fk_reminder_presmed FOREIGN KEY (PressMedId) REFERENCES PrescriptionMedication(PressMedId),
    CONSTRAINT fk_reminder_timing FOREIGN KEY (TimingId) REFERENCES MedicationTiming(TimingId),
    CONSTRAINT chk_reminder_status CHECK (Status IN ('Active', 'Inactive', 'Completed'))
);

CREATE TABLE Compliance (
    ComplianceId INT NOT NULL,
    ReminderId INT NOT NULL,
    TakenAt TIMESTAMP,
    DosageTaken INT DEFAULT 0,
    Status VARCHAR(20) NOT NULL,  -- ENUM replaced with VARCHAR
    Notes VARCHAR(5000),  -- TEXT replaced with VARCHAR
    PRIMARY KEY (ComplianceId),
    CONSTRAINT fk_compliance_reminder FOREIGN KEY (ReminderId) REFERENCES Reminder(ReminderId),
    CONSTRAINT chk_compliance_status CHECK (Status IN ('Taken', 'Partial', 'Missed', 'Skipped')),
    CONSTRAINT chk_dosage_taken_non_negative CHECK (DosageTaken >= 0)
);

-- 10) Audit system
-- Note: JSON type supported in Kinetica but may have different syntax
CREATE TABLE AuditLog (
    AuditId BIGINT NOT NULL,
    ChangedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    AppUserId INT NULL,
    TableName VARCHAR(128) NOT NULL,
    Action VARCHAR(20) NOT NULL,  -- ENUM replaced with VARCHAR
    RowPrimaryKey VARCHAR(255) NOT NULL,
    OldData VARCHAR(10000) NULL,  -- JSON stored as VARCHAR - Kinetica has JSON support but this is simpler
    NewData VARCHAR(10000) NULL,  -- JSON stored as VARCHAR
    Notes VARCHAR(5000) NULL,  -- TEXT replaced with VARCHAR
    PRIMARY KEY (AuditId),
    CONSTRAINT fk_auditlog_appuser FOREIGN KEY (AppUserId) REFERENCES AppUser(AppUserId),
    CONSTRAINT chk_auditlog_action CHECK (Action IN ('INSERT', 'UPDATE', 'DELETE'))
);
