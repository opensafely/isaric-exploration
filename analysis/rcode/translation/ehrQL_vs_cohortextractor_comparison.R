################################################################################
#
# Description: This script compares SUS data extracted using ehrQL to SUS data
#              extracted using cohortextractor
#
# Input: /output/admissions/sus_methodA_admission1_ehrQL.csv.gz
#        /output/admissions/sus_methodB_admission1_ehrQL.csv.gz
#        /output/admissions/sus_methodC_admission1_ehrQL.csv.gz
#        /output/admissions/sus_methodA_admission1_cohortextractor.csv.gz
#        /output/admissions/sus_methodB_admission1_cohortextractor.csv.gz
#        /output/admissions/sus_methodC_admission1_cohortextractor.csv.gz
#
# Output: /output/translation/ehrQL_vs_cohortextractor_comparison.csv
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

# Output directory
fs::dir_create(here("output", "translation"))

## Import data
sus_methodA_ehrQL <- read_csv(here::here("output", "admissions", "sus_methodA_admission1_ehrQL.csv.gz"))
sus_methodB_ehrQL <- read_csv(here::here("output", "admissions", "sus_methodB_admission1_ehrQL.csv.gz"))
sus_methodC_ehrQL <- read_csv(here::here("output", "admissions", "sus_methodC_admission1_ehrQL.csv.gz"))

sus_methodA_cohortextractor <- read_csv(here::here("output", "admissions", "sus_methodA_admission1_cohortextractor.csv.gz"))
sus_methodB_cohortextractor <- read_csv(here::here("output", "admissions", "sus_methodB_admission1_cohortextractor.csv.gz"))
sus_methodC_cohortextractor <- read_csv(here::here("output", "admissions", "sus_methodC_admission1_cohortextractor.csv.gz"))


# Table to compare numbers extarcted by each method ----
comparison_table <- data.frame(method = c("A", "B", "C"),
                         ehrQL = c(nrow(sus_methodA_ehrQL),
                                   nrow(sus_methodB_ehrQL),
                                   nrow(sus_methodC_ehrQL)),
                         cohortextractor = c(nrow(sus_methodA_cohortextractor),
                                             nrow(sus_methodB_cohortextractor),
                                             nrow(sus_methodC_cohortextractor))
                         )

# Save to file ----
write_csv(comparison_table, here("output", "translation", "ehrQL_vs_cohortextractor_comparison.csv"))
