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

DELIMITER ;