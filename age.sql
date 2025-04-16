SELECT
    ad.subject_id
    , ad.hadm_id
    , pa.anchor_age + DATETIME_DIFF(ad.admittime, DATETIME(pa.anchor_year, 1, 1, 0, 0, 0), YEAR) AS age -- noqa: L016
FROM `physionet-data.mimiciv_3_1_hosp.admissions` ad
INNER JOIN `physionet-data.mimiciv_3_1_hosp.patients` pa
    ON ad.subject_id = pa.subject_id
