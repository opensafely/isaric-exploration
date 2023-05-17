######################################
# This script compares ascertainment of covid-19 hospitalisations via SUS (APCS or ECDS) with that via ISARIC
######################################


# preliminaries ----

## Import libraries ----
library('tidyverse')
library('lubridate')
library('here')
library('glue')
library('fuzzyjoin')

## Import custom user functions from lib
source(here("analysis", "lib", "utility.R"))

start_date = as.Date("2020-02-01")
end_date = as.Date("2022-11-30")

rounding_threshold <- 10

## output processed data to rds ----
output_dir <- here("output", "validation_events")
fs::dir_create(output_dir)

## import data ----

import_sus_data <- function(method){
  dat <- read_rds(here("output", "admissions", glue("processed_sus_{method}.rds")))
  dat <- transmute(
    dat,
    patient_id,
    admission_number,
    admission_date,
    "method_sus{method}" := TRUE,
    "admission_date_sus{method}" := admission_date
  )

  return(dat)
}

admissions_susA  <- import_sus_data("A")
admissions_susB  <- import_sus_data("B")
admissions_susC  <- import_sus_data("C")

admissions_isaric  <- read_rds(here("output", "admissions", "processed_isaric.rds")) %>%
  transmute(patient_id, admission_number, admission_date, admission_date_isaric=admission_date) %>%
  mutate(method_isaric=TRUE)

# admissions ----

## Number of first ISARIC admissions in TPP
nrow(admissions_isaric %>% filter(admission_number==1))
nrow(admissions_isaric %>% filter(admission_number==1, admission_date >= start_date, admission_date <= end_date))

## Number of first SUS admissions in TPP
nrow(admissions_susA %>% filter(admission_number ==1))
nrow(admissions_susB %>% filter(admission_number ==1))
nrow(admissions_susC %>% filter(admission_number ==1))
nrow(admissions_susA %>% filter(admission_number ==1, admission_date >= start_date, admission_date <= end_date))
nrow(admissions_susB %>% filter(admission_number ==1, admission_date >= start_date, admission_date <= end_date))
nrow(admissions_susC %>% filter(admission_number ==1, admission_date >= start_date, admission_date <= end_date))



# all dates of admission per patient up to <end_date>, and each ascertainment method where a match was found for that date
admissions_joined <-
  reduce(
    lst(
      admissions_isaric %>% filter(admission_number == 1),
      admissions_susA %>% select(-admission_number),
      admissions_susB %>% select(-admission_number),
      admissions_susC %>% select(-admission_number),
    ),
    full_join,
    by = c("patient_id", "admission_date")
  ) %>%
  replace_na(
    lst(
      method_isaric=FALSE,
      method_susA=FALSE,
      method_susB=FALSE,
      method_susC=FALSE,
    )
  ) %>%
  filter(
    admission_date >= start_date,
    admission_date <= end_date
  )

# sensitivity of SUS for picking up admissions reported in ISARIC -------

ascertainment <-
  admissions_joined %>%
  filter(method_isaric) %>%
  summarise(
    isaric_n = n(),
    susA_n = sum(method_susA),
    susB_n = sum(method_susB),
    susC_n = sum(method_susC),
    susA_prop = mean(method_susA),
    susB_prop = mean(method_susB),
    susC_prop = mean(method_susC),
  ) %>%
  pivot_longer(
    cols=everything(),
    names_to = c("method", ".value"),
    names_pattern = "(.*)_(.*)"
  )

ascertainment

write_csv(ascertainment, fs::path(output_dir, "ascertainment.csv"))

remove(admissions_joined)

# now using fuzzy matching in case admission dates are slightly different (and to pick up different spells/episodes within a single super spell, etc)

# all dates of admission via ISARIC per patient up to <end_date>, and each SUS ascertainment method where a match was found for that date +/- 3 days

# the version below hits memory limits, so refectoring below...
if(TRUE){
  admissions_joined_fuzzy <-
    reduce(
      lst(
        admissions_isaric %>% filter(admission_number == 1),
        admissions_susA %>% select(-admission_number),
        admissions_susB %>% select(-admission_number),
        admissions_susC %>% select(-admission_number),
      ),
      ~{
        fuzzy_left_join(
          .x,
          .y,
          by = c("patient_id", "admission_date"),
          match_fun = list(
            patient_id = `==`,
            admission_date = function(x,y){x<=y+1 & x>=y-1}
          )
        ) %>%
          rename(patient_id=patient_id.x, admission_date=admission_date.x) %>%
          select(-patient_id.y, -admission_date.y)
      },
    ) %>%
    mutate(
      admission_date_diff_susA = admission_date_susA - admission_date_isaric,
      admission_date_diff_susB = admission_date_susB - admission_date_isaric,
      admission_date_diff_susC = admission_date_susC - admission_date_isaric
    ) %>%
    replace_na(
      lst(
        method_isaric=FALSE,
        method_susA=FALSE,
        method_susB=FALSE,
        method_susC=FALSE,
      )
    ) %>%
    filter(
      admission_date >= start_date,
      admission_date <= end_date
    )
}


# potentially lower memory version:
# function_fuzzy_join <- function(mx, my){
#   joined <- fuzzy_left_join(
#     mx,
#     my,
#     by = c("patient_id", "admission_date"),
#     match_fun = list(
#       patient_id = `==`,
#       admission_date = function(x,y){x<=y+1 & x>=y-1}
#     )
#   )
#   renamed <- rename(joined, patient_id=patient_id.x, admission_date=admission_date.x)
#   select(renamed, -patient_id.y, -admission_date.y)
# }
#
# print("susA")
# admissions_joined_fuzzy <-
#   admissions_isaric %>% filter(admission_number == 1) %>%
#   function_fuzzy_join(
#     admissions_susA
#   )
#
# print("susB")
# admissions_joined_fuzzy <-
#   function_fuzzy_join(
#     admissions_joined_fuzzy,
#     admissions_susB
#   )
#
# print("susC")
# admissions_joined_fuzzy <-
#   function_fuzzy_join(
#     admissions_joined_fuzzy,
#     admissions_susC
#   ) %>%
#   mutate(
#     admission_date_diff_susA = admission_date_susA - admission_date_isaric,
#     admission_date_diff_susB = admission_date_susB - admission_date_isaric,
#     admission_date_diff_susC = admission_date_susC - admission_date_isaric
#   ) %>%
#   replace_na(
#     lst(
#       method_isaric=FALSE,
#       method_susA=FALSE,
#       method_susB=FALSE,
#       method_susC=FALSE,
#     )
#   ) %>%
#   filter(
#     admission_date >= start_date,
#     admission_date <= end_date
#   )


# sensitivity of SUS for picking up admissions reported in ISARIC -------

print("summarise")
ascertainment_fuzzy <-
  admissions_joined_fuzzy %>%
  filter(method_isaric) %>%
  summarise(
    isaric_n = n(),
    susA_n = sum(method_susA),
    susB_n = sum(method_susB),
    susC_n = sum(method_susC),
    susA_prop = mean(method_susA),
    susB_prop = mean(method_susB),
    susC_prop = mean(method_susC),
    susA_datediff = mean(admission_date_diff_susA, na.rm=TRUE),
    susB_datediff = mean(admission_date_diff_susB, na.rm=TRUE),
    susC_datediff = mean(admission_date_diff_susC, na.rm=TRUE),
  ) %>%
  pivot_longer(
    cols=everything(),
    names_to = c("method", ".value"),
    names_pattern = "(.*)_(.*)"
  )

ascertainment_fuzzy

write_csv(ascertainment_fuzzy, fs::path(output_dir, "ascertainment_fuzzy.csv"))





