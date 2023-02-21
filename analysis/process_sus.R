######################################

# This script:
# imports data extracted by the cohort extractor (or dummy data)
# standardises some variables (eg convert to factor) and derives some new ones
# Stacks admission dates (one row per admission per patient)
######################################




# Import libraries ----
library('tidyverse')
library('lubridate')
library('arrow')
library('here')
library('glue')

# Import custom user functions from lib
source(here("analysis", "lib", "utility.R"))

# output processed data to rds ----

fs::dir_create(here("output", "admissions"))

# process ----

get_admissions <- function(method, n){
  import_extract(
    here("dummy-output", glue("sus_method{method}_admission{n}.feather")),
    here("output", "admissions", glue("sus_method{method}_admission{n}.csv.gz"))
  ) %>%
  select(-previous_admission_date) %>%
  add_column(
    admission_method=method,
    admission_number=n,
    .before=1
  )
}

process_admissions <- function(method){
  bind_rows(
    get_admissions(method, 1),
    get_admissions(method, 2),
    get_admissions(method, 3),
    get_admissions(method, 4),
    get_admissions(method, 5)
  ) %>%
  mutate(
    ageband = cut(
      age,
      breaks=c(-Inf, 18, 40, 55, 65, 75, Inf),
      labels=c("under 18", "18-39", "40-54", "55-64", "65-74", "75+"),
      right=FALSE
    ),
    sex = fct_case_when(
      sex == "F" ~ "Female",
      sex == "M" ~ "Male",
      #sex == "I" ~ "Inter-sex",
      #sex == "U" ~ "Unknown",
      TRUE ~ NA_character_
    ),
    region = fct_collapse(
      region,
      `East of England` = "East",
      `London` = "London",
      `Midlands` = c("West Midlands", "East Midlands"),
      `North East and Yorkshire` = c("Yorkshire and The Humber", "North East"),
      `North West` = "North West",
      `South East` = "South East",
      `South West` = "South West"
    )
  )
}

admissions_A_processed <- process_admissions("A")
admissions_B_processed <- process_admissions("B")
admissions_C_processed <- process_admissions("C")
# admissions_D_processed <- process_admissions("D")
# admissions_E_processed <- process_admissions("E")


write_rds(admissions_A_processed, here("output", "admissions", "processed_sus_A.rds"), compress="gz")
write_rds(admissions_B_processed, here("output", "admissions", "processed_sus_B.rds"), compress="gz")
write_rds(admissions_C_processed, here("output", "admissions", "processed_sus_C.rds"), compress="gz")
# write_rds(admissions_D_processed, here("output", "admissions", "processed_sus_D.rds"), compress="gz")
# write_rds(admissions_E_processed, here("output", "admissions", "processed_sus_E.rds"), compress="gz")

