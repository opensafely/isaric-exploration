
from cohortextractor import (
  StudyDefinition,
  patients,
  codelist_from_csv,
  codelist,
  filter_codes_by_category,
  combine_codelists,
  params
)

# import json module
import json

# Import codelists from codelists.py
import codelists


# process parameters
admission_number = int(params["admission_number"])
admission_method = params["admission_method"]

start_date = "2020-01-01"
end_date = "2022-11-30"

def previous_admission_date_dict(n, method, minimum_date):
  if n == 1:
    variable_dict = {
      "previous_admiss_date": patients.fixed_value(minimum_date),
    }
  else:
    variable_dict = {
      "previous_admiss_date": patients.with_value_from_file(
        f_path=f"output/admissions/sus_method{method}_admission{n-1}.csv.gz",
        returning="admiss_date", 
        returning_type="date", 
        date_format='YYYY-MM-DD'
      ),
    }
  return variable_dict


def admission_date_dict(method):
  if method == "A":
    # Unplanned admissions with a ICD10 COVID code as a diagnosis
    variable_dict = {
      "admiss_date": patients.admitted_to_hospital(
        returning="date_admitted",
        with_admission_method=["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"],
        with_these_diagnoses=codelists.covid_icd10,
        on_or_after="previous_admiss_date + 1 days",
        date_format="YYYY-MM-DD",
        find_first_match_in_period=True,
      ),
    }
    
  if method == "B":
    # Any admissions with a ICD10 COVID code as a diagnosis
    variable_dict = {
      "admiss_date": patients.admitted_to_hospital(
        returning="date_admitted",
        with_these_diagnoses=codelists.covid_icd10,
        on_or_after="previous_admiss_date + 1 days",
        date_format="YYYY-MM-DD",
        find_first_match_in_period=True,
      ),
    }
    
  if method == "C":
    # A&E attendance resulting in admission to hospital, with a COVID code (from the A&E SNOMED discharge diagnosis refset) as the A&E discharge diagnosis
    # This is expected to be a big underestimate of actual COVID admissions, but A&E data arrives much quick than hospital data for rapid real time analyses it can be an important proxy
    variable_dict = {
      "admiss_date": patients.attended_emergency_care(
        returning="date_arrived",
        date_format="YYYY-MM-DD",
        on_or_after="previous_admiss_date + 1 days",
        find_first_match_in_period=True,
        with_these_diagnoses = codelists.covid_emergency,
        discharged_to = codelists.discharged_to_hospital,
      ),
    }  
    
    
  if method == "D":
    # emergency A&E attendances, with a respiratory diagnosis, occurring within 14 days after or 3 days before a positive SARS-CoV-2 test
    # NOTE: this definition won't work! it will pick up some events meeting the definition, but not all
    # So this method is currently unused. 
    # in fact, this event is not possible to define in cohort extractor
    # supporting this is a goal in ehrQL, but it's not currently possible
    # see slack thread here https://bennettoxford.slack.com/archives/C33TWNQ1J/p1676635830922819
    # and follow on thread here https://bennettoxford.slack.com/archives/C03FB777L1M/p1676890072678899
    variable_dict = {
      "admiss_date": patients.categorised_as(
        "attended_resp_date AND positivetestE",

        attended_resp_date=patients.attended_emergency_care(
          returning="date_arrived",
          date_format="YYYY-MM-DD",
          on_or_after="previous_admiss_date + 1 days",
          find_first_match_in_period=True,
          with_these_diagnoses = codelists.resp_emergency,
          discharged_to = codelists.discharged_to_hospital,
        ),
        
        positivetestD=patients.with_test_result_in_sgss(
          pathogen="SARS-CoV-2",
          test_result="positive",
          returning="binary_flag",
          between=["attended_resp_date - 14 days", "attended_resp_date + 3 days"],
          restrict_to_earliest_specimen_date=False,
        ),
      )
    }
  
  if method == "E":
    # hospital admissions with a respiratory diagnosis, occurring within 14 days after or 3 days before a positive SARS-CoV-2 test
    # NOTE: this definition won't work! it will pick up some events meeting the definition, but not all
    # So this method is currently unused. 
    # in fact, this event is not possible to define in cohort extractor
    # supporting this is a goal in ehrQL, but it's not currently possible
    # see slack thread here https://bennettoxford.slack.com/archives/C33TWNQ1J/p1676635830922819
    # and follow on thread here https://bennettoxford.slack.com/archives/C03FB777L1M/p1676890072678899

    variable_dict = {
      "admiss_date": patients.satisfying(
        "attended_date AND positivetestE",
        
        attended_date = patients.admitted_to_hospital(
          returning="date_admitted",
          with_admission_method=["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"],
          with_these_diagnoses=codelists.resp_icd10,
          on_or_after="previous_admiss_date + 1 days",
          date_format="YYYY-MM-DD",
          find_first_match_in_period=True,
        ),
        
        positivetestE=patients.with_test_result_in_sgss(
          pathogen="SARS-CoV-2",
          test_result="positive",
          returning="binary_flag",
          between=["attended_date - 14 days", "attended_date + 3 days"],
          restrict_to_earliest_specimen_date=False,
        ),
      )
    }
    
  return variable_dict



# Specify study defeinition
study = StudyDefinition(
  
  # Configure the expectations framework
  default_expectations={
    "date": {"earliest": "2020-01-01", "latest": "2023-01-01"},
    "rate": "uniform",
    "incidence": 0.2,
    "int": {"distribution": "normal", "mean": 1000, "stddev": 100},
    "float": {"distribution": "normal", "mean": 25, "stddev": 5},
  },
  
  # This line defines the study population
  population=patients.satisfying(
    "admiss_date",
  ),
  
  
  ## admission date
  
  # prior admissions
  **previous_admission_date_dict(admission_number, admission_method, start_date),
  
  # current admissions
  **admission_date_dict(admission_method),
  
  
  ###############################################################################
  ## Admin and demographics as at admission date
  ###############################################################################
  
  prior_dereg_date=patients.date_deregistered_from_all_supported_practices(
    on_or_before="admiss_date - 1 day",
    date_format="YYYY-MM-DD",
  ),

  dereg_date=patients.date_deregistered_from_all_supported_practices(
    on_or_after="admiss_date",
    date_format="YYYY-MM-DD",
  ),
  
  registered=patients.registered_as_of(
    "admiss_date",
  ),

  age=patients.age_as_of( 
    "admiss_date",
  ),
  
  sex=patients.sex(
    return_expectations={
      "rate": "universal",
      "category": {"ratios": {"M": 0.49, "F": 0.51}},
      "incidence": 1,
    }
  ),
  
  practice_id=patients.registered_practice_as_of(
    "admiss_date",
    returning="pseudo_id",
    return_expectations={
      "int": {"distribution": "normal", "mean": 1000, "stddev": 100},
      "incidence": 1,
    },
  ),
  
  stp=patients.registered_practice_as_of(
    "admiss_date",
    returning="stp_code",
    return_expectations={
      "rate": "universal",
      "category": {
        "ratios": {
          "STP1": 0.1,
          "STP2": 0.1,
          "STP3": 0.1,
          "STP4": 0.1,
          "STP5": 0.1,
          "STP6": 0.1,
          "STP7": 0.1,
          "STP8": 0.1,
          "STP9": 0.1,
          "STP10": 0.1,
        }
      },
    },
  ),
  
  region=patients.registered_practice_as_of(
    "admiss_date",
    returning="nuts1_region_name",
    return_expectations={
      "rate": "universal",
      "category": {
        "ratios": {
          "North East": 0.1,
          "North West": 0.1,
          "Yorkshire and The Humber": 0.2,
          "East Midlands": 0.1,
          "West Midlands": 0.1,
          "East": 0.1,
          "London": 0.1,
          "South East": 0.1,
          "South West": 0.1
          #"" : 0.01
        },
      },
    },
  ),
  
  
  
  ################################################################################################
  ## clinical characteristics
  ################################################################################################
  ##  TODO 
  
  # the following comorbidities (existing prior to admission):
  # Chronic cardiac disease (including congenital heart disease, not hypertension); 
  # Obesity (as defined by clinical staff);
  # Hypertension (physician diagnosed); 
  # Diabetes; 
  # Chronic pulmonary disease (not asthma); 
  # Asthma (physician diagnosed); 
  # Chronic kidney disease; Rheumatologic disorder; 
  # liver disease; 
  # Dementia; 
  # Malnutrition; 
  # Chronic neurological disorder; 
  # Malignant neoplasm; 
  # Chronic hematologic disease;  
  # AIDS/HIV; 
  # Solid organ transplant; 
  # immunosuppression therapies.
  
  # diabetes = patients.with_these_clinical_events(
  #   codelists.diabetes,
  #   returning="binary_flag",
  #   on_or_before="admiss_date - 1 day",
  # ),
  # 
  # chronic_cardiac_disease = patients.with_these_clinical_events(
  #   codelists.chronic_cardiac_disease,
  #   returning="binary_flag",
  #   on_or_before="admiss_date - 1 day",
  # ),
  # 
  ################################################################################################
  # peri admission characteristics / events
  ################################################################################################

  ## TODO
  
  # in-hospital severity (eg critical care stay, length of stay)
  # in-hospital death? - hospitalisation with discharge + death date on same day (or discharge location = death)
  
  ################################################################################################
  # post admission events
  ################################################################################################

# 
#   # Positive case identification prior to study start date
#   prior_primary_care_covid_case_date=patients.with_these_clinical_events(
#     combine_codelists(
#       codelists.covid_primary_care_code,
#       codelists.covid_primary_care_positive_test,
#       codelists.covid_primary_care_sequelae,
#     ),
#     returning="date",
#     date_format="YYYY-MM-DD",
#     on_or_before="admiss_date - 1 day",
#     find_last_match_in_period=True,
#   ),
#   
#   # covid PCR test dates from SGSS
#   prior_covid_test_date=patients.with_test_result_in_sgss(
#     pathogen="SARS-CoV-2",
#     test_result="any",
#     on_or_before="admiss_date - 1 day",
#     returning="date",
#     date_format="YYYY-MM-DD",
#     find_last_match_in_period=True,
#     restrict_to_earliest_specimen_date=False,
#   ),
#   
#   # prior positive covid test
#   prior_positive_test_date=patients.with_test_result_in_sgss(
#     pathogen="SARS-CoV-2",
#     test_result="positive",
#     returning="date",
#     date_format="YYYY-MM-DD",
#     on_or_before="admiss_date - 1 day",
#     find_last_match_in_period=True,
#     restrict_to_earliest_specimen_date=False,
#   ),
#   
#   # positive covid test
#   positive_test_date=patients.with_test_result_in_sgss(
#     pathogen="SARS-CoV-2",
#     test_result="positive",
#     returning="date",
#     date_format="YYYY-MM-DD",
#     on_or_after="admiss_date",
#     find_first_match_in_period=True,
#     restrict_to_earliest_specimen_date=False,
#   ),
  
  
  ############################################################
  ## Post-admission variables
  ############################################################


# All-cause death
  death_date=patients.died_from_any_cause(
    returning="date_of_death",
    date_format="YYYY-MM-DD",
  ),

)
