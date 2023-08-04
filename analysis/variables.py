################################################################################
#
# Description: This script contains custom functions for:
#             - 
#             - Extracting comorbidities from primary care data based on codelist
#             - 
#             - 
#             - 
#             - 
#             - 
#             - 
#             - 
#             - 
#
# Author(s): M Green, W Hulme, S Maude
# Date last updated: 04/08/2023
#
################################################################################


# Extract comorbidity from primary care data based on codelist ------------------------
def add_primary_care_variable(extract_name, codelist_name, system, codelists_ehrql, clinical_events, dataset, days):
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


## Functions for extracting a series of time dependent variables ------------------------
# These define study defintion variable signatures such that
# variable_1_date is the the first event date on or after the index date
# variable_2_date is the first event date strictly after variable_2_date
# ...
# variable_n_date is the first event date strictly after variable_n-1_date

def vaccination_date_X(name, index_date, n, product_name_matches=None, target_disease_matches=None):
  # vaccination date, given product_name
  def var_signature(
    name,
    on_or_after,
    product_name_matches,
    target_disease_matches
  ):
    return {
      name: patients.with_tpp_vaccination_record(
        product_name_matches=product_name_matches,
        target_disease_matches=target_disease_matches,
        on_or_after=on_or_after,
        find_first_match_in_period=True,
        returning="date",
        date_format="YYYY-MM-DD"
      ),
    }
    
  variables = var_signature(f"{name}_1_date", index_date, product_name_matches, target_disease_matches)
  for i in range(2, n+1):
    variables.update(var_signature(
      f"{name}_{i}_date", 
      f"{name}_{i-1}_date + 1 days",
      # pick up subsequent vaccines occurring one day or later -- people with unrealistic dosing intervals are later excluded
      product_name_matches,
      target_disease_matches
    ))
  return variables




def admission_method1_date(
  prior_admission_date,
  index
):
  
  return {
    "admission_{index}_date": patients.admitted_to_hospital(
      returning="date_admitted",
      with_admission_method=["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"],
      with_these_diagnoses=codelists.covid_icd10,
      on_or_after="{prior_admission_date} + 1 days",
      date_format="YYYY-MM-DD",
      find_first_match_in_period=True,
    )
  }  
    
