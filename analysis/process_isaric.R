######################################

# This script:
# imports data extracted by the ehrQL (or dummy data)
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

## import ISARIC admissions data ----
get_admissions <- function(n){
  import_extract(
    here("dummy-output", glue("isaric_admission{n}.feather")),
    here("output", "admissions", glue("isaric_admission{n}.csv.gz"))
  ) %>%
  add_column(
    admission_method="ISARIC",
    admission_number=n,
    .before=1
  )
}

isaric_raw1 <- get_admissions(1)


## print basic dataset decription to file ----

os_skim(isaric_raw1, path=here("output", "admissions", "isaric_raw_skim.txt"))

## standardise some variables ----

isaric_processed <-
  isaric_raw1 %>%
  mutate(
    ieorres1 = corona_ieorres == "Yes",
    ieorres2 = coriona_ieorres2 == "Yes",
    ieorres3 = coriona_ieorres3 == "Yes",
    inflammatory_mss = inflammatory_mss == "Yes",
    covid19_vaccine = covid19_vaccine == "Yes",
    ageband = cut(
      age,
      breaks=c(-Inf, 18, 40, 55, 65, 75, Inf),
      labels=c("under 18", "18-39", "40-54", "55-64", "65-74", "75+"),
      right=FALSE
    ),
    sex = factor(sex, levels=c("Female", "Male")),
    cancer_pc = (cancer_lung_pc | cancer_haemo_pc | cancer_other_pc )*1L
  )

## save to file ----

write_rds(isaric_processed, here("output", "admissions", "processed_isaric.rds"), compress="gz")
