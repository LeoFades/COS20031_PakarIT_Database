-- ==========================================
-- KINETICA SECURITY VIEWS (For data masking)
-- ==========================================
-- Note: Kinetica supports views with similar syntax to MySQL
-- However, WITH CHECK OPTION may have different behavior

CREATE VIEW PatientPublic AS
SELECT
    PatientId,
    Name,
    DateOfBirth,
    Gender,
    'ENCRYPTED' AS ContactInfoMask,
    DoctorId,
    IsActive,
    CreatedAt
FROM Patient;

CREATE VIEW DoctorPublic AS
SELECT
    DoctorId,
    Name,
    Specialization,
    'ENCRYPTED' AS ContactInfoMask,
    IsActive,
    CreatedAt
FROM Doctor;

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
-- ALERT MONITORING VIEW
-- ==========================================

CREATE VIEW AlertDashboard AS
SELECT 
    'Compliance' AS AlertType,
    p.PatientId,
    p.Name AS PatientName,
    p.ComplianceStatus AS Status,
    p.LastComplianceCheck AS LastChecked,
    'Compliance Rate: ' || p.ComplianceStatus AS Details,  -- CONCAT replaced with ||
    d.Name AS AssignedDoctor
FROM Patient p
LEFT JOIN Doctor d ON p.DoctorId = d.DoctorId
WHERE p.ComplianceStatus IN ('Warning', 'Critical')

UNION ALL

SELECT 
    'Side Effect' AS AlertType,
    pse.PatientId,
    p.Name AS PatientName,
    sl.SeverityName AS Status,
    pse.RecordedAt AS LastChecked,
    'Side Effect: ' || se.Name || ' - Requires Review' AS Details,  -- CONCAT replaced with ||
    d.Name AS AssignedDoctor
FROM PatientSideEffect pse
JOIN Patient p ON pse.PatientId = p.PatientId
LEFT JOIN Doctor d ON p.DoctorId = d.DoctorId
JOIN SideEffect se ON pse.SideEffectId = se.SideEffectId
JOIN SeverityLevel sl ON pse.SeverityId = sl.SeverityId
WHERE pse.RequiresDoctorReview = TRUE
AND pse.ReviewedAt IS NULL

UNION ALL

SELECT 
    'Unresolved Side Effect' AS AlertType,
    pse.PatientId,
    p.Name AS PatientName,
    'Critical' AS Status,
    pse.OnsetDate AS LastChecked,
    'Severe side effect unresolved for ' || CAST(DATEDIFF(DAY, pse.OnsetDate, CURRENT_TIMESTAMP) AS VARCHAR(10)) || ' days' AS Details,
    d.Name AS AssignedDoctor
FROM PatientSideEffect pse
JOIN Patient p ON pse.PatientId = p.PatientId
LEFT JOIN Doctor d ON p.DoctorId = d.DoctorId
JOIN SeverityLevel sl ON pse.SeverityId = sl.SeverityId
WHERE sl.SeverityCode = 'severe'
AND pse.ResolutionDate IS NULL
AND DATEDIFF(DAY, pse.OnsetDate, CURRENT_TIMESTAMP) >= 7;
