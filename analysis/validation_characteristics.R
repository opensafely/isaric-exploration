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
output_dir <- here("output", "validation_characteristics")
fs::dir_create(output_dir)

here(output_dir, "ascertainment_fuzzy.csv")

## import data ----

admissions_isaric  <- read_rds(here("output", "admissions", "processed_isaric.rds"))


# describe isaric admissions ----

## admissions over time ----

admissions_per_week <-
  admissions_isaric %>%
  filter(admission_number==1, admission_date >= start_date, admission_date <= end_date) %>%
  mutate(
    admission_week = round_date(admission_date, unit="week", week_start=1)
  ) %>%
  group_by(admission_week) %>%
  summarise(
    n = n()
  ) %>%
  ungroup() %>%
  complete(
    admission_week = full_seq(.$admission_week, 7), # in case zero admissions on some days
    fill = list(n=0)
  ) %>%
  arrange(admission_week) %>%
  mutate(
    cumuln = cumsum(n)
  ) %>%
  ungroup() %>%
  mutate(
    cumuln = roundmid_any(cumuln, to = rounding_threshold),
    n = diff(c(0,cumuln)),
  )

write_csv(admissions_per_week, fs::path(output_dir, "isaric_admissions_per_week.csv"))

xmin <- min(admissions_per_week$admission_week )
xmax <- max(admissions_per_week$admission_week )+7

plot_admissions_per_week <-
  admissions_per_week %>%
  ggplot()+
  geom_col(
    aes(
      x=admission_week+0.5,
      y=n,
      colour=NULL
    ),
    #position=position_stack(reverse=TRUE),
    #alpha=0.8,
    width=5
  )+
  #geom_rect(xmin=xmin, xmax= xmax+1, ymin=-6, ymax=6, fill="grey", colour="transparent")+
  geom_hline(yintercept = 0, colour="black")+
  scale_x_date(
    breaks = unique(lubridate::ceiling_date(admissions_per_week$admission_week, "6 month")),
    limits = c(xmin-1, NA),
    labels = scales::label_date("%d/%m/%Y"),
    expand = expansion(add=1),
  )+
  scale_y_continuous(
    #labels = ~scales::label_number(accuracy = 1, big.mark=",")(abs(.x)),
    expand = expansion(c(0, NA))
  )+
  scale_fill_brewer(type="qual", palette="Set2")+
  scale_colour_brewer(type="qual", palette="Set2")+
  #scale_alpha_discrete(range= c(0.8,0.4))+
  labs(
    x="Date",
    y="ISARIC-recorded COVID-19 admissions per week",
    colour=NULL,
    fill=NULL,
    alpha=NULL
  ) +
  theme_minimal()+
  theme(
    axis.line.x.bottom = element_line(),
    axis.text.x.top=element_text(hjust=0),
    strip.text.y.right = element_text(angle = 0),
    axis.ticks.x=element_line(),
    legend.position = "bottom"
  )+
  NULL

ggsave(plot_admissions_per_week, filename="admission_per_week.jpg", path=output_dir)
remove(plot_admissions_per_week)


## baseline characteristics ----

var_labels <- list(
  N  ~ "Total N",
  age ~ "Age",
  sex ~ "Sex",
  ccd_isaric ~ "Chronic cardiac disease",
  hypertension_isaric ~ "Hypertension",
  ckd_isaric ~ "Chronic kidney disease",
  diabetes_isaric ~ "Diabetes",
  asthma_isaric ~ "Asthma",
  neuro_isaric ~ "Neurological disease",
  hiv_isaric ~ "HIV/AIDS"
) %>%
  set_names(., map_chr(., all.vars))


data_baseline <-
  admissions_isaric %>%
  filter(admission_number==1, admission_date >= start_date, admission_date <= end_date) %>%
  select(patient_id, all_of(names(var_labels[-1])))

library('gt')
library('gtsummary')

tab_summary_baseline <-
  data_baseline %>%
  mutate(
    N = 1L
  ) %>%
  select(
    all_of(names(var_labels)),
  ) %>%
  tbl_summary(
    #by = treatment_descr,
    label = unname(var_labels[names(.)]),
    statistic = list(
      N = "{N}",
      age="{mean} ({sd})"
    ),
  )

raw_stats <- tab_summary_baseline$meta_data %>%
  select(var_label, df_stats) %>%
  unnest(df_stats)

remove(tab_summary_baseline)
remove(data_baseline)


raw_stats_redacted <- raw_stats %>%
  mutate(
    n = roundmid_any(n, rounding_threshold),
    N = roundmid_any(N, rounding_threshold),
    p = n / N,
    N_miss = roundmid_any(N_miss, rounding_threshold),
    N_obs = roundmid_any(N_obs, rounding_threshold),
    p_miss = N_miss / N_obs,
    N_nonmiss = roundmid_any(N_nonmiss, rounding_threshold),
    p_nonmiss = N_nonmiss / N_obs,
    var_label = factor(var_label, levels = map_chr(var_labels[-c(1, 2)], ~ last(as.character(.)))),
    variable_levels = replace_na(as.character(variable_levels), "")
  )

write_csv(raw_stats_redacted, fs::path(output_dir, "baseline.csv"))


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

write_csv(comorbs_crossvalidation, fs::path(output_dir, "comorbs_crossvalidation.csv"))





