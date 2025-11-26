USE PakarIT;

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