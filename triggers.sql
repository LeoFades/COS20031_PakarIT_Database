USE PakarIT;

DELIMITER $$

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
-- COMPREHENSIVE AUDIT TRIGGERS
-- ==========================================

-- PATIENT TRIGGERS
CREATE TRIGGER trg_audit_patient_insert
AFTER INSERT ON Patient
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, NewData)
    VALUES('Patient', 'INSERT', CONCAT('PatientId=', NEW.PatientId),
        JSON_OBJECT(
            'Name', NEW.Name, 
            'DateOfBirth', CAST(NEW.DateOfBirth AS CHAR), 
            'Gender', NEW.Gender,
            'DoctorId', NEW.DoctorId
        )
    );
END$$

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

CREATE TRIGGER trg_audit_patient_delete
AFTER DELETE ON Patient
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, OldData)
    VALUES('Patient', 'DELETE', CONCAT('PatientId=', OLD.PatientId),
        JSON_OBJECT(
            'Name', OLD.Name, 
            'DateOfBirth', CAST(OLD.DateOfBirth AS CHAR), 
            'Gender', OLD.Gender,
            'DoctorId', OLD.DoctorId
        )
    );
END$$

-- PRESCRIPTION TRIGGERS
CREATE TRIGGER trg_audit_prescription_insert
AFTER INSERT ON Prescription
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, NewData)
    VALUES('Prescription', 'INSERT', CONCAT('PrescriptionId=', NEW.PrescriptionId),
        JSON_OBJECT(
            'DoctorId', NEW.DoctorId,
            'PatientId', NEW.PatientId,
            'Status', NEW.Status,
            'Notes', NEW.Notes
        )
    );
END$$

CREATE TRIGGER trg_audit_prescription_delete
AFTER DELETE ON Prescription
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, OldData)
    VALUES('Prescription', 'DELETE', CONCAT('PrescriptionId=', OLD.PrescriptionId),
        JSON_OBJECT(
            'DoctorId', OLD.DoctorId,
            'PatientId', OLD.PatientId,
            'Status', OLD.Status
        )
    );
END$$

-- PRESCRIPTION MEDICATION TRIGGERS
CREATE TRIGGER trg_audit_presmed_insert
AFTER INSERT ON PrescriptionMedication
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, NewData)
    VALUES('PrescriptionMedication', 'INSERT', CONCAT('PressMedId=', NEW.PressMedId),
        JSON_OBJECT(
            'PrescriptionId', NEW.PrescriptionId,
            'MedicationId', NEW.MedicationId,
            'DosageAmount', NEW.DosageAmount,
            'Status', NEW.Status,
            'Version', NEW.Version
        )
    );
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

CREATE TRIGGER trg_audit_presmed_delete
AFTER DELETE ON PrescriptionMedication
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, OldData)
    VALUES('PrescriptionMedication', 'DELETE', CONCAT('PressMedId=', OLD.PressMedId),
        JSON_OBJECT(
            'PrescriptionId', OLD.PrescriptionId,
            'MedicationId', OLD.MedicationId,
            'DosageAmount', OLD.DosageAmount,
            'Version', OLD.Version
        )
    );
END$$

-- COMPLIANCE TRIGGERS
CREATE TRIGGER trg_audit_compliance_insert
AFTER INSERT ON Compliance
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, NewData)
    VALUES('Compliance', 'INSERT', CONCAT('ComplianceId=', NEW.ComplianceId),
        JSON_OBJECT(
            'ReminderId', NEW.ReminderId,
            'Status', NEW.Status,
            'DosageTaken', NEW.DosageTaken,
            'TakenAt', CAST(NEW.TakenAt AS CHAR)
        )
    );
END$$

CREATE TRIGGER trg_audit_compliance_delete
AFTER DELETE ON Compliance
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, OldData)
    VALUES('Compliance', 'DELETE', CONCAT('ComplianceId=', OLD.ComplianceId),
        JSON_OBJECT(
            'ReminderId', OLD.ReminderId,
            'Status', OLD.Status,
            'DosageTaken', OLD.DosageTaken
        )
    );
END$$

-- ==========================================
-- AUTOMATIC THRESHOLD CHECK TRIGGERS
-- ==========================================

-- TRIGGER 1: Auto-flag severe side effects for doctor review
CREATE TRIGGER trg_auto_flag_severe_sideeffect
BEFORE INSERT ON PatientSideEffect
FOR EACH ROW
BEGIN
    DECLARE v_severity_code VARCHAR(10);
    
    -- Get severity code
    SELECT SeverityCode INTO v_severity_code 
    FROM SeverityLevel 
    WHERE SeverityId = NEW.SeverityId;
    
    -- If severe, automatically flag for doctor review
    IF v_severity_code = 'severe' THEN
        SET NEW.RequiresDoctorReview = TRUE;
    END IF;
END$$

CREATE TRIGGER trg_auto_flag_severe_sideeffect_update
BEFORE UPDATE ON PatientSideEffect
FOR EACH ROW
BEGIN
    DECLARE v_severity_code VARCHAR(10);
    
    -- Get severity code
    SELECT SeverityCode INTO v_severity_code 
    FROM SeverityLevel 
    WHERE SeverityId = NEW.SeverityId;
    
    -- If severity increased to severe, flag for review
    IF v_severity_code = 'severe' AND OLD.RequiresDoctorReview = FALSE THEN
        SET NEW.RequiresDoctorReview = TRUE;
    END IF;
END$$

-- TRIGGER 2: Auto-update prescription status based on dates
CREATE TRIGGER trg_auto_update_prescription_status
BEFORE UPDATE ON PrescriptionMedication
FOR EACH ROW
BEGIN
    -- If end date has passed, mark as Completed
    IF NEW.EndDate IS NOT NULL AND NEW.EndDate <= CURDATE() AND OLD.Status != 'Completed' THEN
        SET NEW.Status = 'Completed';
    END IF;
END$$

-- TRIGGER 3: Monitor patient compliance rate
CREATE TRIGGER trg_auto_check_patient_compliance
AFTER INSERT ON Compliance
FOR EACH ROW
BEGIN
    DECLARE v_patient_id INT;
    DECLARE v_total_doses INT;
    DECLARE v_missed_doses INT;
    DECLARE v_compliance_rate DECIMAL(5,2);
    
    -- Get patient ID from reminder
    SELECT PatientId INTO v_patient_id
    FROM Reminder
    WHERE ReminderId = NEW.ReminderId;
    
    -- Calculate compliance for last 30 days
    SELECT 
        COUNT(*) INTO v_total_doses
    FROM Compliance c
    JOIN Reminder r ON c.ReminderId = r.ReminderId
    WHERE r.PatientId = v_patient_id
    AND c.TakenAt >= DATE_SUB(NOW(), INTERVAL 30 DAY);
    
    -- Count missed doses
    SELECT 
        COUNT(*) INTO v_missed_doses
    FROM Compliance c
    JOIN Reminder r ON c.ReminderId = r.ReminderId
    WHERE r.PatientId = v_patient_id
    AND c.Status IN ('Missed', 'Skipped')
    AND c.TakenAt >= DATE_SUB(NOW(), INTERVAL 30 DAY);
    
    -- Calculate compliance rate
    IF v_total_doses > 0 THEN
        SET v_compliance_rate = ((v_total_doses - v_missed_doses) / v_total_doses) * 100;
        
        -- Update patient status based on threshold
        -- Critical: < 50%, Warning: < 80%, Good: >= 80%
        IF v_compliance_rate < 50 THEN
            UPDATE Patient 
            SET ComplianceStatus = 'Critical',
                LastComplianceCheck = NOW()
            WHERE PatientId = v_patient_id;
        ELSEIF v_compliance_rate < 80 THEN
            UPDATE Patient 
            SET ComplianceStatus = 'Warning',
                LastComplianceCheck = NOW()
            WHERE PatientId = v_patient_id;
        ELSE
            UPDATE Patient 
            SET ComplianceStatus = 'Good',
                LastComplianceCheck = NOW()
            WHERE PatientId = v_patient_id;
        END IF;
    END IF;
END$$

-- TRIGGER 4: Alert if patient has multiple severe side effects
CREATE TRIGGER trg_auto_check_multiple_sideeffects
AFTER INSERT ON PatientSideEffect
FOR EACH ROW
BEGIN
    DECLARE v_severe_count INT;
    
    -- Count severe side effects in last 7 days
    SELECT COUNT(*) INTO v_severe_count
    FROM PatientSideEffect pse
    JOIN SeverityLevel sl ON pse.SeverityId = sl.SeverityId
    WHERE pse.PatientId = NEW.PatientId
    AND sl.SeverityCode = 'severe'
    AND pse.RecordedAt >= DATE_SUB(NOW(), INTERVAL 7 DAY);
    
    -- If 2 or more severe side effects, flag all for review
    IF v_severe_count >= 2 THEN
        UPDATE PatientSideEffect
        SET RequiresDoctorReview = TRUE
        WHERE PatientId = NEW.PatientId
        AND RecordedAt >= DATE_SUB(NOW(), INTERVAL 7 DAY);
    END IF;
END$$

-- TRIGGER 5: Check unresolved severe side effects (7+ days)
CREATE TRIGGER trg_auto_check_unresolved_sideeffect
AFTER UPDATE ON PatientSideEffect
FOR EACH ROW
BEGIN
    DECLARE v_severity_code VARCHAR(10);
    DECLARE v_days_since_onset INT;
    
    -- Get severity code
    SELECT SeverityCode INTO v_severity_code 
    FROM SeverityLevel 
    WHERE SeverityId = NEW.SeverityId;
    
    -- Calculate days since onset
    SET v_days_since_onset = DATEDIFF(NOW(), NEW.OnsetDate);
    
    -- If severe side effect unresolved for 7+ days, log alert
    IF v_severity_code = 'severe' 
       AND NEW.ResolutionDate IS NULL 
       AND v_days_since_onset >= 7 THEN
        
        -- Add audit log entry for doctor attention
        INSERT INTO AuditLog(TableName, Action, RowPrimaryKey, NewData, Notes)
        VALUES('PatientSideEffect', 'UPDATE', 
               CONCAT('PatientSideEffectId=', NEW.PatientSideEffectId),
               JSON_OBJECT('PatientId', NEW.PatientId, 'PressMedId', NEW.PressMedId),
               'ALERT: Severe side effect unresolved for 7+ days - medication review recommended');
    END IF;
END$$

DELIMITER ;