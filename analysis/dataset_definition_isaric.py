from ehrql import Dataset
from ehrql import days
from ehrql.tables import clinical_events, isaric_raw, hospital_admissions

import codelists_ehrql

dataset = Dataset()

# Select all patients with an entry in the ISARIC table.
dataset.define_population(isaric_raw.exists_for_patient())

# for column_name in isaric_raw.qm_node.schema.column_names:
#     # The conventional way to set columns on the dataset in ehrQL would be to write them out:
#     # dataset.column = isaric_raw.sort_by(isaric_raw.column).first_for_patient().column
#     # Instead, we access the column names as attributes,
#     # so we don't have to explicitly specify them,
#     # making this dataset definition much more concise.
#     # see here for all options: https://github.com/opensafely-core/databuilder/blob/dec86f9001911665e863b4ac886327f856ab4a6c/databuilder/tables/beta/tpp.py#L204
#     # this will need to be updated to add / access new columns
#     column_on_table = getattr(isaric_raw, column_name)
#     # Choose the same row for each column.
#     column_data = getattr(
#         isaric_raw.sort_by(isaric_raw.age).first_for_patient(), column_name
#     )
#     setattr(dataset, column_name, column_data)

# 
# for column_name in [
#     "hostdat",
#     "age",
#     "calc_age",
#     "sex",
#     "corona_ieorres",
#     "coriona_ieorres2",
#     "coriona_ieorres3",
#     "inflammatory_mss",
#     "covid19_vaccine",
#     "chrincard", 
#     "hypertension_mhyn",
#     "chronicpul_mhyn",
#     "asthma_mhyn",
#     "renal_mhyn",
#     "mildliver",
#     "modliv",
#     "chronicneu_mhyn",
#     "malignantneo_mhyn",
#     "chronichaemo_mhyn",
#     "aidshiv_mhyn",
#     "obesity_mhyn",
#     "diabetes_mhyn",
#     "diabetescom_mhyn",
#     "rheumatologic_mhyn",
#     "dementia_mhyn",
#     "malnutrition_mhyn",
# ]:
#     # Instead of approach above, choose subset of variables currently of interest, treating all as a string
#     column_on_table = getattr(isaric_raw, column_name)
#     # Choose the same row for each column.
#     column_data = getattr(
#         isaric_raw.sort_by(isaric_raw.age).first_for_patient(), column_name
#     )
#     setattr(dataset, column_name, column_data)
#     
    
def add_isaric_variable(extract_name, database_name):
  # select a column from isaric and rename it
    column_on_table = getattr(isaric_raw, database_name)
    # Choose the same row for each column.
    column_data = getattr(
        isaric_raw.sort_by(isaric_raw.age).first_for_patient(), database_name
    )
    setattr(dataset, extract_name, column_data)
    
add_isaric_variable("admission_date","hostdat")
add_isaric_variable("age", "age")
add_isaric_variable("calc_age","calc_age")
add_isaric_variable("sex","sex")
add_isaric_variable("corona_ieorres","corona_ieorres")
add_isaric_variable("coriona_ieorres2","coriona_ieorres2")
add_isaric_variable("coriona_ieorres3","coriona_ieorres3")
add_isaric_variable("inflammatory_mss","inflammatory_mss")
add_isaric_variable("covid19_vaccine","covid19_vaccine")

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
