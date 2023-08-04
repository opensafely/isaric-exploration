################################################################################
#
# Description: This script provides the formal specification of the study data 
#              that will be extracted from the OpenSAFELY database.
#
# Output: output/admissions/isaric_admission1.csv.gz
#
# Author(s): S Maude, W Hulme, M Green
# Date last updated: 04/08/2023
#
################################################################################





# IMPORT STATEMENTS ------------------------

# Import tables and Python objects
from ehrql import Dataset, days, years, case, when
from ehrql.tables.beta.tpp import clinical_events, isaric_raw, patients, sgss_covid_all_tests, vaccinations

# Import codelists
import codelists_ehrql

# Functions
from variables import add_primary_care_variable





# DEFINE DATASET ------------------------

# Create dataset object for output dataset
dataset = Dataset()

# Define dataset a all patients with an entry in the ISARIC table.
dataset.define_population(isaric_raw.exists_for_patient())






# ADD BASIC INFO ABOUT PATIENTS FIRST ADMISSION (as recorded at time of admission) ------------------------

# Filter isaric table on first admission for each patient
# Note that sort is on age rather than admission_date as this is more reliable due to some dodgy admission_date values
first_isaric_admission = (isaric_raw.sort_by(isaric_raw.age).first_for_patient())

# Admission date
dataset.admission_date = first_isaric_admission.hostdat

# Age
dataset.age_isaric = first_isaric_admission.age
dataset.calc_age_isaric = first_isaric_admission.calc_age

# Sex
dataset.sex_isaric = first_isaric_admission.sex

# COVID-19 infection
dataset.corona_ieorres_isaric = first_isaric_admission.corona_ieorres
dataset.coriona_ieorres2_isaric = first_isaric_admission.coriona_ieorres2
dataset.coriona_ieorres3_isaric = first_isaric_admission.coriona_ieorres3

# Adult or child who meets case definition for inflammatory multi-system syndrome (MIS-C/MIS-A).
dataset.inflammatory_mss_isaric = first_isaric_admission.inflammatory_mss

# Ethnicity
dataset.eth1_isaric = first_isaric_admission.ethnic___1
dataset.eth2_isaric = first_isaric_admission.ethnic___2
dataset.eth3_isaric = first_isaric_admission.ethnic___3
dataset.eth4_isaric = first_isaric_admission.ethnic___4
dataset.eth5_isaric = first_isaric_admission.ethnic___5
dataset.eth6_isaric = first_isaric_admission.ethnic___6
dataset.eth7_isaric = first_isaric_admission.ethnic___7
dataset.eth8_isaric = first_isaric_admission.ethnic___8
dataset.eth9_isaric = first_isaric_admission.ethnic___9
dataset.eth10_isaric = first_isaric_admission.ethnic___10

# COVID-19 vaccination
dataset.covid19_vaccine_isaric = first_isaric_admission.covid19_vaccine





# ADD COMORBIDITY INFO (as recorded at the time of first admission) ------------------------

# Chronic cardiac disease
dataset.ccd_isaric = first_isaric_admission.chrincard

# Hypertension
dataset.hypertension_isaric = first_isaric_admission.hypertension_mhyn

# Chronic pulmonary disease
dataset.copd_isaric = first_isaric_admission.chronicpul_mhyn

# Asthma
dataset.asthma_isaric = first_isaric_admission.asthma_mhyn

# Chronic kidney disease
dataset.ckd_isaric = first_isaric_admission.renal_mhyn

# Liver disease
dataset.mildliver_isaric = first_isaric_admission.mildliver
dataset.modliver_isaric = first_isaric_admission.modliv

# Chronic neurological disorder
dataset.neuro_isaric = first_isaric_admission.chronicneu_mhyn

# Cancer
dataset.cancer_isaric = first_isaric_admission.malignantneo_mhyn
dataset.cancer_haemo_isaric = first_isaric_admission.chronichaemo_mhyn

# AIDS/HIV
dataset.hiv_isaric = first_isaric_admission.aidshiv_mhyn

# Obesity
dataset.obesity_isaric = first_isaric_admission.obesity_mhyn

# Diabetes
dataset.diabetes_isaric = first_isaric_admission.diabetes_mhyn
dataset.diabetescom_isaric = first_isaric_admission.diabetescom_mhyn

# Rheumatologic disorder
dataset.rheumatologic_isaric = first_isaric_admission.rheumatologic_mhyn

# Dementia
dataset.dementia_isaric = first_isaric_admission.dementia_mhyn

# Malnutrition
dataset.malnutrition_isaric = first_isaric_admission.malnutrition_mhyn

# Smoking
dataset.smoking_isaric = first_isaric_admission.smoking_mhyn





# EXTRACT EQUIVALENT DATA FROM PRIMARY CARE RECORDS ------------------------
# Note, these may not exactly match the clinical definitions used on the ISARIC case report forms

# Age
dataset.age_pc = patients.age_on(dataset.admission_date)

# Sex
dataset.sex_pc = patients.sex

# Ethnicity
ethnicity6 = clinical_events.where(clinical_events.snomedct_code.is_in(codelists_ehrql.ethnicity_codelist)
    ).where(
        clinical_events.date.is_on_or_before(dataset.admission_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient().snomedct_code.to_category(codelists_ehrql.ethnicity_codelist)

dataset.ethnicity_pc = case(
    when(ethnicity6 == "1").then("White"),
    when(ethnicity6 == "2").then("Mixed"),
    when(ethnicity6 == "3").then("South Asian"),
    when(ethnicity6 == "4").then("Black"),
    when(ethnicity6 == "5").then("Other"),
    when(ethnicity6 == "6").then("Not stated"),
    default = "Unknown"
)

# COVID-19 infection
dataset.suspected_covid_date_pc = clinical_events.where(
  clinical_events.ctv3_code.is_in(codelists_ehrql.primary_care_suspected_covid_combined)
  ).where(
    clinical_events.date.is_on_or_before(dataset.admission_date)
    ).sort_by(
      clinical_events.date
      ).last_for_patient().date

dataset.probable_covid_date_pc = clinical_events.where(
  clinical_events.ctv3_code.is_in(codelists_ehrql.covid_primary_care_probable_combined)
  ).where(
    clinical_events.date.is_on_or_before(dataset.admission_date)
    ).sort_by(
      clinical_events.date
      ).last_for_patient().date

dataset.last_positive_test_date_pc = sgss_covid_all_tests.where(sgss_covid_all_tests.is_positive
    ).where(
        sgss_covid_all_tests.specimen_taken_date.is_on_or_before(dataset.admission_date)
    ).sort_by(
        sgss_covid_all_tests.specimen_taken_date
    ).last_for_patient().specimen_taken_date
    
# COVID-19 Vaccination
dataset.covid19_vaccine_pc = vaccinations.where(vaccinations.date.is_on_or_before(dataset.admission_date)).exists_for_patient()

# Chronic cardiac disease
add_primary_care_variable("ccd_pc", "chronic_cardiac_disease", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Hypertension
add_primary_care_variable("hypertension_pc", "hypertension", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Chronic pulmonary disease
add_primary_care_variable("copd_pc", "copd", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Asthma
add_primary_care_variable("asthma_pc", "asthma", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Chronic kidney disease
add_primary_care_variable("ckd_pc", "chronic_kidney_disease", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Liver disease
add_primary_care_variable("cld_pc", "chronic_liver_disease", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Chronic neurological disorder
add_primary_care_variable("neuro_pc", "neuro_other", "ctv3", codelists_ehrql, clinical_events, dataset, days)

# Cancer
add_primary_care_variable("cancer_lung_pc", "cancer_lung", "snomed", codelists_ehrql, clinical_events, dataset, days)
add_primary_care_variable("cancer_other_pc", "cancer_other", "snomed", codelists_ehrql, clinical_events, dataset, days)
add_primary_care_variable("cancer_haemo_pc", "cancer_haemo", "snomed", codelists_ehrql, clinical_events, dataset, days)

# AIDS/HIV
add_primary_care_variable("hiv_pc", "hiv", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Obesity
dataset.obesity_pc  = (
    # Filter on codes which which capture recorded BMI
    clinical_events.where(clinical_events.snomedct_code.is_in(codelists_ehrql.obesity_codelist))
    # Only values in the 5 years prior to admission date
    .where(clinical_events.date.is_on_or_between(dataset.admission_date - years(5), dataset.admission_date))
    # Exclude out-of-range values
    .where((clinical_events.numeric_value > 4.0) & (clinical_events.numeric_value < 200.0))
    # Exclude measurements taken when patient was younger than 16
    .where(clinical_events.date >= patients.date_of_birth + years(16))
    .numeric_value.maximum_for_patient()
)

# Diabetes
add_primary_care_variable("diabetes_pc", "diabetes", "snomed", codelists_ehrql, clinical_events, dataset, days)
add_primary_care_variable("diabetes_t1_pc", "diabetes_t1", "snomed", codelists_ehrql, clinical_events, dataset, days)
add_primary_care_variable("diabetes_t2_pc", "diabetes_t2", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Rheumatologic disorder
#add_primary_care_variable("rheumatologic_pc", "rheumatologic", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Dementia
add_primary_care_variable("dementia_pc", "dementia", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Malnutrition
#add_primary_care_variable("malnutrition_pc", "malnutrition", "snomed", codelists_ehrql, clinical_events, dataset, days)

# Smoking
#add_primary_care_variable("smoking_pc", "smoking", "snomed", codelists_ehrql, clinical_events, dataset, days)





    


