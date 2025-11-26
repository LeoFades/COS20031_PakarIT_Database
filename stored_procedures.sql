USE PakarIT;

-- ==========================================
-- COMPREHENSIVE INPUT SANITIZATION PROCEDURES
-- ==========================================

DELIMITER $$

-- ==========================================
-- USER MANAGEMENT PROCEDURES
-- ==========================================

DROP PROCEDURE IF EXISTS sp_create_app_user$$
CREATE PROCEDURE sp_create_app_user(
    IN p_username VARCHAR(100),
    IN p_password_hash VARCHAR(255),
    IN p_role_code VARCHAR(20)
)
BEGIN
    DECLARE v_role_id INT;
    
    -- Sanitize username: trim, check length, no special chars except underscore
    SET p_username = TRIM(p_username);
    
    IF LENGTH(p_username) < 3 OR LENGTH(p_username) > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username must be between 3 and 100 characters';
    END IF;
    
    IF p_username REGEXP '[^a-zA-Z0-9_]' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username can only contain letters, numbers, and underscores';
    END IF;
    
    -- Validate role exists
    SELECT RoleId INTO v_role_id FROM UserRole WHERE RoleCode = p_role_code;
    IF v_role_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid role code';
    END IF;
    
    -- Check username doesn't already exist
    IF EXISTS (SELECT 1 FROM AppUser WHERE Username = p_username) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username already exists';
    END IF;
    
    -- Insert sanitized user
    INSERT INTO AppUser(Username, PasswordHash, RoleId)
    VALUES(p_username, p_password_hash, v_role_id);
END$$

-- ==========================================
-- PATIENT MANAGEMENT PROCEDURES
-- ==========================================

DROP PROCEDURE IF EXISTS sp_create_secure_patient$$
CREATE PROCEDURE sp_create_secure_patient(
    IN p_name VARCHAR(100),
    IN p_dob DATE,
    IN p_gender ENUM('Male','Female','Other'),
    IN p_phone VARCHAR(20),
    IN p_email VARCHAR(100),
    IN p_address VARCHAR(500),
    IN p_emergency_contact VARCHAR(20),
    IN p_doctor_id INT
)
BEGIN
    DECLARE v_doctor_exists INT;
    
    -- Sanitize name: trim, check length, no special chars except spaces/hyphens/apostrophes
    SET p_name = TRIM(p_name);
    
    IF LENGTH(p_name) < 2 OR LENGTH(p_name) > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient name must be between 2 and 100 characters';
    END IF;
    
    IF p_name REGEXP '[^a-zA-Z -'']' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient name contains invalid characters';
    END IF;
    
    -- Validate date of birth
    IF p_dob > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Date of birth cannot be in future';
    END IF;
    
    IF p_dob < DATE_SUB(CURDATE(), INTERVAL 150 YEAR) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Date of birth is not reasonable';
    END IF;
    
    -- Validate phone format (if provided)
    IF p_phone IS NOT NULL AND p_phone != '' THEN
        SET p_phone = TRIM(p_phone);
        IF LENGTH(p_phone) < 10 OR LENGTH(p_phone) > 20 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Phone number must be between 10 and 20 characters';
        END IF;
        IF p_phone REGEXP '[^0-9+() -]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Phone number contains invalid characters';
        END IF;
    END IF;
    
    -- Validate email format (if provided)
    IF p_email IS NOT NULL AND p_email != '' THEN
        SET p_email = TRIM(LOWER(p_email));
        IF LENGTH(p_email) > 100 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email address is too long';
        END IF;
        IF p_email NOT REGEXP '^[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid email format';
        END IF;
    END IF;
    
    -- Validate address (if provided)
    IF p_address IS NOT NULL AND p_address != '' THEN
        SET p_address = TRIM(p_address);
        IF LENGTH(p_address) > 500 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Address is too long (max 500 characters)';
        END IF;
        -- Remove potentially dangerous characters
        IF p_address REGEXP '[<>]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Address contains invalid characters';
        END IF;
    END IF;
    
    -- Validate emergency contact (if provided)
    IF p_emergency_contact IS NOT NULL AND p_emergency_contact != '' THEN
        SET p_emergency_contact = TRIM(p_emergency_contact);
        IF LENGTH(p_emergency_contact) < 10 OR LENGTH(p_emergency_contact) > 20 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Emergency contact must be between 10 and 20 characters';
        END IF;
        IF p_emergency_contact REGEXP '[^0-9+() -]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Emergency contact contains invalid characters';
        END IF;
    END IF;
    
    -- Validate doctor exists (if provided)
    IF p_doctor_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_doctor_exists FROM Doctor WHERE DoctorId = p_doctor_id AND IsActive = TRUE;
        IF v_doctor_exists = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or inactive doctor ID';
        END IF;
    END IF;
    
    -- Insert with encryption
    INSERT INTO Patient (
        Name, DateOfBirth, Gender, 
        PhoneEncrypted, EmailEncrypted, AddressEncrypted, EmergencyContactEncrypted,
        DoctorId
    ) VALUES (
        p_name, p_dob, p_gender,
        IF(p_phone IS NOT NULL AND p_phone != '', AES_ENCRYPT(p_phone, @enc_key), NULL),
        IF(p_email IS NOT NULL AND p_email != '', AES_ENCRYPT(p_email, @enc_key), NULL),
        IF(p_address IS NOT NULL AND p_address != '', AES_ENCRYPT(p_address, @enc_key), NULL),
        IF(p_emergency_contact IS NOT NULL AND p_emergency_contact != '', AES_ENCRYPT(p_emergency_contact, @enc_key), NULL),
        p_doctor_id
    );
END$$

DROP PROCEDURE IF EXISTS sp_update_patient$$
CREATE PROCEDURE sp_update_patient(
    IN p_patient_id INT,
    IN p_name VARCHAR(100),
    IN p_phone VARCHAR(20),
    IN p_email VARCHAR(100),
    IN p_address VARCHAR(500),
    IN p_emergency_contact VARCHAR(20)
)
BEGIN
    -- Check patient exists
    IF NOT EXISTS (SELECT 1 FROM Patient WHERE PatientId = p_patient_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient not found';
    END IF;
    
    -- Sanitize name
    SET p_name = TRIM(p_name);
    IF LENGTH(p_name) < 2 OR LENGTH(p_name) > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient name must be between 2 and 100 characters';
    END IF;
    IF p_name REGEXP '[^a-zA-Z ''-]' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient name contains invalid characters';
    END IF;
    
    -- Validate phone (if provided)
    IF p_phone IS NOT NULL AND p_phone != '' THEN
        SET p_phone = TRIM(p_phone);
        IF LENGTH(p_phone) < 10 OR LENGTH(p_phone) > 20 OR p_phone REGEXP '[^0-9+() -]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid phone number';
        END IF;
    END IF;
    
    -- Validate email (if provided)
    IF p_email IS NOT NULL AND p_email != '' THEN
        SET p_email = TRIM(LOWER(p_email));
        IF LENGTH(p_email) > 100 OR p_email NOT REGEXP '^[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid email format';
        END IF;
    END IF;
    
    -- Validate address (if provided)
    IF p_address IS NOT NULL AND p_address != '' THEN
        SET p_address = TRIM(p_address);
        IF LENGTH(p_address) > 500 OR p_address REGEXP '[<>]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid address';
        END IF;
    END IF;
    
    -- Validate emergency contact (if provided)
    IF p_emergency_contact IS NOT NULL AND p_emergency_contact != '' THEN
        SET p_emergency_contact = TRIM(p_emergency_contact);
        IF LENGTH(p_emergency_contact) < 10 OR LENGTH(p_emergency_contact) > 20 OR p_emergency_contact REGEXP '[^0-9+() -]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid emergency contact';
        END IF;
    END IF;
    
    -- Update with encryption
    UPDATE Patient SET
        Name = p_name,
        PhoneEncrypted = IF(p_phone IS NOT NULL AND p_phone != '', AES_ENCRYPT(p_phone, @enc_key), PhoneEncrypted),
        EmailEncrypted = IF(p_email IS NOT NULL AND p_email != '', AES_ENCRYPT(p_email, @enc_key), EmailEncrypted),
        AddressEncrypted = IF(p_address IS NOT NULL AND p_address != '', AES_ENCRYPT(p_address, @enc_key), AddressEncrypted),
        EmergencyContactEncrypted = IF(p_emergency_contact IS NOT NULL AND p_emergency_contact != '', AES_ENCRYPT(p_emergency_contact, @enc_key), EmergencyContactEncrypted)
    WHERE PatientId = p_patient_id;
END$$

-- ==========================================
-- DOCTOR MANAGEMENT PROCEDURES
-- ==========================================

DROP PROCEDURE IF EXISTS sp_create_doctor$$
CREATE PROCEDURE sp_create_doctor(
    IN p_name VARCHAR(100),
    IN p_specialization VARCHAR(100),
    IN p_contact_info VARCHAR(1024),
    IN p_app_user_id INT,
    IN p_admin_id INT
)
BEGIN
    -- Sanitize name
    SET p_name = TRIM(p_name);
    IF LENGTH(p_name) < 2 OR LENGTH(p_name) > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor name must be between 2 and 100 characters';
    END IF;
    IF p_name REGEXP '[^a-zA-Z ''-.]' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor name contains invalid characters';
    END IF;
    
    -- Sanitize specialization (if provided)
    IF p_specialization IS NOT NULL AND p_specialization != '' THEN
        SET p_specialization = TRIM(p_specialization);
        IF LENGTH(p_specialization) > 100 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Specialization is too long';
        END IF;
        IF p_specialization REGEXP '[^a-zA-Z ''-]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Specialization contains invalid characters';
        END IF;
    END IF;
    
    -- Validate contact info (if provided)
    IF p_contact_info IS NOT NULL AND p_contact_info != '' THEN
        SET p_contact_info = TRIM(p_contact_info);
        IF LENGTH(p_contact_info) > 1024 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Contact info is too long';
        END IF;
        IF p_contact_info REGEXP '[<>]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Contact info contains invalid characters';
        END IF;
    END IF;
    
    -- Validate app user exists
    IF NOT EXISTS (SELECT 1 FROM AppUser WHERE AppUserId = p_app_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'App user not found';
    END IF;
    
    -- Validate admin exists (if provided)
    IF p_admin_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM Admin WHERE AdminId = p_admin_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Admin not found';
        END IF;
    END IF;
    
    -- Insert with encryption
    INSERT INTO Doctor (Name, Specialization, ContactInfoEncrypted, AppUserId, AdminId)
    VALUES (
        p_name, 
        p_specialization,
        IF(p_contact_info IS NOT NULL AND p_contact_info != '', AES_ENCRYPT(p_contact_info, @enc_key), NULL),
        p_app_user_id,
        p_admin_id
    );
END$$

-- ==========================================
-- MEDICATION MANAGEMENT PROCEDURES
-- ==========================================

DROP PROCEDURE IF EXISTS sp_create_medication$$
CREATE PROCEDURE sp_create_medication(
    IN p_name VARCHAR(100),
    IN p_dosage_form VARCHAR(50),
    IN p_strength VARCHAR(50),
    IN p_instructions TEXT
)
BEGIN
    -- Sanitize medication name
    SET p_name = TRIM(p_name);
    IF LENGTH(p_name) < 2 OR LENGTH(p_name) > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Medication name must be between 2 and 100 characters';
    END IF;
    IF p_name REGEXP '[^a-zA-Z0-9 ''-]' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Medication name contains invalid characters';
    END IF;
    
    -- Sanitize dosage form (if provided)
    IF p_dosage_form IS NOT NULL AND p_dosage_form != '' THEN
        SET p_dosage_form = TRIM(p_dosage_form);
        IF LENGTH(p_dosage_form) > 50 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dosage form is too long';
        END IF;
        IF p_dosage_form REGEXP '[^a-zA-Z ]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dosage form contains invalid characters';
        END IF;
    END IF;
    
    -- Sanitize strength (if provided)
    IF p_strength IS NOT NULL AND p_strength != '' THEN
        SET p_strength = TRIM(p_strength);
        IF LENGTH(p_strength) > 50 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Strength is too long';
        END IF;
        IF p_strength REGEXP '[^a-zA-Z0-9./% ]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Strength contains invalid characters';
        END IF;
    END IF;
    
    -- Sanitize instructions (if provided)
    IF p_instructions IS NOT NULL AND p_instructions != '' THEN
        SET p_instructions = TRIM(p_instructions);
        IF LENGTH(p_instructions) > 5000 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Instructions are too long (max 5000 characters)';
        END IF;
        -- Remove potentially dangerous HTML/script tags
        IF p_instructions REGEXP '<script|<iframe|javascript:' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Instructions contain prohibited content';
        END IF;
    END IF;
    
    -- Check for duplicate medication
    IF EXISTS (SELECT 1 FROM Medication WHERE Name = p_name AND Strength = p_strength) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Medication with same name and strength already exists';
    END IF;
    
    INSERT INTO Medication (Name, DosageForm, Strength, Instructions)
    VALUES (p_name, p_dosage_form, p_strength, p_instructions);
END$$

-- ==========================================
-- PRESCRIPTION MANAGEMENT PROCEDURES
-- ==========================================

DROP PROCEDURE IF EXISTS sp_create_prescription$$
CREATE PROCEDURE sp_create_prescription(
    IN p_doctor_id INT,
    IN p_patient_id INT,
    IN p_notes TEXT
)
BEGIN
    -- Validate doctor exists
    IF NOT EXISTS (SELECT 1 FROM Doctor WHERE DoctorId = p_doctor_id AND IsActive = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or inactive doctor';
    END IF;
    
    -- Validate patient exists
    IF NOT EXISTS (SELECT 1 FROM Patient WHERE PatientId = p_patient_id AND IsActive = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or inactive patient';
    END IF;
    
    -- Sanitize notes (if provided)
    IF p_notes IS NOT NULL AND p_notes != '' THEN
        SET p_notes = TRIM(p_notes);
        IF LENGTH(p_notes) > 10000 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notes are too long (max 10000 characters)';
        END IF;
        IF p_notes REGEXP '<script|<iframe|javascript:' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notes contain prohibited content';
        END IF;
    END IF;
    
    INSERT INTO Prescription (DoctorId, PatientId, Notes)
    VALUES (p_doctor_id, p_patient_id, p_notes);
END$$

DROP PROCEDURE IF EXISTS sp_add_prescription_medication$$
CREATE PROCEDURE sp_add_prescription_medication(
    IN p_prescription_id INT,
    IN p_medication_id INT,
    IN p_dosage_amount INT,
    IN p_timing_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_brand VARCHAR(100)
)
BEGIN
    -- Validate prescription exists
    IF NOT EXISTS (SELECT 1 FROM Prescription WHERE PrescriptionId = p_prescription_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prescription not found';
    END IF;
    
    -- Validate medication exists
    IF NOT EXISTS (SELECT 1 FROM Medication WHERE MedicationId = p_medication_id AND IsActive = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or inactive medication';
    END IF;
    
    -- Validate dosage amount
    IF p_dosage_amount <= 0 OR p_dosage_amount > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dosage amount must be between 1 and 100';
    END IF;
    
    -- Validate timing (if provided)
    IF p_timing_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM MedicationTiming WHERE TimingId = p_timing_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid timing ID';
        END IF;
    END IF;
    
    -- Validate dates
    IF p_start_date IS NOT NULL AND p_start_date < CURDATE() - INTERVAL 1 YEAR THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Start date is too far in the past';
    END IF;
    
    IF p_end_date IS NOT NULL AND p_start_date IS NOT NULL THEN
        IF p_end_date < p_start_date THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'End date cannot be before start date';
        END IF;
        IF DATEDIFF(p_end_date, p_start_date) > 365 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prescription period cannot exceed 1 year';
        END IF;
    END IF;
    
    -- Sanitize brand (if provided)
    IF p_brand IS NOT NULL AND p_brand != '' THEN
        SET p_brand = TRIM(p_brand);
        IF LENGTH(p_brand) > 100 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Brand name is too long';
        END IF;
        IF p_brand REGEXP '[^a-zA-Z0-9 ''-]' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Brand name contains invalid characters';
        END IF;
    END IF;
    
    INSERT INTO PrescriptionMedication (
        PrescriptionId, MedicationId, DosageAmount, TimingId,
        StartDate, EndDate, Brand
    ) VALUES (
        p_prescription_id, p_medication_id, p_dosage_amount, p_timing_id,
        p_start_date, p_end_date, p_brand
    );
END$$

DROP PROCEDURE IF EXISTS sp_update_prescription_dosage$$
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
    
    -- Validate new dosage
    IF p_new_dosage <= 0 OR p_new_dosage > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dosage must be between 1 and 100';
    END IF;
    
    -- Sanitize reason (if provided)
    IF p_reason IS NOT NULL AND p_reason != '' THEN
        SET p_reason = TRIM(p_reason);
        IF LENGTH(p_reason) > 1000 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reason is too long (max 1000 characters)';
        END IF;
        IF p_reason REGEXP '<script|<iframe|javascript:' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reason contains prohibited content';
        END IF;
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

DROP PROCEDURE IF EXISTS sp_record_medication_schedule$$
CREATE PROCEDURE sp_record_medication_schedule(
    IN p_press_med_id INT,
    IN p_day_of_week ENUM('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'),
    IN p_times JSON
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_time_count INT;
    DECLARE v_current_time TIME;
    
    -- Validate prescription exists and is active
    IF NOT EXISTS (SELECT 1 FROM PrescriptionMedication WHERE PressMedId = p_press_med_id AND IsCurrent = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or inactive prescription medication';
    END IF;
    
    -- Validate JSON is not null
    IF p_times IS NULL OR JSON_LENGTH(p_times) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Times array cannot be empty';
    END IF;
    
    -- Get number of times
    SET v_time_count = JSON_LENGTH(p_times);
    
    -- Validate not too many times per day
    IF v_time_count > 10 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot schedule more than 10 times per day';
    END IF;
    
    -- Insert each time
    WHILE i < v_time_count DO
        SET v_current_time = TIME(JSON_UNQUOTE(JSON_EXTRACT(p_times, CONCAT('$[', i, ']'))));
        
        -- Validate time format
        IF v_current_time IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid time format in array';
        END IF;
        
        INSERT INTO PrescriptionSchedule (PressMedId, DayOfWeek, TimeOfDay, DosageAmount)
        VALUES (p_press_med_id, p_day_of_week, v_current_time, 1);
        
        SET i = i + 1;
    END WHILE;
END$$

-- ==========================================
-- SYMPTOM & SIDE EFFECT PROCEDURES
-- ==========================================

DROP PROCEDURE IF EXISTS sp_record_side_effect$$
CREATE PROCEDURE sp_record_side_effect(
    IN p_patient_id INT,
    IN p_side_effect_id INT,
    IN p_press_med_id INT,
    IN p_severity_id INT,
    IN p_onset_date DATE,
    IN p_notes TEXT
)
BEGIN
    -- Validate patient exists
    IF NOT EXISTS (SELECT 1 FROM Patient WHERE PatientId = p_patient_id AND IsActive = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or inactive patient';
    END IF;
    
    -- Validate side effect exists
    IF NOT EXISTS (SELECT 1 FROM SideEffect WHERE SideEffectId = p_side_effect_id AND IsActive = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or inactive side effect';
    END IF;
    
    -- Validate prescription medication exists
    IF NOT EXISTS (SELECT 1 FROM PrescriptionMedication WHERE PressMedId = p_press_med_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid prescription medication';
    END IF;
    
    -- Validate severity exists
    IF NOT EXISTS (SELECT 1 FROM SeverityLevel WHERE SeverityId = p_severity_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid severity level';
    END IF;
    
    -- Validate onset date
    IF p_onset_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Onset date cannot be in the future';
    END IF;
    
    IF p_onset_date < DATE_SUB(CURDATE(), INTERVAL 1 YEAR) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Onset date is too far in the past';
    END IF;
    
    -- Sanitize notes (if provided)
    IF p_notes IS NOT NULL AND p_notes != '' THEN
        SET p_notes = TRIM(p_notes);
        IF LENGTH(p_notes) > 5000 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notes are too long (max 5000 characters)';
        END IF;
        IF p_notes REGEXP '<script|<iframe|javascript:' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notes contain prohibited content';
        END IF;
    END IF;
    
    INSERT INTO PatientSideEffect (
        PatientId, SideEffectId, PressMedId, SeverityId, OnsetDate, Notes
    ) VALUES (
        p_patient_id, p_side_effect_id, p_press_med_id, p_severity_id, p_onset_date, p_notes
    );
END$$

-- ==========================================
-- SECURITY PROCEDURES (Failed Login Tracking)
-- ==========================================

DROP PROCEDURE IF EXISTS sp_failed_login$$
CREATE PROCEDURE sp_failed_login(
    IN p_username VARCHAR(100),
    IN p_max_attempts INT,
    IN p_lock_minutes INT
)
BEGIN
    -- Validate max attempts is reasonable
    IF p_max_attempts < 1 OR p_max_attempts > 10 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Max attempts must be between 1 and 10';
    END IF;
    
    -- Validate lock minutes is reasonable
    IF p_lock_minutes < 1 OR p_lock_minutes > 1440 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lock minutes must be between 1 and 1440 (24 hours)';
    END IF;
    
    -- Increment failed attempts
    UPDATE AppUser
    SET FailedAttempts = FailedAttempts + 1
    WHERE Username = p_username;

    -- Lock account if max attempts reached
    IF (SELECT FailedAttempts FROM AppUser WHERE Username = p_username) >= p_max_attempts THEN
        UPDATE AppUser
        SET IsLocked = TRUE,
            LockedUntil = DATE_ADD(NOW(), INTERVAL p_lock_minutes MINUTE)
        WHERE Username = p_username;
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_successful_login$$
CREATE PROCEDURE sp_successful_login(
    IN p_username VARCHAR(100)
)
BEGIN
    -- Reset failed attempts and update last login
    UPDATE AppUser
    SET FailedAttempts = 0,
        IsLocked = FALSE,
        LockedUntil = NULL,
        LastLogin = NOW()
    WHERE Username = p_username;
END$$

DELIMITER ;

-- ==========================================
-- TEST MESSAGE
-- ==========================================
SELECT 'Comprehensive input sanitization procedures created successfully!' AS Status;
SELECT 'All major operations now have full validation and sanitization' AS Info;