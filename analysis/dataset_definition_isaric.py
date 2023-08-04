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


# IMPORT STATEMENTS ----

# Import tables and Python objects
from ehrql import Dataset, days
from ehrql.tables.beta.tpp import clinical_events, isaric_raw, hospital_admissions

# Import codelists
import codelists_ehrql

# Functions
def add_isaric_variable(extract_name, database_name):
  # The conventional way to set columns on the dataset in ehrQL would be to write them out, for instance:
  #   dataset.variable_name = isaric_raw.sort_by(isaric_raw.admission_date).first_for_patient().database_variable_name
  # but since all we want to do is select a bunch of variables using this exact pattern, we can wrap it in a function
  # unfortunately, I don't know how to do that for arbitrary `variable_name` and `database_variable_name`, except by getting and setting attributes, as in the function below
  # so that's what we'll use for now
  
  # note that we sort on age because this is more reliable than sorting on admission_date, which has a bunch of dodgy values 
  
  # select a column from isaric and rename it
  column_on_table = getattr(isaric_raw, database_name)
  # Choose the same row for each column.
  column_data = getattr(
      isaric_raw.sort_by(isaric_raw.age).first_for_patient(), database_name
  )
  setattr(dataset, extract_name, column_data)
  
  def add_primary_care_variable(extract_name, codelist_name, system):
    codelist_attribute = getattr(codelists_ehrql, codelist_name)
    if system == "snomed":
      characteristic = (
          clinical_events.where(clinical_events.snomedct_code.is_in(codelist_attribute))
          .where(clinical_events.date.is_on_or_before(dataset.admission_date - days(1)))
          .exists_for_patient()
      )
      setattr(dataset, extract_name, characteristic)
    if system == "ctv3":
      characteristic = (
          clinical_events.where(clinical_events.ctv3_code.is_in(codelist_attribute))
          .where(clinical_events.date.is_on_or_before(dataset.admission_date - days(1)))
          .exists_for_patient()
      )
      setattr(dataset, extract_name, characteristic)


# DEFINE DATASET ----

# Create dataset object for output dataset
dataset = Dataset()

# Define dataset a all patients with an entry in the ISARIC table.
dataset.define_population(isaric_raw.exists_for_patient())






# ADD BASIC INFO ABOUT PATIENTS FIRST ADMISSION (as recorded at time of admission) ----

# Admission date
add_isaric_variable("admission_date","hostdat")

#Age
add_isaric_variable("age", "age")
add_isaric_variable("calc_age","calc_age")

#Sex
add_isaric_variable("sex","sex")

# Ethnicity

# COVID-19 infection
add_isaric_variable("corona_ieorres","corona_ieorres")
add_isaric_variable("coriona_ieorres2","coriona_ieorres2")
add_isaric_variable("coriona_ieorres3","coriona_ieorres3")

# Adult or child who meets case definition for inflammatory multi-system syndrome (MIS-C/MIS-A).
add_isaric_variable("inflammatory_mss","inflammatory_mss")

# COVID-19 vaccination
add_isaric_variable("covid19_vaccine","covid19_vaccine")


# ADD COMORBIDITY INFO (as recorded in ISARIC at the time of first admission) ----

# Chronic cardiac disease
add_isaric_variable("ccd_isaric","chrincard") 

# Hypertension
add_isaric_variable("hypertension_isaric","hypertension_mhyn")

# Chronic pulmonary disease
add_isaric_variable("chronicpul_isaric","chronicpul_mhyn")

# Asthma
add_isaric_variable("asthma_isaric","asthma_mhyn")

# Chronic kidney disease
add_isaric_variable("ckd_isaric","renal_mhyn")

# Liver disease
add_isaric_variable("mildliver_isaric","mildliver")
add_isaric_variable("modliver_isaric","modliv")

# Chronic neurological disorder
add_isaric_variable("neuro_isaric","chronicneu_mhyn")

#Cancer
add_isaric_variable("cancer_isaric","malignantneo_mhyn")
add_isaric_variable("haemo_isaric","chronichaemo_mhyn")

# AIDS/HIV
add_isaric_variable("hiv_isaric","aidshiv_mhyn")

# Obesity
add_isaric_variable("obesity_isaric","obesity_mhyn")

# Diabetes
add_isaric_variable("diabetes_isaric","diabetes_mhyn")
add_isaric_variable("diabetescom_isaric","diabetescom_mhyn")

# Rheumatologic disorder
add_isaric_variable("rheumatologic_isaric","rheumatologic_mhyn")

# Dementia
add_isaric_variable("dementia_isaric","dementia_mhyn")

# Malnutrition
add_isaric_variable("malnutrition_isaric","malnutrition_mhyn")

# Smoking


# EXTRACT EQUIVALENT DATA FROM PRIMARY CARE RECORDS ----
# Note, these may not exactly match the clinical definitions used on the ISARIC case report forms

# Age
dataset.age_pc = patients.age_on(dataset.admission_date)

# Sex
dataset.sex_pc = patients.sex

# Ethnicity

# COVID-19 infection

# COVID-19 Vaccination


# Chronic cardiac disease
add_primary_care_variable("ccd_pc", "chronic_cardiac_disease", "snomed")

# Hypertension
add_primary_care_variable("hypertension_pc", "hypertension", "snomed")

# Chronic pulmonary disease
add_primary_care_variable("copd_pc", "copd", "snomed")

# Asthma
add_primary_care_variable("asthma_pc", "asthma", "snomed")

# Chronic kidney disease
add_primary_care_variable("ckd_pc", "chronic_kidney_disease", "snomed")

# Liver disease
add_primary_care_variable("cld_pc", "chronic_liver_disease", "snomed")

# Chronic neurological disorder
add_primary_care_variable("neuro_pc", "neuro_other", "ctv3")

# Cancer
add_primary_care_variable("cancer_lung_pc", "cancer_lung", "snomed")
add_primary_care_variable("cancer_other_pc", "cancer_other", "snomed")
add_primary_care_variable("cancer_haemo_pc", "cancer_haemo", "snomed")

# AIDS/HIV
add_primary_care_variable("hiv_pc", "hiv", "snomed")

# Obesity

# Diabetes
add_primary_care_variable("diabetes_pc", "diabetes", "snomed")
add_primary_care_variable("diabetes_t1_pc", "diabetes_t1", "snomed")
add_primary_care_variable("diabetes_t2_pc", "diabetes_t2", "snomed")

# Rheumatologic disorder
#add_primary_care_variable("rheumatologic_pc", "rheumatologic", "snomed")

# Dementia
#add_primary_care_variable("dementia_pc", "dementia", "snomed")

# Malnutrition
#add_primary_care_variable("malnutrition_pc", "malnutrition", "snomed")

# Smoking
#add_primary_care_variable("smoking_pc", "smoking", "snomed")



