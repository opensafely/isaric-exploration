################################################################################
#
# Description: This script provides the formal specification of the study data
#              that will be extracted from the OpenSAFELY database. It is a 
#              translation of study_definition_sus.py from cohort extractor to
#              ehrQL.
#
# Output: output/admissions/sus_method[]_admission[].csv.gz
#
# Author(s): M Green
# Date last updated: 07/08/2023
#
################################################################################





# IMPORT STATEMENTS ------------------------

# Import tables and Python objects
from ehrql import Dataset, days, years, case, when
from ehrql.tables.beta.tpp import (
  hospital_admissions, 
  emergency_care_attendances, 
  patients, 
  sgss_covid_all_tests, 
  vaccinations,
  addresses, 
  practice_registrations,
  clinical_events,
  ons_deaths
  )
from argparse import ArgumentParser

# Import codelists
import codelists_ehrql

# Process parameters
parser = ArgumentParser()
parser.add_argument("--admission_method")
args = parser.parse_args()
admission_method = args.admission_method

# Functions
from variables import (
  emergency_care_diagnosis_matches, 
  admissions_data, 
  get_sequential_admissions_date, 
  date_deregistered_from_all_supported_practices,
  has_prior_comorbidity
  )





# DEFINE DATASET ------------------------

# Create dataset object for output dataset
dataset = Dataset()

# Define dataset as all patients with a COVID-19 related hospital_admissions/emergency_care_attendances 
# depending on method.
admissions_data_sus = admissions_data(
  admission_method, hospital_admissions, emergency_care_attendances)
dataset.define_population(admissions_data_sus.exists_for_patient())





# ADD BASIC INFO ABOUT PATIENTS ADMISSION (as recorded at time of admission) ------------------------

# First COVID-19 admission date
if admission_method == "C":
  dataset.first_admission_date_sus = admissions_data_sus.first_for_patient().arrival_date
else:
  dataset.first_admission_date_sus = admissions_data_sus.first_for_patient().admission_date

# Subsequent COVID-19 admission dates
get_sequential_admissions_date(dataset, "admission{n}_date_sus", admissions_data_sus, 5, admission_method)

# Registration details
dataset.prior_dereg_date_sus = practice_registrations.where(
      practice_registrations.end_date.is_before(dataset.first_admission_date_sus)).end_date.maximum_for_patient()

dataset.dereg_date_sus = date_deregistered_from_all_supported_practices(practice_registrations, case, when)

dataset.registered_sus = practice_registrations.for_patient_on(dataset.first_admission_date_sus).exists_for_patient()

# Age
dataset.age_sus = patients.age_on(dataset.first_admission_date_sus)

# Sex
dataset.sex_sus = patients.sex

# Ethnicity
ethnicity6 = clinical_events.where(clinical_events.snomedct_code.is_in(codelists_ehrql.ethnicity_codelist)
    ).where(
        clinical_events.date.is_on_or_before(dataset.first_admission_date_sus)
    ).sort_by(
        clinical_events.date
    ).last_for_patient().snomedct_code.to_category(codelists_ehrql.ethnicity_codelist)

dataset.ethnicity_sus = case(
    when(ethnicity6 == "1").then("White"),
    when(ethnicity6 == "2").then("Mixed"),
    when(ethnicity6 == "3").then("South Asian"),
    when(ethnicity6 == "4").then("Black"),
    when(ethnicity6 == "5").then("Other"),
    when(ethnicity6 == "6").then("Not stated"),
    default = "Unknown"
)

# IMD
imd = addresses.for_patient_on(dataset.first_admission_date_sus).imd_rounded

dataset.imd_sus = case(
    when((imd >=0) & (imd < int(32844 * 1 / 5))).then("1 (most deprived)"),
    when(imd < int(32844 * 2 / 5)).then("2"),
    when(imd < int(32844 * 3 / 5)).then("3"),
    when(imd < int(32844 * 4 / 5)).then("4"),
    when(imd < int(32844 * 5 / 5)).then("5 (least deprived)"),
    default="unknown"
)

# Region
dataset.region_sus = practice_registrations.for_patient_on(dataset.first_admission_date_sus).practice_nuts1_region_name

# COVID-19 infection
dataset.suspected_covid_date_sus = clinical_events.where(
  clinical_events.ctv3_code.is_in(codelists_ehrql.primary_care_suspected_covid_combined)
  ).where(
    clinical_events.date.is_on_or_before(dataset.first_admission_date_sus)
    ).sort_by(
      clinical_events.date
      ).last_for_patient().date

dataset.probable_covid_date_sus = clinical_events.where(
  clinical_events.ctv3_code.is_in(codelists_ehrql.covid_primary_care_probable_combined)
  ).where(
    clinical_events.date.is_on_or_before(dataset.first_admission_date_sus)
    ).sort_by(
      clinical_events.date
      ).last_for_patient().date

dataset.last_positive_test_date_sus = sgss_covid_all_tests.where(sgss_covid_all_tests.is_positive
    ).where(
        sgss_covid_all_tests.specimen_taken_date.is_on_or_before(dataset.first_admission_date_sus)
    ).sort_by(
        sgss_covid_all_tests.specimen_taken_date
    ).last_for_patient().specimen_taken_date
    
# COVID-19 Vaccination
dataset.covid19_vaccine_sus = vaccinations.where(vaccinations.date.is_on_or_before(dataset.first_admission_date_sus)).exists_for_patient()





# ADD COMORBIDITY INFO (as recorded at the time of first admission) ------------------------

# Chronic cardiac disease
has_prior_comorbidity("ccd_sus", "chronic_cardiac_disease", "snomed", "first_admission_date_sus", dataset)

# Hypertension
has_prior_comorbidity("hypertension_sus", "hypertension", "snomed", "first_admission_date_sus", dataset)

# Chronic pulmonary disease
has_prior_comorbidity("copd_sus", "copd", "snomed", "first_admission_date_sus", dataset)

# Asthma
has_prior_comorbidity("asthma_sus", "asthma", "snomed", "first_admission_date_sus", dataset)

# Chronic kidney disease
has_prior_comorbidity("ckd_sus", "chronic_kidney_disease", "snomed", "first_admission_date_sus", dataset)

# Liver disease
has_prior_comorbidity("cld_sus", "chronic_liver_disease", "snomed", "first_admission_date_sus", dataset)

# Chronic neurological disorder
has_prior_comorbidity("neuro_sus", "neuro_other", "snomed", "first_admission_date_sus", dataset)

# Cancer
has_prior_comorbidity("cancer_lung_sus", "cancer_lung", "snomed", "first_admission_date_sus", dataset)
has_prior_comorbidity("cancer_other_sus", "cancer_other", "snomed", "first_admission_date_sus", dataset)
has_prior_comorbidity("cancer_haemo_sus", "cancer_haemo", "snomed", "first_admission_date_sus", dataset)

# AIDS/HIV
has_prior_comorbidity("hiv_sus", "hiv", "snomed", "first_admission_date_sus", dataset)

# Obesity
dataset.obesity_sus  = (
    # Filter on codes which which capture recorded BMI
    clinical_events.where(clinical_events.snomedct_code.is_in(codelists_ehrql.obesity_codelist))
    # Only values in the 5 years prior to admission date
    .where(clinical_events.date.is_on_or_between(dataset.first_admission_date_sus - years(5), dataset.first_admission_date_sus))
    # Exclude out-of-range values
    .where((clinical_events.numeric_value > 4.0) & (clinical_events.numeric_value < 200.0))
    # Exclude measurements taken when patient was younger than 16
    .where(clinical_events.date >= patients.date_of_birth + years(16))
    .numeric_value.maximum_for_patient()
)

# Diabetes
has_prior_comorbidity("diabetes_sus", "diabetes", "snomed", "first_admission_date_sus", dataset)
has_prior_comorbidity("diabetes_t1_sus", "diabetes_t1", "snomed", "first_admission_date_sus", dataset)
has_prior_comorbidity("diabetes_t2_sus", "diabetes_t2", "snomed", "first_admission_date_sus", dataset)

# Rheumatologic disorder
#has_prior_comorbidity("rheumatologic_sus", "rheumatologic", "snomed", "first_admission_date_sus", dataset)

# Dementia
has_prior_comorbidity("dementia_sus", "dementia", "snomed", "first_admission_date_sus", dataset)

# Malnutrition
#has_prior_comorbidity("malnutrition_sus", "malnutrition", "snomed", "first_admission_date_sus", dataset)

# Smoking
has_prior_comorbidity("smoking_sus", "clear_smoking_codes", "ctv3", "first_admission_date_sus", dataset)





# ADD OTHER INFO  ------------------------

# Number of admissions
if admission_method == "A" or admission_method == "B":
  dataset.n_admissions =  admissions_data_sus.count_for_patient() 

# In-hospital severity (critical care stay, length of stay)
if admission_method == "A" or admission_method == "B":
  dataset.days_in_critical_care = admissions_data_sus.first_for_patient().days_in_critical_care

# All-cause death
ons_deathdata = ons_deaths.sort_by(ons_deaths.date).last_for_patient()
dataset.ons_death_date = ons_deathdata.date
dataset.death_date = patients.date_of_death
dataset.has_died = ons_deaths.where(ons_deaths.date >= dataset.first_admission_date_sus).exists_for_patient()

# In-hospital death (hospitalisation with discharge + death date on same day or discharge location = death)
dataset.in_hospital_death = ons_deaths.where(ons_deaths.place == "Hospital").exists_for_patient()
if admission_method == "A" or admission_method == "B":
  dataset.discharge_date = admissions_data_sus.first_for_patient().discharge_date


