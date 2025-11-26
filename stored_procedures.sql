USE PakarIT;

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

-- ==========================================
-- SECURITY PROCEDURES (Failed Login Tracking)
-- ==========================================

CREATE PROCEDURE sp_failed_login(
    IN p_username VARCHAR(100),
    IN p_max_attempts INT,
    IN p_lock_minutes INT
)
BEGIN
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