################################################################################
#
# Description: This script imports data extracted by ehrQL (or dummy data),
#              standardises some variables (eg convert to factor) and
#              derives some additional variables needed for subsequent analyses
#
# Input: /output/admissions/isaric_admission1.csv.gz
#
# Output: /output/admissions/processed_isaric.rds
#         /output/admissions/processed_sus_A.rds
#         /output/admissions/processed_sus_B.rds
#         /output/admissions/processed_sus_C.rds
#
# Author(s): M Green
# Date last updated: 09/03/2022
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

## Print basic dataset description to file
os_skim(isaric_raw, path=here("output", "admissions", "isaric_raw_skim.txt"))

## Standardise some variables
isaric_processed <- isaric_raw %>%
  dplyr::mutate(

    # Ethnicity
    ethnicity = dplyr::case_when(
      ethnic___1 == "Checked" ~ "Arab",
      ethnic___2 == "Checked" ~ "Black",
      ethnic___3 == "Checked" ~ "East Asian",
      ethnic___4 == "Checked" ~ "South Asian",
      ethnic___5 == "Checked" ~ "West Asian",
      ethnic___6 == "Checked" ~ "Latin American",
      ethnic___7 == "Checked" ~ "White",
      ethnic___8 == "Checked" ~ "Aboriginal/First Nations",
      ethnic___9 == "Checked" ~ "Other"
    ),

    ethnicity_grouped = dplyr::case_when(
      ethnicity %in% c("East Asian", "South Asian", "West Asian") ~ "Asian",
      ethnicity %in%
        c("Other", "Arab", "Latin American", "Aboriginal/First Nations") ~ "Other",
      TRUE ~ ethnicity
    ),

    # Age
    ageband = cut(
      age,
      breaks=c(-Inf, 18, 40, 55, 65, 75, Inf),
      labels=c("under 18", "18-39", "40-54", "55-64", "65-74", "75+"),
      right=FALSE
    ),

    # Cancer
    cancer_pc = (cancer_lung_pc | cancer_haemo_pc | cancer_other_pc )*1L
  )

## Save to file
write_rds(isaric_processed, here("output", "admissions", "processed_isaric.rds"), compress="gz")
