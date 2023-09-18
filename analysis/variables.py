################################################################################
#
# Description: This script contains custom functions for:
#             - 
#             - Extracting comorbidities from primary care data based on codelist
#             - Extracting emergency care data based on codelist
#             - Extracting patients with COVID-19 admissions depending on method specified
#             - Matching hospital admission dignosis with codelist
#             - Creating n sequential admission date variables
#             - Extracting practice deregistration date
#             - 
#             - 
#             - 
#             - 
#
# Author(s): M Green, W Hulme, S Maude
# Date last updated: 04/08/2023
#
################################################################################



# IMPORT STATEMENTS ------------------------

# Import tables and Python objects
from ehrql import Dataset, days, years, case, when
from ehrql.codes import ICD10Code
from ehrql.tables.beta.tpp import (
  hospital_admissions, 
  emergency_care_attendances, 
  practice_registrations, 
  patients, 
  sgss_covid_all_tests, 
  vaccinations,
  addresses, 
  clinical_events
  )
import operator
from functools import reduce

# Import codelists
import codelists_ehrql





# FUNCTIONS ------------------------

# Extract comorbidity from primary care data based on codelist ------------------------
def has_prior_comorbidity(
  extract_name, codelist_name, system, column_name, dataset):
    
    codelist_attribute = getattr(codelists_ehrql, codelist_name)
    if system == "snomed":
      characteristic = (
          clinical_events.where(clinical_events.snomedct_code.is_in(codelist_attribute))
          .where(clinical_events.date.is_on_or_before(getattr(dataset, column_name) - days(1)))
          .exists_for_patient()
      )
      setattr(dataset, extract_name, characteristic)
    
    if system == "ctv3":
      characteristic = (
          clinical_events.where(clinical_events.ctv3_code.is_in(codelist_attribute))
          .where(clinical_events.date.is_on_or_before(getattr(dataset, column_name) - days(1)))
          .exists_for_patient()
      )
      setattr(dataset, extract_name, characteristic)



# Extract emergency care data based on codelist ------------------------
def emergency_care_diagnosis_matches(emergency_care_attendances, codelist):
  conditions = [
    getattr(emergency_care_attendances, column_name).is_in(codelist)
    for column_name in [f"diagnosis_{i:02d}" for i in range(1, 25)]
  ]
  return emergency_care_attendances.where(reduce(operator.or_, conditions)) 



# Match hospital admission dignosis with codelists ------------------------
def hospitalisation_diagnosis_matches(admissions, codelist):
    code_strings = set()
    for code in codelist:
        # Pass the string through the ICD10Code to constructor to validate that it has
        # the expected format
        code_string = ICD10Code(code)._to_primitive_type()
        code_strings.add(code_string)
    conditions = [
        # The reason a plain substring search like this works is twofold:
        #
        # * ICD-10 codes all start with the sequence [A-Z][0-9] and do not contain
        #   such a sequence in any other part of the code. In this sense they are
        #   suffix-free and two codes will only match at they start if they match at
        #   all.
        #
        # * Although the codes are not prefix-free they are organised hierarchically
        #   such that code A0123 represents a child concept of code A01. So although
        #   the naive substring matching below will find code A01 if code A0123 is
        #   present, this happens to be the behaviour we actually want.
        #
        # Obviously this is all far from ideal though, and later we hope to be able
        # to pull these codes out in a separate table and handle the matching
        # properly.
        admissions.all_diagnoses.contains(code_string)
        for code_string in code_strings
    ]
    return admissions.where(reduce(operator.or_, conditions))



# Extract patients with COVID-19 admissions depending on method specified ------------------------
def admissions_data(admission_method, hospital_admissions, emergency_care_attendances):
    
    # Unplanned admissions with a ICD10 COVID code as a diagnosis
    if admission_method == "A":
      admissions_data_sus = (
          hospitalisation_diagnosis_matches(hospital_admissions, codelists_ehrql.covid_icd10)
          .where(hospital_admissions.admission_method.is_in(["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"]))
          #.where(hospital_admissions.admission_date.is_on_or_after(start_date))
          .sort_by(hospital_admissions.admission_date)
      )
    
    ## Any hospital admission with a ICD10 COVID code as a diagnosis
    if admission_method == "B":
      admissions_data_sus = (
          hospitalisation_diagnosis_matches(hospital_admissions, codelists_ehrql.covid_icd10)
          #.where(hospital_admissions.admission_date.is_on_or_after(start_date))
          .sort_by(hospital_admissions.admission_date)
      )
    
    ## A&E attendance resulting in admission to hospital, with a COVID code 
    ## (from the A&E SNOMED discharge diagnosis refset) as the A&E discharge diagnosis
    ## Note, this is expected to be a big underestimate of actual COVID admissions, but A&E data arrives 
    ## much quick than hospital data for rapid real time analyses it can be an important proxy 
    if admission_method == "C":
      admissions_data_sus = (
          emergency_care_diagnosis_matches(emergency_care_attendances, codelists_ehrql.covid_emergency)
          #.where(emergency_care_attendances.arrival_date.is_on_or_after(start_date))
          .where(emergency_care_attendances.discharge_destination.is_in(codelists_ehrql.discharged_to_hospital))
          .sort_by(emergency_care_attendances.arrival_date)
      )
      
    return admissions_data_sus



# Create n sequential admission date variables ------------------------

def get_sequential_admissions_date(
    dataset, variable_name_template, admissions_data, num_admissions, admission_method, sort_column=None):    
    
    if admission_method == "C":
      column = "arrival_date"
    else:
      column = "admission_date"
    
    sort_column = sort_column or column
    
    previous_date = None
    
    for index in range(num_admissions):
        next_admission = admissions_data.sort_by(getattr(admissions_data, sort_column)).first_for_patient()
        admissions_data = admissions_data.where(
            getattr(admissions_data, sort_column) > getattr(next_admission, sort_column)
        )
        variable_name = variable_name_template.format(n=index + 1)
        setattr(dataset, variable_name, getattr(next_admission, column))
    


# Extract practice deregistration date ------------------------

def date_deregistered_from_all_supported_practices(practice_registrations, case, when):
    max_dereg_date = practice_registrations.end_date.maximum_for_patient()
    # In TPP currently active registrations are recorded as having an end date of
    # 9999-12-31. We convert these, and any other far-future dates, to NULL.
    return case(
        when(max_dereg_date.is_before("3000-01-01")).then(max_dereg_date),
        default=None,
    )


