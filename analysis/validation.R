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
      admissions_isaric %>% filter(admission_number == 1) %>% transmute(patient_id, admission_date, method_isaric=TRUE),
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

write_csv(ascertainment, here("output","validation", "ascertainment.csv"))



# now using fuzzy matching in-case admission dates are slightly different (and to pick up different spells/episodes within a single super spell, etc)

# all dates of admission via ISARIC per patient up to <end_date>, and each SUS ascertainment method where a match was found for that date +/- 3 days
admissions_joined_fuzzy <-
  reduce(
    lst(
      admissions_isaric %>% filter(admission_number == 1) %>% transmute(patient_id, admission_date, admission_date_isaric=admission_date, method_isaric=TRUE),
      admissions_susA %>% filter(admission_number == 1) %>% transmute(patient_id, admission_date, admission_date_susA=admission_date, method_susA=TRUE),
      admissions_susB %>% filter(admission_number == 1) %>% transmute(patient_id, admission_date, admission_date_susB=admission_date, method_susB=TRUE),
      admissions_susC %>% filter(admission_number == 1) %>% transmute(patient_id, admission_date, admission_date_susC=admission_date, method_susC=TRUE),
    ),
    ~{
      fuzzy_left_join(
        .x,
        .y,
        by = c("patient_id", "admission_date"),
        match_fun = list(
          patient_id = `==`,
          admission_date = function(x,y){x<=y+3 & x>=y-3})
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


# sensitivity of SUS for picking up admissions reported in ISARIC -------

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

write_csv(ascertainment_fuzzy, here("output","validation", "ascertainment_fuzzy.csv"))



# Ascertainment of clinical characteristics in SystmOne versus ISARIC -------

## Only consider ISARIC admissions

comorbs <-
  c(
    "ccd",
    "hypertension",
    #"chronicpul",
    "asthma",
    "ckd",
    #"mildliver",
    #"modliver",
    "neuro",
    #"cancer",
    #"haemo",
    "hiv",
    #"obesity",
    "diabetes",
    #"rheumatologic",
    #"dementia",
    #"malnutrition",
    NULL
  )

comorbs_crossvalidation <-
  admissions_isaric %>%
  mutate(
    across(
      .cols = all_of(str_c(comorbs, "_isaric")),
      .fns = ~(.=="YES")*1L
    )
  ) %>%
  select(
    patient_id, all_of(str_c(comorbs, "_isaric")), all_of(str_c(comorbs, "_pc"))
  ) %>%
  pivot_longer(
    -patient_id,
    names_to=c("comorb", ".value"),
    names_sep="_",
    values_to=""
  ) %>%
  group_by(comorb) %>%
  summarise(
    isaric_prop = mean(isaric),
    pc_prop = mean(pc),
    difference = isaric_prop - pc_prop,
    agreement = mean(isaric==pc),
    sensitivity = sum(pc*isaric) / sum(pc),
    specificity = sum((1-pc)*(1-isaric)) / sum((1-pc)),
  )

write_csv(comorbs_crossvalidation, here("output","validation", "comorbs_crossvalidation.csv"))





