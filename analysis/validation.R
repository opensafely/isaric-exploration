######################################
# This script compares ascertainment of covid-19 hospitalisations via SUS (APCS or ECDS) with that via ISARIC
######################################


# preliminaries ----

## Import libraries ----
library('tidyverse')
library('lubridate')
library('here')
library('glue')

## Import custom user functions from lib
source(here("analysis", "lib", "utility.R"))

end_date = as.Date("2022-11-30")

## output processed data to rds ----

fs::dir_create(here("output", "validation"))

## import data ----

admissions_susA  <- read_rds(here("output", "admissions", "processed_sus_A.rds"))
admissions_susB  <- read_rds(here("output", "admissions", "processed_sus_B.rds"))
admissions_susC  <- read_rds(here("output", "admissions", "processed_sus_C.rds"))
admissions_isaric  <- read_rds(here("output", "admissions", "processed_isaric.rds"))


# admissions ----


## Number of first ISARIC admissions in TPP
nrow(admissions_isaric %>% filter(admission_number==1))

## Number of first SUS admissions in TPP
nrow(admissions_susA %>% filter(admission_number ==1))
nrow(admissions_susB %>% filter(admission_number ==1))
nrow(admissions_susC %>% filter(admission_number ==1))


# all dates of admission per patient up to <end_date>, and each ascertainment method where a match was found for that date
admissions_joined <-
  reduce(
    lst(
      admissions_isaric %>% filter(admission_number == 1) %>% transmute(patient_id, admission_date=hostdat, method_isaric=TRUE),
      admissions_susA %>% filter(admission_number == 1) %>% transmute(patient_id, admission_date, method_susA=TRUE),
      admissions_susB %>% filter(admission_number == 1) %>% transmute(patient_id, admission_date, method_susB=TRUE),
      admissions_susC %>% filter(admission_number == 1) %>% transmute(patient_id, admission_date, method_susC=TRUE),
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
  filter(admission_date <= end_date)

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

write_csv(ascertainment, here("output","validation", "ascertainment.csv"))



