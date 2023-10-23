################################################################################
#
# Description: This script produces metadata, figurs and tables to go into the
#              mabs_and_antivirvals_coverage_report.rmd
#
# Input: output/admissions/processed_isaric.rds
#        output/admissions/processed_sus_methodA.rds
#        output/admissions/processed_sus_methodB.rds
#        output/admissions/processed_sus_methodC.rds
#
# Output: output/validation/table_flowchart_numbers_redacted_rounded.csv
#         output/validation/table_admissions_per_week_redacted_rounded.csv
#         output/validation/unmatched_sus_isaric_numbers_redacted_rounded.csv
#         output/validation/table_demo_clinc_breakdown_redacted_rounded
#         output/validation/
#         output/validation/
#         output/validation/
#         output/validation/
#
# Author(s): M Green
# Date last updated: 23/10/2023
#
################################################################################


# PRELIMINARIES ----------------------------------------------------------------

## Import libraries
library(tidyverse)
library(here)
library(glue)
library(gt)
library(gtsummary)
library(reshape2)
library(stringr)

## Import custom user functions
source(here("analysis", "lib", "custom_functions.R"))
source(here("analysis", "lib", "utility.R"))

## Output directory
output_dir <- here("output", "validation")
output_dir2 <- here("output", "validation", "for-checks")

fs::dir_create(output_dir)
fs::dir_create(output_dir2)

## Redaction threshold
threshold <- 7

## Rounding threshold for statistical disclosure control ----
rounding_threshold <- 10
midpoint_rounding_threshold <- 8

## Dates
start_date = as.Date("2020-02-01")
end_date = as.Date("2023-01-01")

## Import data
processed_isaric <- read_rds(here::here("output", "admissions", "processed_isaric.rds"))
processed_sus_methodA <- read_rds(here::here("output", "admissions", "processed_sus_methodA.rds"))
processed_sus_methodB <- read_rds(here::here("output", "admissions", "processed_sus_methodB.rds"))
processed_sus_methodC <- read_rds(here::here("output", "admissions", "processed_sus_methodC.rds"))

# Combine admissions
admissions_joined_SUS <- processed_sus_methodA %>%
  rbind(processed_sus_methodB %>%
          filter(!patient_id %in% processed_sus_methodA$patient_id &
                   !first_admission_date_sus %in%processed_sus_methodA$first_admission_date_sus)) %>%
  plyr::rbind.fill(processed_sus_methodC %>%
                     filter(!patient_id %in% processed_sus_methodA$patient_id &
                              !first_admission_date_sus %in%processed_sus_methodA$first_admission_date_sus) %>%
                     filter(!patient_id %in% processed_sus_methodB$patient_id &
                              !first_admission_date_sus %in%processed_sus_methodB$first_admission_date_sus))

# Filter dates
ISARIC_admission_1 <- processed_isaric %>% filter(first_admission_date_isaric >= start_date,
                                                  first_admission_date_isaric <= end_date)

SUS_admission_1_method_A <- processed_sus_methodA %>% filter(first_admission_date_sus >= start_date,
                                                             first_admission_date_sus <= end_date)
SUS_admission_1_method_B <- processed_sus_methodB %>% filter(first_admission_date_sus >= start_date,
                                                             first_admission_date_sus <= end_date)
SUS_admission_1_method_C <- processed_sus_methodC %>% filter(first_admission_date_sus >= start_date,
                                                             first_admission_date_sus <= end_date)
admissions_SUS <- admissions_joined_SUS %>% filter(first_admission_date_sus >= start_date,
                                                   first_admission_date_sus <= end_date)



# DATA FOR REPORT --------------------------------------------------------------


# Number of admissions per week ----
admissions_per_week_ISARIC <- ISARIC_admission_1 %>%
  mutate(admission_week = round_date(first_admission_date_isaric, unit="week", week_start=1)) %>%
  group_by(admission_week) %>%
  summarise(n = n()) %>%
  ungroup() %>%
  complete(admission_week = full_seq(.$admission_week, 7), # in case zero admissions on some days
           fill = list(n=0)) %>%
  arrange(admission_week) %>%
  ungroup() %>%
  mutate(dataset = "ISARIC")

admissions_per_week_SUS <- admissions_SUS %>%
  mutate(admission_week = round_date(first_admission_date_sus, unit="week", week_start=1)) %>%
  group_by(admission_week) %>%
  summarise(n = n()) %>%
  ungroup() %>%
  complete(admission_week = full_seq(.$admission_week, 7), # in case zero admissions on some days
           fill = list(n=0)) %>%
  arrange(admission_week) %>%
  ungroup() %>%
  mutate(dataset = "SUS")

admissions_per_week <- rbind(admissions_per_week_ISARIC, admissions_per_week_SUS)

admissions_per_week_redacted_rounded <- admissions_per_week %>%
  mutate(n_redacted = ifelse(n <= threshold, NA, n),
         n_redacted_rounded =  plyr::round_any(as.numeric(n_redacted), rounding_threshold)) %>%
  select(admission_week, n_redacted_rounded, dataset)

write_csv(admissions_per_week_redacted_rounded, fs::path(output_dir, "table_admissions_per_week_redacted_rounded.csv"))


# Numbers for text/flowchart ----

## Min/max dates
min_ISARIC <- min(ISARIC_admission_1$first_admission_date_isaric)
max_ISARIC <- max(ISARIC_admission_1$first_admission_date_isaric)

## Patients with an COVID-19 hospital admission
n_patients_ISARIC <- nrow(processed_isaric)
n_patients_SUS_method_A <- nrow(processed_sus_methodA)
n_patients_SUS_method_B <- nrow(processed_sus_methodB)
n_patients_SUS_method_C <- nrow(processed_sus_methodC)
n_patients_SUS_joined <- nrow(admissions_joined_SUS)

## Patients with an COVID-19 hospital admission between 2020-02-01 and 2023-01-01
n_ISARIC_admission_1 <- nrow(ISARIC_admission_1)
n_SUS_admission_1_method_A <- nrow(SUS_admission_1_method_A)
n_SUS_admission_1_method_B <- nrow(SUS_admission_1_method_B)
n_SUS_admission_1_method_C <- nrow(SUS_admission_1_method_C)
n_SUS_joined_admission_1 <- nrow(admissions_SUS)

## Patients with an COVID-19 hospital admission in ISARIC but not SUS
admission_ISARIC_NOT_SUS <- ISARIC_admission_1 %>%
  filter(!(patient_id %in% admissions_SUS$patient_id))
n_admission_ISARIC_NOT_SUS <- admission_ISARIC_NOT_SUS %>% nrow()

## Patients with an COVID-19 hospital admission in SUS but not ISARIC
admission_SUS_NOT_ISARIC <- admissions_SUS %>%
  filter(!(patient_id %in% ISARIC_admission_1$patient_id))
n_admission_SUS_NOT_ISARIC <- admission_SUS_NOT_ISARIC %>% nrow()

## Patients with an COVID-19 hospital admission in ISARIC and SUS
admission_ISARIC_SUS <- inner_join(ISARIC_admission_1, admissions_SUS, by = c("patient_id" = "patient_id"))
n_admission_ISARIC_SUS <- nrow(admission_ISARIC_SUS)

## Patients with an COVID-19 hospital admission in ISARIC and SUS within 5 days
n_admission_ISARIC_SUS_5days <- admission_ISARIC_SUS %>%
  filter(first_admission_date_isaric <= first_admission_date_sus + 5 |
           first_admission_date_isaric >= first_admission_date_sus - 5) %>%
  nrow()

## Patients with an COVID-19 hospital admission in ISARIC and SUS within 2 days
n_admission_ISARIC_SUS_2days <- admission_ISARIC_SUS %>%
  filter(first_admission_date_isaric <= first_admission_date_sus + 2 |
           first_admission_date_isaric >= first_admission_date_sus - 2) %>%
  nrow()

## Patients with an COVID-19 hospital admission in ISARIC and SUS on the same date
n_admission_ISARIC_SUS_same_date <- admission_ISARIC_SUS %>%
  filter(first_admission_date_isaric == first_admission_date_sus) %>%
  nrow()

n_admission_ISARIC_SUS_same_date_method_A <- admission_ISARIC_SUS %>%
  filter(first_admission_date_isaric == first_admission_date_sus) %>%
  filter(patient_id %in% SUS_admission_1_method_A$patient_id) %>%
  nrow()

n_admission_ISARIC_SUS_same_date_method_B <- admission_ISARIC_SUS %>%
  filter(first_admission_date_isaric == first_admission_date_sus) %>%
  filter(patient_id %in% SUS_admission_1_method_B$patient_id &
           !(patient_id %in% SUS_admission_1_method_A$patient_id)) %>%
  nrow()

n_admission_ISARIC_SUS_same_date_method_C <- admission_ISARIC_SUS %>%
  filter(first_admission_date_isaric == first_admission_date_sus) %>%
  filter(patient_id %in% SUS_admission_1_method_C$patient_id &
           !(patient_id %in% SUS_admission_1_method_A$patient_id) &
           !(patient_id %in% SUS_admission_1_method_B$patient_id)) %>%
  nrow()

## Extract the variable names and values
#variable_names <- ls(pattern = "^n_")
variable_names <- c("min_ISARIC", "max_ISARIC", "n_patients_ISARIC", "n_patients_SUS_method_A", "n_patients_SUS_method_B", "n_patients_SUS_method_C", "n_patients_SUS_joined",
                    "n_ISARIC_admission_1", "n_SUS_admission_1_method_A", "n_SUS_admission_1_method_B", "n_SUS_admission_1_method_C", "n_SUS_joined_admission_1",
                    "n_admission_ISARIC_NOT_SUS", "n_admission_SUS_NOT_ISARIC", "n_admission_ISARIC_SUS",
                    "n_admission_ISARIC_SUS_5days", "n_admission_ISARIC_SUS_2days", "n_admission_ISARIC_SUS_same_date",
                    "n_admission_ISARIC_SUS_same_date_method_A", "n_admission_ISARIC_SUS_same_date_method_B", "n_admission_ISARIC_SUS_same_date_method_C")

variable_values <- sapply(variable_names, function(var) get(var))

## Create a data frame with the variable names and values
flowchart_numbers <- data.frame(
  variable = variable_names,
  value = variable_values,
  row.names = NULL
)

flowchart_numbers_redacted_rounded <- flowchart_numbers %>%
  mutate(value_redacted = ifelse(value <= threshold, NA, value),
         value_redacted_rounded =  plyr::round_any(value_redacted, rounding_threshold)) %>%
  select(variable, value_redacted_rounded)

## Save data
write_csv(flowchart_numbers_redacted_rounded, fs::path(output_dir, "table_flowchart_numbers_redacted_rounded.csv"))



# Unmatched ISARIC/SUS patients ----

## Possible reasons for no admission match
n_admission_ISARIC_NOT_SUS_non_covid_admission_SUS_same_date <- admission_ISARIC_NOT_SUS %>% filter(non_covid_admission_SUS_same_date == TRUE) %>% nrow()
n_admission_ISARIC_NOT_SUS_non_covid_admission_SUS_2days <- admission_ISARIC_NOT_SUS %>% filter(non_covid_admission_SUS_2days == TRUE) %>% nrow()
n_admission_ISARIC_NOT_SUS_registered_pc <- admission_ISARIC_NOT_SUS %>% filter(registered_pc == FALSE) %>% nrow()
n_admission_ISARIC_NOT_SUS_positive_covid_test_last_14_days <- admission_ISARIC_NOT_SUS %>% filter(first_admission_date_isaric <= last_positive_test_date_pc  & first_admission_date_isaric >= last_positive_test_date_pc - 14) %>% nrow()

## Extract the variable names and values
variable_names <- c("n_admission_ISARIC_NOT_SUS_non_covid_admission_SUS_same_date",
                    "n_admission_ISARIC_NOT_SUS_non_covid_admission_SUS_2days",
                    "n_admission_ISARIC_NOT_SUS_registered_pc",
                    "n_admission_ISARIC_NOT_SUS_positive_covid_test_last_14_days")

variable_values <- sapply(variable_names, function(var) get(var))

## Create a data frame with the variable names and values
unmatched_sus_isaric_numbers <- data.frame(
  variable = variable_names,
  value = variable_values,
  row.names = NULL
)

unmatched_sus_isaric_numbers_redacted_rounded <- unmatched_sus_isaric_numbers %>%
  mutate(value_redacted = ifelse(value <= threshold, NA, value),
         value_redacted_rounded =  plyr::round_any(as.numeric(value_redacted), rounding_threshold)) %>%
  select(variable, value_redacted_rounded)

## Save data
write_csv(unmatched_sus_isaric_numbers_redacted_rounded, fs::path(output_dir, "table_unmatched_sus_isaric_numbers_redacted_rounded.csv"))


# Demographic characteristics of ISARIC and SUS patients ----

## ISARIC table
tbl_ISARIC <- ISARIC_admission_1 %>%
  mutate(days_in_critical_care = ifelse(days_in_critical_care >0, 1, NA)) %>%
  select(patient_id, ageband = ageband_pc, sex = sex_pc, ethnicity = ethnicity_pc, imd = imd_pc, region = region_pc,
         asthma = asthma_pc, cancer = cancer_pc, chronic_heart_disease = ccd_pc, chronic_kidney_disease = ckd_pc,
         chronic_liver_disease = cld_pc, copd = copd_pc, dementia = dementia_pc, diabetes_type_1 = diabetes_t1_pc,
         diabetes_type_2 = diabetes_t2_pc, hiv = hiv_pc, hypertension = hypertension_pc,
         neurological_disorder = neuro_pc, obesity = obesity_pc, smoking = smoking_pc, days_in_critical_care,
         death_with_28_days_of_covid_positive_test) %>%
  mutate(dataset = "ISARIC")

## SUS table
tbl_SUS <- admissions_SUS %>%
  mutate(days_in_critical_care = ifelse(days_in_critical_care >0, 1, NA)) %>%
  select(patient_id, ageband = ageband_sus, sex = sex_sus, ethnicity = ethnicity_sus, imd = imd_sus, region = region_sus,
         asthma = asthma_sus, cancer = cancer_sus, chronic_heart_disease = ccd_sus, chronic_kidney_disease = ckd_sus,
         chronic_liver_disease = cld_sus, copd = copd_sus, dementia = dementia_sus, diabetes_type_1 = diabetes_t1_sus,
         diabetes_type_2 = diabetes_t2_sus, hiv = hiv_sus, hypertension = hypertension_sus,
         neurological_disorder = neuro_sus, obesity = obesity_sus, smoking = smoking_sus, days_in_critical_care,
         death_with_28_days_of_covid_positive_test) %>%
  mutate(dataset = "SUS")

## Join tables
table_demo_clinc_breakdown_base <- rbind(tbl_ISARIC, tbl_SUS) %>%
  select(-patient_id) %>%
  tbl_summary(by = dataset)

## Extract relvent data
table_demo_clinc_breakdown_base$inputs$data <- NULL

table_demo_clinc_breakdown_base <- table_demo_clinc_breakdown_base$table_body %>%
  separate(stat_1, c("stat_1","perc0"), sep = " ([(])") %>%
  separate(stat_2, c("stat_2","perc0"), sep = " ([(])") %>%
  select(variable, level = label,
         ISARIC = stat_1,
         SUS = stat_2) %>%
  data.frame()

## Apply SDCs
table_demo_clinc_breakdown_redacted_rounded <- table_demo_clinc_breakdown_base %>%
  # Redact values < 8
  mutate(ISARIC_redacted = ifelse(ISARIC < threshold, NA, as.numeric(ISARIC)),
         SUS_redacted = ifelse(SUS < threshold, NA, as.numeric(SUS))) %>%
  # Round to nearest 10
  mutate(ISARIC_redacted_rounded = plyr::round_any(ISARIC_redacted, 10),
         SUS_redacted_rounded = plyr::round_any(SUS_redacted, 10)) %>%
  select(variable, level, ISARIC_redacted_rounded, SUS_redacted_rounded)

## Save file
write_csv(table_demo_clinc_breakdown_redacted_rounded, fs::path(output_dir, "table_demo_clinc_breakdown_redacted_rounded.csv"))

