from cohortextractor import (codelist, codelist_from_csv, combine_codelists)


covid_icd10 = codelist(["U071", "U072", "U109", "U099"], system="icd10")

covid_emergency = codelist(
    "codelists/user-anschaf-covid-19-ae-diagnosis-codes.csv",
    system="snomed",
)

resp_emergency = codelist_from_csv(
    "codelists/user-Louis-respiratory-related-ae.csv",
    system="snomed",
    column="code",
)



covid_primary_care_positive_test = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-probable-covid-positive-test.csv",
    system="ctv3",
    column="CTV3ID",
)

covid_primary_care_code = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-probable-covid-clinical-code.csv",
    system="ctv3",
    column="CTV3ID",
)

covid_primary_care_sequelae = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-probable-covid-sequelae.csv",
    system="ctv3",
    column="CTV3ID",
)

covid_primary_care_probable_combined = combine_codelists(
    covid_primary_care_positive_test,
    covid_primary_care_code,
    covid_primary_care_sequelae,
)
covid_primary_care_suspected_covid_advice = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-suspected-covid-advice.csv",
    system="ctv3",
    column="CTV3ID",
)
covid_primary_care_suspected_covid_had_test = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-suspected-covid-had-test.csv",
    system="ctv3",
    column="CTV3ID",
)
covid_primary_care_suspected_covid_isolation = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-suspected-covid-isolation-code.csv",
    system="ctv3",
    column="CTV3ID",
)
covid_primary_care_suspected_covid_nonspecific_clinical_assessment = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-suspected-covid-nonspecific-clinical-assessment.csv",
    system="ctv3",
    column="CTV3ID",
)
covid_primary_care_suspected_covid_exposure = codelist_from_csv(
    "codelists/opensafely-covid-identification-in-primary-care-exposure-to-disease.csv",
    system="ctv3",
    column="CTV3ID",
)
primary_care_suspected_covid_combined = combine_codelists(
    covid_primary_care_suspected_covid_advice,
    covid_primary_care_suspected_covid_had_test,
    covid_primary_care_suspected_covid_isolation,
    covid_primary_care_suspected_covid_exposure,
)

discharged_to_hospital = codelist(
    ["306706006", "1066331000000109", "1066391000000105"],
    system="snomed",
)

# comorbidities 

diabetes = codelist_from_csv(
    "codelists/opensafely-diabetes.csv",
    system="ctv3",
    column="CTV3ID",
)

chronic_cardiac_disease = codelist_from_csv(
    "codelists/opensafely-chronic-cardiac-disease.csv",
    system="ctv3",
    column="CTV3ID",
)

