######################################
# This script compares ascertainment of covid-19 hospitalisations via SUS (APCS or ECDS) with that via ISARIC
######################################


# preliminaries ----

## Import libraries ----
library('tidyverse')
library('here')
library('glue')
library('fuzzyjoin')
library('data.table')

## Import custom user functions from lib
source(here("analysis", "lib", "utility.R"))

start_date = as.Date("2020-02-01")
end_date = as.Date("2022-11-30")

rounding_threshold <- 10

## output processed data to rds ----
output_dir <- here("output", "validation_events")
fs::dir_create(output_dir)

## import data ----

# import sus data
import_sus_data <- function(method){
  dat <- read_rds(here("output", "admissions", glue("processed_sus_{method}.rds")))
  dat <- transmute(
    dat,
    patient_id,
    admission_number,
    admission_date,
    "admission_date_sus{method}" := admission_date,
    "method_sus{method}" := TRUE
  )

  return(dat)
}

admissions_susA  <- import_sus_data("A")
admissions_susB  <- import_sus_data("B")
admissions_susC  <- import_sus_data("C")


# import ISARIC data
admissions_isaric  <- read_rds(here("output", "admissions", "processed_isaric.rds")) %>%
  transmute(
    patient_id,
    admission_number,
    admission_date,
    admission_date_isaric=admission_date,
    method_isaric=TRUE
  )

# compare ascertainment of COVID-19 admissions between SUS and ISARIC ----

# Note, we assume ISARIC as a tool for identifying COVID-19 in-patient admissions is 100% specific, but not 100% sensitive.
# In other words, it may not pick up every COVID-19 admission, either because
# - lack of coverage in certain hospitals
# - some admissions were missed in participating hospitals
# - admission date was badly recorded
# but every ISARIC record corresponds to a "true" COVID-19 admission
# our goal is to see if national hospital data (provided via SUS) is capable of identifying those records picked up by SUS

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

# sensitivity of SUS for picking up admissions reported in ISARIC ----

## match records using exact date ----

ascertainment <-
  admissions_joined %>%
  # recover left-join on isaric admissions
  filter(method_isaric) %>%
  # remove multiple same-day matches from SUS
  group_by(patient_id, admission_date) %>%
  mutate(dup_id = row_number()) %>%
  ungroup() %>%
  filter(dup_id==1L) %>%
  # summarise number of SUS admissions that match isaric admissions
  summarise(
    isaric_n = roundmid_any(n(), 10),
    susA_n = roundmid_any(sum(method_susA),10),
    susB_n = roundmid_any(sum(method_susB),10),
    susC_n = roundmid_any(sum(method_susC),10),
    susA_prop = susA_n/isaric_n,
    susB_prop = susB_n/isaric_n,
    susC_prop = susC_n/isaric_n,
  ) %>%
  pivot_longer(
    cols=everything(),
    names_to = c("method", ".value"),
    names_pattern = "(.*)_(.*)"
  )

ascertainment

write_csv(ascertainment, fs::path(output_dir, "ascertainment.csv"))

remove(admissions_joined)


## match records using non-exact date ----

# we use fuzzy (=non-equi) matching in case admission dates are slightly different (and to pick up different spells/episodes within a single super spell, etc)

# all dates of admission via ISARIC per patient up to <end_date>, and each SUS ascertainment method where a match was found for that date +/- X days

function_fuzzy_join <- function(mx, my, x_days_before, x_days_after){
  # this function is easy to read but is very very slow
  # there is now an equivalent function to `fuzzy_left_join` in dplyr (and probably much faster), but this version of dplyr is not currently in the opensafely R image
  joined <- fuzzy_left_join(
    mx,
    my,
    by = c("patient_id", "admission_date"),
    match_fun = list(
      patient_id = `==`,
      admission_date = function(x,y){x>=y-x_days_before & x<=y+x_days_after}
    )
  )
  renamed <- rename(joined, patient_id=patient_id.x, admission_date=admission_date.x)
  select(renamed, -patient_id.y, -admission_date.y)
}


function_nonequi_join <- function(mx, my, x_days_before, x_days_after){
  # this function uses the data.table package. it's harder to read, but it is very very quick!
  joined <- setDT(my)[
    ,
    c("admission_date_pre", "admission_date_post") := list(admission_date-x_days_before, admission_date+x_days_after)
  ][
    setDT(mx),
    on = .(patient_id, admission_date_pre<=admission_date, admission_date_post>=admission_date)
  ]
  joined <- select(joined, -admission_date_pre, -admission_date_post) %>% mutate(admission_date=admission_date_isaric)
  joined
}

admissions_joined_nonequi <-
  reduce(
    lst(
      admissions_isaric %>% filter(admission_number == 1),
      admissions_susA %>% select(-admission_number),
      admissions_susB %>% select(-admission_number),
      admissions_susC %>% select(-admission_number),
    ),
    ~{function_nonequi_join(.x, .y, 2, 2)},
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


ascertainment_nonequi <-
  admissions_joined_nonequi %>%
  # remove multiple matches within period -- ignore thinking about how to select the most appropriate match for now as it doesn't matter in the summary
  group_by(patient_id, admission_date) %>%
  mutate(dup_id = row_number()) %>%
  ungroup() %>%
  filter(dup_id==1L) %>%
  # summarise number of SUS admissions that closely match isaric admissions
  summarise(
    isaric_n = roundmid_any(n(), 10),
    susA_n = roundmid_any(sum(method_susA),10),
    susB_n = roundmid_any(sum(method_susB),10),
    susC_n = roundmid_any(sum(method_susC),10),
    susA_prop = susA_n/isaric_n,
    susB_prop = susB_n/isaric_n,
    susC_prop = susC_n/isaric_n,
    susA_datediff = plyr::round_any(as.numeric(mean(admission_date_diff_susA, na.rm=TRUE)),1/24),
    susB_datediff = plyr::round_any(as.numeric(mean(admission_date_diff_susB, na.rm=TRUE)),1/24),
    susC_datediff = plyr::round_any(as.numeric(mean(admission_date_diff_susC, na.rm=TRUE)),1/24),
  ) %>%
  pivot_longer(
    cols=everything(),
    names_to = c("method", ".value"),
    names_pattern = "(.*)_(.*)"
  )

ascertainment_nonequi

write_csv(ascertainment_nonequi, fs::path(output_dir, "ascertainment_nonequi.csv"))





