################################################################################
#
# Description: - Some of the variables used in this study are created from 
#                codelists of clinical conditions or numerical values available 
#                on a patient's records.
#              - This script defines all of the codelists used.
#
################################################################################



# IMPORT STATEMENTS ------------------------
from databuilder.ehrql import codelist_from_csv



# CODELISTS FOR PRIMARY CARE RECORD VARIABLES ------------------------

ethnicity_codelist = codelist_from_csv(
    "codelists/opensafely-ethnicity-snomed-0removed.csv",
    column="snomedcode",
    category_column="Grouping_6",
)

covid_icd10 = ["U071", "U072", "U109", "U099"]

covid_emergency = codelist_from_csv(
    "codelists/opensafely-covid-19-ae-diagnosis-codes.csv",
    column="code",
)

resp_emergency = codelist_from_csv(
    "codelists/user-Louis-respiratory-related-ae.csv",
    column="code",
)

covid_primary_care_positive_test = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-probable-covid-positive-test.csv",
    column="CTV3ID",
)

covid_primary_care_code = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-probable-covid-clinical-code.csv",
    column="CTV3ID",
)

covid_primary_care_sequelae = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-probable-covid-sequelae.csv",
    column="CTV3ID",
)

covid_primary_care_probable_combined = (
    covid_primary_care_positive_test
    + covid_primary_care_code
    + covid_primary_care_sequelae
)

covid_primary_care_suspected_covid_advice = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-suspected-covid-advice.csv",
    column="CTV3ID",
)

covid_primary_care_suspected_covid_had_test = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-suspected-covid-had-test.csv",
    column="CTV3ID",
)

covid_primary_care_suspected_covid_isolation = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-suspected-covid-isolation-code.csv",
    column="CTV3ID",
)

covid_primary_care_suspected_covid_nonspecific_clinical_assessment = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-suspected-covid-nonspecific-clinical-assessment.csv",
    column="CTV3ID",
)

covid_primary_care_suspected_covid_exposure = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-exposure-to-disease.csv",
    column="CTV3ID",
)

primary_care_suspected_covid_combined = (
    covid_primary_care_suspected_covid_advice
    + covid_primary_care_suspected_covid_had_test
    + covid_primary_care_suspected_covid_isolation
    + covid_primary_care_suspected_covid_exposure
)

discharged_to_hospital = ["306706006", "1066331000000109", "1066391000000105"]



# CODELISTS FOR PRIMARY CARE RECORD COMORBIDITIES ------------------

chronic_cardiac_disease = codelist_from_csv(
    "codelists/opensafely-chronic-cardiac-disease-snomed.csv",
    column="id",
)

hypertension = codelist_from_csv(
    "codelists/opensafely-hypertension-snomed.csv",
    column="id",
)

copd = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-copd_cod.csv",
    column="code",
)

asthma = codelist_from_csv(
    "codelists/opensafely-asthma-diagnosis-snomed.csv",
    column="id",
)

chronic_kidney_disease = codelist_from_csv(
    "codelists/opensafely-chronic-kidney-disease-snomed.csv",
    column="id",
)

chronic_liver_disease = codelist_from_csv(
    "codelists/opensafely-chronic-liver-disease-snomed.csv",
    column="id",
)

neuro_other = codelist_from_csv(
    "codelists/opensafely-other-neurological-conditions-snomed.csv",
    column="id",
)


cancer_haemo = codelist_from_csv(
    "codelists/opensafely-haematological-cancer-snomed.csv",
    column="id",
)

cancer_lung = codelist_from_csv(
    "codelists/opensafely-lung-cancer-snomed.csv",
    column="id",
)

cancer_other = codelist_from_csv(
    "codelists/opensafely-cancer-excluding-lung-and-haematological-snomed.csv",
    column="id",
)

hiv = codelist_from_csv(
    "codelists/opensafely-hiv-snomed.csv",
    column="id",
)

diabetes = codelist_from_csv(
    "codelists/opensafely-diabetes-snomed.csv",
    column="id",
)

diabetes_t1 = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-dmtype1_cod.csv",
    column="code",
)

diabetes_t2 = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-dmtype2_cod.csv",
    column="code",
)

dementia = codelist_from_csv(
    "codelists/opensafely-dementia-snomed.csv",
    column="id",
)

obesity_codelist = ["60621009", "846931000000101"]

clear_smoking_codes = codelist_from_csv(
    "codelists/opensafely-smoking-clear.csv",
    column = "CTV3Code",
    category_column = "Category",
)
