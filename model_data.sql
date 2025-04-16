WITH 
-- Compute the total number of procedures for each hospital admission
num_procedures AS (
    SELECT subject_id, hadm_id, COUNT(icd_code) AS num_procedures
    FROM `physionet-data.mimiciv_3_1_hosp.procedures_icd`
    GROUP BY subject_id, hadm_id
),

-- Compute the number of unique procedures for each hospital admission
num_unique_procedures AS (
    SELECT subject_id, hadm_id, COUNT(DISTINCT icd_code) AS num_unique_procedures
    FROM `physionet-data.mimiciv_3_1_hosp.procedures_icd`
    GROUP BY subject_id, hadm_id
),

-- Compute the number of unique ICD codes (diagnoses) for each hospital admission
num_unique_icd_codes AS (
    SELECT subject_id, hadm_id, COUNT(DISTINCT icd_code) AS num_unique_icd_codes
    FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
    GROUP BY subject_id, hadm_id
),

-- Compute the number of unique drugs prescribed per hospital admission
num_unique_drugs AS (
    SELECT subject_id, hadm_id, COUNT(DISTINCT drug) AS num_unique_drugs
    FROM `physionet-data.mimiciv_3_1_hosp.prescriptions`
    WHERE stoptime >= starttime
    GROUP BY subject_id, hadm_id
),

-- Compute the total number of prescription days and the total number of prescription records per hospital admission
num_prescribed_days_and_records AS (
    SELECT subject_id, hadm_id,
           SUM(DATE_DIFF(stoptime, starttime, DAY)) AS num_prescribed_days,
           COUNT(*) AS num_prescription_records
    FROM `physionet-data.mimiciv_3_1_hosp.prescriptions`
    WHERE stoptime >= starttime
    GROUP BY subject_id, hadm_id
),

-- Compute sequential hospitalization count for each patient
num_hospital_admissions AS (
    SELECT 
        subject_id, 
        hadm_id,
        ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY admittime) AS num_hospital_admissions
    FROM `physionet-data.mimiciv_3_1_hosp.admissions`
),

-- From procedures_icd table: concatenated icd_code sorted by chartdate
proc_icd_concat AS (
    SELECT subject_id, hadm_id,
           STRING_AGG(icd_code, ' ' ORDER BY chartdate) AS proc_icd_codes
    FROM `physionet-data.mimiciv_3_1_hosp.procedures_icd`
    GROUP BY subject_id, hadm_id
),

-- From diagnoses_icd table: concatenated icd_code strings
diag_icd_concat AS (
    SELECT subject_id, hadm_id,
           STRING_AGG(icd_code, ' ' ORDER BY seq_num) AS diag_icd_codes
    FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd`
    GROUP BY subject_id, hadm_id
),

-- From drgcodes table: concatenated drg_type and drg_code pairs (e.g., "drg_type drg_code")
drg_concat AS (
    SELECT subject_id, hadm_id,
           STRING_AGG(CONCAT(drg_type, ' ', drg_code), ' ') AS drg_concat
    FROM `physionet-data.mimiciv_3_1_hosp.drgcodes`
    GROUP BY subject_id, hadm_id
),

-- New: From drgcodes table, select top DRG info by severity and mortality
drg_top_info AS (
    SELECT
      subject_id,
      hadm_id,
      ARRAY_AGG(STRUCT(
          drg_code,
          drg_type,
          drg_severity,
          drg_mortality
      ) ORDER BY drg_severity DESC, drg_mortality DESC LIMIT 1)[OFFSET(0)] AS drg_info
    FROM `physionet-data.mimiciv_3_1_hosp.drgcodes`
    GROUP BY subject_id, hadm_id
),

-- From emar table: count the number of medication events where event_txt = "Administered"
emar_med_count AS (
    SELECT subject_id, hadm_id,
           COUNT(medication) AS num_emar_medications
    FROM `physionet-data.mimiciv_3_1_hosp.emar`
    WHERE event_txt = "Administered"
    GROUP BY subject_id, hadm_id
),

-- From labevents table: count abnormal lab events where flag = "abnormal"
abnormal_labevents AS (
    SELECT subject_id, hadm_id,
           COUNT(labevent_id) AS num_abnormal_labevents
    FROM `physionet-data.mimiciv_3_1_hosp.labevents`
    WHERE flag = "abnormal"
    GROUP BY subject_id, hadm_id
),

-- Compute counts of previous admissions based on admission_location (from admissions table)
prev_visits AS (
    SELECT 
        curr.subject_id, 
        curr.hadm_id,
        COALESCE(SUM(CASE WHEN prev.admission_location = 'EMERGENCY ROOM' THEN 1 ELSE 0 END), 0) AS num_prev_emergency,
        COALESCE(SUM(CASE WHEN prev.admission_location NOT IN ('EMERGENCY ROOM', 'INTERNAL TRANSFER TO OR FROM PSYCH') THEN 1 ELSE 0 END), 0) AS num_prev_non_emergency
    FROM `physionet-data.mimiciv_3_1_hosp.admissions` curr
    LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` prev
      ON curr.subject_id = prev.subject_id 
         AND prev.admittime < curr.admittime
    GROUP BY curr.subject_id, curr.hadm_id
),

-- Compute counts of previous visits by careunit class from transfers table.
-- Only transfers with intime earlier than current admission's admittime are considered.
prev_transfers AS (
    SELECT 
        curr.subject_id,
        curr.hadm_id,
        SUM(CASE 
              WHEN t.careunit IN ('Med/Surg', 'Med/Surg/GYN', 'Med/Surg/Trauma', 'Medical/Surgical (Gynecology)', 
                                  'Observation', 'Discharge Lounge', 'Emergency Department Observation', 
                                  'Nursery', 'Special Care Nursery (SCN)') 
              THEN 1 ELSE 0 END) AS num_prev_general_practice,
        SUM(CASE 
              WHEN t.careunit IN ('Surgery', 'Surgery/Trauma', 'Surgery/Vascular/Intermediate', 
                                  'Surgery/Pancreatic/Biliary/Bariatric', 'Surgical Intermediate', 
                                  'Surgical Intensive Care Unit (SICU)', 'Cardiac Surgery', 'Thoracic Surgery', 
                                  'Cardiology Surgery Intermediate') 
              THEN 1 ELSE 0 END) AS num_prev_general_surgery,
        SUM(CASE 
              WHEN t.careunit IN ('Medicine', 'Medicine/Cardiology', 'Medicine/Cardiology Intermediate', 
                                  'Cardiology', 'Neurology', 'Neuro Stepdown', 'Neuro Intermediate', 
                                  'Psychiatry', 'Oncology', 'Hematology/Oncology', 'Hematology/Oncology Intermediate', 
                                  'Vascular', 'Transplant', 'Intensive Care Unit (ICU)', 'Medical Intensive Care Unit (MICU)', 
                                  'Medical/Surgical Intensive Care Unit (MICU/SICU)', 'Neuro Surgical Intensive Care Unit (Neuro SICU)', 
                                  'Cardiac Vascular Intensive Care Unit (CVICU)', 'Coronary Care Unit (CCU)') 
              THEN 1 ELSE 0 END) AS num_prev_internal_medicine
    FROM `physionet-data.mimiciv_3_1_hosp.admissions` curr
    LEFT JOIN `physionet-data.mimiciv_3_1_hosp.transfers` t
      ON curr.subject_id = t.subject_id
         AND t.intime < curr.admittime
    GROUP BY curr.subject_id, curr.hadm_id
)

-- Main query: join all computed features into a single dataset for model training
SELECT 
    h.subject_id,                     -- Unique patient identifier
    h.hadm_id,                        -- Unique hospital admission identifier
    h.race,                           -- Race of the patient
    h.admittime,                      -- Admission timestamp
    h.dischtime,                      -- Discharge timestamp
    h.hospital_expire_flag,           -- Indicates if the patient expired during hospitalization

    r.readmission_flag,               -- 1 if the patient was readmitted within 30 days, 0 otherwise

    np.num_procedures,                -- Total number of procedures performed during admission
    nup.num_unique_procedures,        -- Number of unique procedure codes used
    nuic.num_unique_icd_codes,        -- Number of unique ICD diagnoses assigned during admission
    nud.num_unique_drugs,             -- Number of unique drugs prescribed during admission
    npd.num_prescribed_days,          -- Total number of days the patient was prescribed medication
    npd.num_prescription_records,     -- Total number of prescription records for the admission
    nha.num_hospital_admissions,      -- Sequential count of hospital admissions for the patient
    
    pic.proc_icd_codes,               -- Concatenated ICD codes from procedures_icd (sorted by chartdate)
    dic.diag_icd_codes,               -- Concatenated ICD codes from diagnoses_icd
    dc.drg_concat,                    -- Concatenated drg_type and drg_code pairs from drgcodes
    
    dti.drg_info.drg_code AS top_drg_code,          -- Top DRG code from drg_top_info
    dti.drg_info.drg_type AS top_drg_type,           -- Top DRG type from drg_top_info
    dti.drg_info.drg_severity AS top_drg_severity,   -- Top DRG severity from drg_top_info
    dti.drg_info.drg_mortality AS top_drg_mortality, -- Top DRG mortality from drg_top_info
    
    emc.num_emar_medications,         -- Number of medication events from emar where event_txt = "Administered"
    lab.num_abnormal_labevents,       -- Number of abnormal lab events from labevents

    pv.num_prev_emergency,            -- Count of previous emergency visits from admissions table
    pv.num_prev_non_emergency,        -- Count of previous non-emergency visits from admissions table

    pt.num_prev_general_practice,     -- Count of previous General Practice visits from transfers
    pt.num_prev_general_surgery,      -- Count of previous General Surgery visits from transfers
    pt.num_prev_internal_medicine,    -- Count of previous Internal Medicine visits from transfers

    ag.age,                         -- Age from processed age table
    ci.charlson_comorbidity_index   -- Charlson Comorbidity Index from processed comorbidity_index table

FROM `physionet-data.mimiciv_3_1_hosp.admissions` h

-- Join the computed readmission labels
LEFT JOIN `datamining-neu.mimic_processed.readmission` r 
    ON h.hadm_id = r.hadm_id AND h.subject_id = r.subject_id

-- Join the computed number of procedures
LEFT JOIN num_procedures np 
    ON h.subject_id = np.subject_id AND h.hadm_id = np.hadm_id

-- Join the computed number of unique procedures
LEFT JOIN num_unique_procedures nup 
    ON h.subject_id = nup.subject_id AND h.hadm_id = nup.hadm_id

-- Join the computed number of unique ICD diagnoses
LEFT JOIN num_unique_icd_codes nuic 
    ON h.subject_id = nuic.subject_id AND h.hadm_id = nuic.hadm_id

-- Join the computed number of unique drugs prescribed
LEFT JOIN num_unique_drugs nud 
    ON h.subject_id = nud.subject_id AND h.hadm_id = nud.hadm_id

-- Join the computed prescription duration and records
LEFT JOIN num_prescribed_days_and_records npd 
    ON h.subject_id = npd.subject_id AND h.hadm_id = npd.hadm_id

-- Join the computed sequential hospitalization count
LEFT JOIN num_hospital_admissions nha 
    ON h.subject_id = nha.subject_id AND h.hadm_id = nha.hadm_id

-- Join concatenated procedures ICD codes
LEFT JOIN proc_icd_concat pic 
    ON h.subject_id = pic.subject_id AND h.hadm_id = pic.hadm_id

-- Join concatenated diagnoses ICD codes
LEFT JOIN diag_icd_concat dic 
    ON h.subject_id = dic.subject_id AND h.hadm_id = dic.hadm_id

-- Join concatenated drgcodes
LEFT JOIN drg_concat dc 
    ON h.subject_id = dc.subject_id AND h.hadm_id = dc.hadm_id

-- Join DRG top information
LEFT JOIN drg_top_info dti 
    ON h.subject_id = dti.subject_id AND h.hadm_id = dti.hadm_id

-- Join emar medication count
LEFT JOIN emar_med_count emc 
    ON h.subject_id = emc.subject_id AND h.hadm_id = emc.hadm_id

-- Join abnormal lab events count
LEFT JOIN abnormal_labevents lab 
    ON h.subject_id = lab.subject_id AND h.hadm_id = lab.hadm_id

-- Join previous visits counts from admissions
LEFT JOIN prev_visits pv 
    ON h.subject_id = pv.subject_id AND h.hadm_id = pv.hadm_id

-- Join previous transfers counts by careunit class
LEFT JOIN prev_transfers pt 
    ON h.subject_id = pt.subject_id AND h.hadm_id = pt.hadm_id

-- Join age from processed age table
LEFT JOIN `datamining-neu.mimic_processed.age` ag
    ON h.subject_id = ag.subject_id AND h.hadm_id = ag.hadm_id

-- Join Charlson comorbidity index from processed comorbidity_index table
LEFT JOIN `datamining-neu.mimic_processed.comorbidity_index` ci
    ON h.subject_id = ci.subject_id AND h.hadm_id = ci.hadm_id

WHERE
  h.deathtime IS NULL;
