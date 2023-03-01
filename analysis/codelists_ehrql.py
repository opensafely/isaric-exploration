from databuilder.ehrql import codelist_from_csv


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

# comorbidities

diabetes = codelist_from_csv(
    "codelists/opensafely-diabetes.csv",
    column="CTV3ID",
)

chronic_cardiac_disease = codelist_from_csv(
    "codelists/opensafely-chronic-cardiac-disease.csv",
    column="CTV3ID",
)
