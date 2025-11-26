-- ==========================================
-- POPULATE LOOKUP TABLES FOR KINETICA
-- ==========================================
-- Note: In Kinetica, there's no AUTO_INCREMENT, so we manually specify IDs

INSERT INTO UserRole (RoleId, RoleCode, RoleName, Description) VALUES
(1, 'admin', 'Administrator', 'System administrator with full access'),
(2, 'doctor', 'Doctor', 'Medical doctor who can manage patients and prescriptions'),
(3, 'patient', 'Patient', 'Patient who receives medical care'),
(4, 'system', 'System', 'System/internal user for automated processes');

INSERT INTO SeverityLevel (SeverityId, SeverityCode, SeverityName, ClinicalDescription) VALUES
(1, 'mild', 'Mild', 'Noticeable but does not affect daily activities'),
(2, 'moderate', 'Moderate', 'Affects some daily activities, may require intervention'),
(3, 'severe', 'Severe', 'Significantly affects daily activities, requires immediate attention');

INSERT INTO SideEffectAction (ActionId, ActionCode, ActionName, Description) VALUES
(1, 'none', 'None', 'No action taken, monitoring continued'),
(2, 'dosage_reduced', 'Dosage Reduced', 'Medication dosage was reduced'),
(3, 'medication_changed', 'Medication Changed', 'Switched to different medication'),
(4, 'treatment_stopped', 'Treatment Stopped', 'Medication was discontinued'),
(5, 'other_treatment', 'Other Treatment', 'Additional treatment given for side effect'),
(6, 'other', 'Other', 'Other action taken');

INSERT INTO MedicationTiming (TimingId, Name, Description) VALUES
(1, 'Morning', 'Take in the morning, usually with breakfast'),
(2, 'Noon', 'Take around midday, with lunch'),
(3, 'Evening', 'Take in the evening, with dinner'),
(4, 'Bedtime', 'Take before going to sleep'),
(5, 'As Needed', 'Take only when symptoms occur');
