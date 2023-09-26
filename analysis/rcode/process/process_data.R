################################################################################
#
# Description: This script imports data extracted by ehrQL (or dummy data),
#              standardises some variables (eg convert to factor) and
#              derives some additional variables needed for subsequent analyses
#
# Input: /output/admissions/isaric_admission1.csv.gz
#        /output/admissions/sus_methodA_admission1_ehrQL.csv.gz
#        /output/admissions/sus_methodB_admission1_ehrQL.csv.gz
#        /output/admissions/sus_methodC_admission1_ehrQL.csv.gz
#
# Output: /output/admissions/processed_isaric.rds
#         /output/admissions/processed_sus_A.rds
#         /output/admissions/processed_sus_B.rds
#         /output/admissions/processed_sus_C.rds
#
# Author(s): M Green
# Date last updated: 08/09/2023
#
################################################################################


# Preliminaries ----

# Import libraries
library('tidyverse')
library('lubridate')
library('arrow')
library('here')
library('glue')
library('dplyr')

# Import custom user functions from lib
source(here("analysis", "lib", "utility.R"))
source(here("analysis", "lib", "custom_functions.R"))

# Output directory
fs::dir_create(here("output", "admissions"))


# Process data ----

## Import data
isaric_raw <- read_csv(here::here("output", "admissions", "isaric_admission1.csv.gz"))
sus_methodA_raw <- read_csv(here::here("output", "admissions", "sus_methodA_admission1_ehrQL.csv.gz"))
sus_methodB_raw <- read_csv(here::here("output", "admissions", "sus_methodB_admission1_ehrQL.csv.gz"))
sus_methodC_raw <- read_csv(here::here("output", "admissions", "sus_methodC_admission1_ehrQL.csv.gz"))

## Print basic dataset description to file
os_skim(isaric_raw, path=here("output", "admissions", "isaric_raw_skim.txt"))
os_skim(sus_methodA_raw, path=here("output", "admissions", "sus_methodA_raw_skim.txt"))
os_skim(sus_methodB_raw, path=here("output", "admissions", "sus_methodB_raw_skim.txt"))
os_skim(sus_methodC_raw, path=here("output", "admissions", "sus_methodC_raw_skim.txt"))

## Standardise some ISARIC variables
isaric_processed <- isaric_raw %>%
  dplyr::mutate(

    # Age
    ageband = cut(
      as.numeric(age_isaric),
      breaks=c(-Inf, 18, 40, 55, 65, 75, Inf),
      labels=c("under 18", "18-39", "40-54", "55-64", "65-74", "75+"),
      right=FALSE
    ),

    ageband_pc = cut(
      as.numeric(age_pc),
      breaks=c(-Inf, 18, 40, 55, 65, 75, Inf),
      labels=c("under 18", "18-39", "40-54", "55-64", "65-74", "75+"),
      right=FALSE),

    # Ethnicity
    ethnicity = dplyr::case_when(
      eth1_isaric == "Checked" ~ "Arab",
      eth2_isaric == "Checked" ~ "Black",
      eth3_isaric == "Checked" ~ "East Asian",
      eth4_isaric == "Checked" ~ "South Asian",
      eth5_isaric == "Checked" ~ "West Asian",
      eth6_isaric == "Checked" ~ "Latin American",
      eth7_isaric == "Checked" ~ "White",
      eth8_isaric == "Checked" ~ "Aboriginal/First Nations",
      eth9_isaric == "Checked" ~ "Other"
    ),

    ethnicity_grouped = dplyr::case_when(
      ethnicity %in% c("East Asian", "South Asian", "West Asian") ~ "Asian",
      ethnicity %in%
        c("Other", "Arab", "Latin American", "Aboriginal/First Nations") ~ "Other",
      TRUE ~ ethnicity
    ),

    ethnicity_pc = factor(as.character(ethnicity_pc),
                          levels = c("White", "Mixed", "South Asian",
                                     "Black", "Other", "Not stated", "Unknown")),
    # Cancer
    cancer_pc = (cancer_lung_pc | cancer_haemo_pc | cancer_other_pc )*1L,

    # Death
    death_with_28_days_of_covid_positive_test = ifelse((ons_death_date <= last_positive_test_date_pc + 28 &
                                                          ons_death_date >= last_positive_test_date_pc), 1, NA),

    death_with_28_days_of_covid_hosp_admission = ifelse((ons_death_date <= first_admission_date_isaric + 28 &
                                                           ons_death_date >= first_admission_date_isaric), 1, NA),

    # Positive COVID test
    positive_covid_test_prior_28_days = ifelse((last_positive_test_date_pc >= first_admission_date_isaric - 28 &
                                                  last_positive_test_date_pc <= first_admission_date_isaric), 1, NA),
  )

## Standardise some SUS variables
process_sus <- function(data){
  data %>%
    mutate(

      # Age
      ageband_sus = cut(
        age_sus,
        breaks=c(-Inf, 18, 40, 55, 65, 75, Inf),
        labels=c("under 18", "18-39", "40-54", "55-64", "65-74", "75+"),
        right=FALSE
      ),

      # Ethnicity
      ethnicity_sus = factor(as.character(ethnicity_sus),
                            levels = c("White", "Mixed", "South Asian",
                                       "Black", "Other", "Not stated", "Unknown")),

      # Cancer
      cancer_sus = (cancer_lung_sus | cancer_haemo_sus | cancer_other_sus )*1L,

      # Death
      death_with_28_days_of_covid_positive_test = ifelse((ons_death_date <= last_positive_test_date_sus + 28 &
                                                            ons_death_date >= last_positive_test_date_sus), 1, NA),

      death_with_28_days_of_covid_hosp_admission = ifelse((ons_death_date <= first_admission_date_sus + 28 &
                                                             ons_death_date >= first_admission_date_sus), 1, NA),

      # Positive COVID test
      positive_covid_test_prior_28_days = ifelse((last_positive_test_date_sus >= first_admission_date_sus - 28 &
                                                    last_positive_test_date_sus <= first_admission_date_sus), 1, NA),
    )
}

processed_sus_methodA <- process_sus(sus_methodA_raw)
processed_sus_methodB <- process_sus(sus_methodB_raw)
processed_sus_methodC <- process_sus(sus_methodC_raw)

## Save to file
write_rds(isaric_processed, here("output", "admissions", "processed_isaric.rds"), compress="gz")
write_rds(processed_sus_methodA, here("output", "admissions", "processed_sus_methodA.rds"), compress="gz")
write_rds(processed_sus_methodB, here("output", "admissions", "processed_sus_methodB.rds"), compress="gz")
write_rds(processed_sus_methodC, here("output", "admissions", "processed_sus_methodC.rds"), compress="gz")

