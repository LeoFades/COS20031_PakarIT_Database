USE PakarIT;

-- ==========================================
-- SECURITY VIEWS (For data masking)
-- ==========================================

CREATE VIEW PatientPublic AS
SELECT
    PatientId,
    Name,
    DateOfBirth,
    Gender,
    'ENCRYPTED' AS ContactInfoMask,
    DoctorId
FROM Patient
WITH CASCADED CHECK OPTION;

CREATE VIEW DoctorPublic AS
SELECT
    DoctorId,
    Name,
    Specialization,
    'ENCRYPTED' AS ContactInfoMask
FROM Doctor
WITH CASCADED CHECK OPTION;

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
