# Patient Readmission Prediction

## Overview

This project aims to predict whether a patient will be readmitted within 30 days of hospital discharge using machine learning models. Accurate prediction enables timely interventions, improves patient outcomes, and reduces hospital readmission costs.

## Objectives and Metrics

### Objectives

- Predict 30-day readmissions using MIMIC-IV data.
- Identify key factors influencing readmission.
- Enable early interventions for high-risk patients.

### Key Results

- Achieve good accuracy on the test dataset.
- Keep false negative rate low.
- Ensure interpretability by highlighting key predictors.

### KPIs

- Accuracy, Precision, Recall, and F1-score.
- Feature importance from models.

---

## Data

### Source

The data is extracted from the [MIMIC-IV v3.1](https://physionet.org/content/mimiciv/3.1/) database. It includes anonymized health records from over 364,000 patients admitted to the ICU at Beth Israel Deaconess Medical Center.

### Key Tables

- `admissions`, `patients`, `icustays`: Demographics and hospitalization details.
- `diagnoses_icd`, `procedures_icd`: ICD codes for conditions and procedures.
- `prescriptions`, `emar`: Medication details.
- `drgcodes`, `labevents`: DRG data and lab results.

### Feature Engineering

Features were engineered from timestamps, medication records, lab abnormalities, unit transfers, DRG codes, and comorbidities. Word2Vec embeddings were created for ICD codes to capture contextual sequence information.

Key features:

- Number of previous emergency visits.
- Charlson comorbidity index.
- Top DRG severity and mortality.
- Word2Vec embeddings for diagnoses and procedures.

---

## SQL Scripts

All SQL files were executed on **Google BigQuery** to prepare the dataset from raw MIMIC-IV tables:

- `model_data.sql`:  
  Primary script used to extract and join multiple tables (admissions, diagnoses, procedures, labevents, emar, etc.) to create the final dataset used for modeling.

- `age.sql`:  
  Calculates patient age at the time of admission by joining patient demographics with admission timestamps.

- `comorbidity_index.sql`:  
  Computes the Charlson Comorbidity Index for each admission using ICD codes to quantify the severity of comorbid conditions.

- `readmission.sql`:  
  Generates the `readmission_flag` (1 for readmitted within 30 days, 0 otherwise) by self-joining the admissions table based on patient ID and admission timestamps.

These scripts form the backbone of the data engineering pipeline, ensuring clean and feature-rich inputs for model training.

---

## Data Exploration & Preprocessing

Performed in [`data_exploration.ipynb`](data_exploration.ipynb):

- 534,238 records with 32 features.
- 20.2% of patients were readmitted.
- Missing values were imputed (0 for numerics, "UNKNOWN" for categoricals).
- Removed unique identifiers.
- PCA showed that >86% variance is captured in PC1.

---

## Modeling

Conducted in [`model_building.ipynb`](model_building.ipynb):

### Models Evaluated

- Logistic Regression
- Random Forest
- XGBoost
- LightGBM (Best Performance)
- CatBoost

### Preprocessing

- One-hot encoding for categorical variables.
- Oversampling applied to training set for class balance.
- Stratified train-test split.

### Evaluation Metrics

- Precision, Recall, F1-score
- ROC-AUC

### Best Model: LightGBM

- Accuracy: 63.16%
- F1-score (Class 1): 0.626
- Precision: 0.635
- Recall: 0.618

### Post-tuning: ROC-AUC curve improved, reaffirming LightGBM as the top model

---

## Project Impact

- Enables hospitals to proactively plan discharge and follow-up care for high-risk patients.
- Reduces avoidable readmissions, improving hospital efficiency and patient outcomes.
- Aids healthcare policy by revealing key readmission factors.
- Showcases machine learning's role in transforming clinical decision-making.

---

## File Structure

- `data_exploration.ipynb`: Data loading, cleaning, visualization, imputation, PCA.
- `model_building.ipynb`: Model training, evaluation, hyperparameter tuning.
- `model_data.sql`: Extracts and joins MIMIC-IV tables to create modeling dataset.
- `readmission.sql`: Defines readmission within 30 days logic.
- `age.sql`: Computes patient age.
- `comorbidity_index.sql`: Calculates Charlson Comorbidity Index.

---

## Getting Started

### Prerequisites

Before running the notebooks, you must obtain access to the MIMIC-IV dataset and prepare the modeling data using SQL.

1. **Get Access to MIMIC-IV Dataset**  
   Register and complete the required data use agreement on [PhysioNet](https://physionet.org/content/mimiciv/3.1/) to gain access to MIMIC-IV.

2. **Set Up Google BigQuery**  
   Upload the MIMIC-IV tables to Google BigQuery (if not already available via a hosted version) and create a project.

3. **Run SQL Scripts to Generate Dataset**  
   Use the following SQL files provided in this repository to prepare your dataset

   - `model_data.sql`: Extracts and joins data from multiple tables to form the modeling dataset.
   - `readmission.sql`: Flags patients readmitted within 30 days.
   - `age.sql`: Calculates patient age at admission.
   - `comorbidity_index.sql`: Computes Charlson Comorbidity Index.

4. **Export the Final Dataset**  
   Export the result of `model_data.sql` to a CSV file (or your preferred format) for use in the notebooks.

---

### Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/abhinavdev24/patient-readmission-prediction.git
   cd patient-readmission-prediction
   ```

2. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

3. Run in order:

   - `data_exploration.ipynb` – for cleaning, EDA, and feature preprocessing
   - `model_building.ipynb` - for model training, evaluation, and tuning

### Contributing

Contributions are welcome. Feel free to fork the repo and submit a pull request with enhancements or bug fixes.

### License

This project is licensed under the **MIT License** – see the [LICENSE](LICENSE) file for details.

**Note:** This project uses the MIMIC-IV dataset. To use this data, you must first obtain access via [PhysioNet](https://physionet.org/content/mimiciv/3.1/) and comply with their data use agreement. The dataset is not distributed with this repository and must be queried separately through Google BigQuery or another approved access method.
