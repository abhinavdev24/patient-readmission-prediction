WITH
  readmission AS (
  SELECT
    subject_id,
    hadm_id,
    dischtime,
    LEAD(admittime) OVER (PARTITION BY subject_id ORDER BY admittime) AS next_admittime
  FROM
    `physionet-data.mimiciv_3_1_hosp.admissions` )
SELECT
  subject_id,
  hadm_id,
  dischtime,
  CASE
    WHEN TIMESTAMP_DIFF(next_admittime, dischtime, DAY) <= 30 THEN 1
    ELSE 0
END
  AS readmission_flag
FROM
  readmission