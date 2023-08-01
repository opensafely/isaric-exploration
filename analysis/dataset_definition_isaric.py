from ehrql import Dataset
from ehrql import days
from ehrql.tables.beta.tpp import clinical_events, isaric_raw, hospital_admissions

import codelists_ehrql

dataset = Dataset()

# Select all patients with an entry in the ISARIC table.
dataset.define_population(isaric_raw.exists_for_patient())



## extract all ISARIC variables of interest from the `isaric_raw` table, selecting only the first admission for each patient


    
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

# get basic information about the admission as recorded at time of admission
add_isaric_variable("admission_date","hostdat")
add_isaric_variable("age", "age")
add_isaric_variable("calc_age","calc_age")
add_isaric_variable("sex","sex")
add_isaric_variable("corona_ieorres","corona_ieorres")
add_isaric_variable("coriona_ieorres2","coriona_ieorres2")
add_isaric_variable("coriona_ieorres3","coriona_ieorres3")
add_isaric_variable("inflammatory_mss","inflammatory_mss")
add_isaric_variable("covid19_vaccine","covid19_vaccine")

# get comorbidity info as recorded at the time of admission
add_isaric_variable("ccd_isaric","chrincard") 
add_isaric_variable("hypertension_isaric","hypertension_mhyn")
add_isaric_variable("chronicpul_isaric","chronicpul_mhyn")
add_isaric_variable("asthma_isaric","asthma_mhyn")
add_isaric_variable("ckd_isaric","renal_mhyn")
add_isaric_variable("mildliver_isaric","mildliver")
add_isaric_variable("modliver_isaric","modliv")
add_isaric_variable("neuro_isaric","chronicneu_mhyn")
add_isaric_variable("cancer_isaric","malignantneo_mhyn")
add_isaric_variable("haemo_isaric","chronichaemo_mhyn")
add_isaric_variable("hiv_isaric","aidshiv_mhyn")
add_isaric_variable("obesity_isaric","obesity_mhyn")
add_isaric_variable("diabetes_isaric","diabetes_mhyn")
add_isaric_variable("diabetescom_isaric","diabetescom_mhyn")
add_isaric_variable("rheumatologic_isaric","rheumatologic_mhyn")
add_isaric_variable("dementia_isaric","dementia_mhyn")
add_isaric_variable("malnutrition_isaric","malnutrition_mhyn")



# Now retrieve equivalent comorbidity data from primary care records
# I've used existing codelists from previous studies.
# These may not exactly match the clinical definitions used on the ISARIC case report forms
# Codelists should therefore be checked and revised if necessary

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

add_primary_care_variable("ccd_pc", "chronic_cardiac_disease", "snomed")
add_primary_care_variable("hypertension_pc", "hypertension", "snomed")
add_primary_care_variable("copd_pc", "copd", "snomed")
add_primary_care_variable("asthma_pc", "asthma", "snomed")
add_primary_care_variable("ckd_pc", "chronic_kidney_disease", "snomed")
add_primary_care_variable("neuro_pc", "neuro_other", "ctv3")
add_primary_care_variable("cancer_haemo_pc", "cancer_haemo", "snomed")
add_primary_care_variable("cancer_lung_pc", "cancer_lung", "snomed")
add_primary_care_variable("cancer_other_pc", "cancer_other", "snomed")
add_primary_care_variable("hiv_pc", "hiv", "snomed")
#add_primary_care_variable("obesity_pc", "obesity", "snomed")
add_primary_care_variable("diabetes_pc", "diabetes", "snomed")
add_primary_care_variable("diabetes_t1_pc", "diabetes_t1", "snomed")
add_primary_care_variable("diabetes_t2_pc", "diabetes_t2", "snomed")
