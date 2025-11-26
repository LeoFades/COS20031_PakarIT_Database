USE PakarIT;

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