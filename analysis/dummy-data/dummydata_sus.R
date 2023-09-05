
library('tidyverse')
library('arrow')
library('here')
library('glue')

#source(here("analysis", "lib", "utility_functions.R"))

remotes::install_github("https://github.com/wjchulme/dd4d")
library('dd4d')


population_size <- 2000

# get nth largest value from list
nthmax <- function(x, n=1){
  dplyr::nth(sort(x, decreasing=TRUE), n)
}

nthmin <- function(x, n=1){
  dplyr::nth(sort(x, decreasing=FALSE), n)
}

known_variables <- c(
  "index_date",
  "index_day"
)

index_date = as.Date("2020-01-01")

sim_list1 = lst(

  previous_admiss_day = bn_node(
    ~0
  ),

  admiss_day = bn_node(
    ~as.integer(seq_len(..n)*(500/..n)), # uniformly distributed over day 0 to 500, in order
    missing_rate = ~0.05
  ),

  prior_dereg_day = bn_node(
    ~as.integer(runif(n=..n, admiss_day-500, admiss_day)),
    missing_rate = ~0.99
  ),

  dereg_day = bn_node(
    ~as.integer(runif(n=..n, admiss_day, admiss_day+500)),
    missing_rate = ~0.99
  ),

  registered = bn_node(
    ~rbernoulli(n=..n, p=0.999)
  ),

  age = bn_node(
    ~as.integer(rnorm(n=..n, mean=60, sd=14))
  ),

  sex = bn_node(
    ~rfactor(n=..n, levels = c("F", "M"), p = c(0.51, 0.49)),
    missing_rate = ~0.001 # this is shorthand for ~(rbernoulli(n=..n, p = 0.2))
  ),

  obesity = bn_node(
    ~as.integer(rnorm(n=..n, mean=25, sd=5))
  ),

  practice_id = bn_node(
    ~as.integer(runif(n=..n, 1, 200))
  ),

  stp = bn_node(
    ~factor(as.integer(runif(n=..n, 1, 36)), levels=1:36)
  ),

  region = bn_node(
    variable_formula = ~rfactor(n=..n, levels=c(
      "North East",
      "North West",
      "Yorkshire and The Humber",
      "East Midlands",
      "West Midlands",
      "East",
      "London",
      "South East",
      "South West"
    ), p = c(0.2, 0.2, 0.3, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05))
  ),

  # comorbidities

  # diabetes = bn_node(
  #   ~rbernoulli(n=..n, p=0.15)
  # ),
  #
  # chronic_cardiac_disease = bn_node(
  #   ~rbernoulli(n=..n, p=0.2)
  # ),



  death_day = bn_node(
    ~as.integer(runif(n=..n, 800, 1500)),
    missing_rate = ~0.96
  ),
)

sim_list2 = lst(
  admiss_day = bn_node(
    ~as.integer(runif(n=..n, previous_admiss_day, 300)),
    missing_rate = ~0.9
  )
)

bn1 <- bn_create(sim_list1, known_variables = known_variables)
bn2 <- bn_create(sim_list2, known_variables = c(known_variables, "previous_admiss_day"))

bn_plot(bn1)
bn_plot(bn1, connected_only=TRUE)

set.seed(10)

dummydata1 <- bn_simulate(bn1, pop_size = population_size, keep_all = FALSE, .id="patient_id")
dummydata2 <- bn_simulate(bn2, pop_size = population_size, keep_all = FALSE, .id="patient_id", known_df = dummydata1 %>% select(-previous_admiss_day) %>% rename(previous_admiss_day = admiss_day))
dummydata3 <- bn_simulate(bn2, pop_size = population_size, keep_all = FALSE, .id="patient_id", known_df = dummydata2 %>% select(-previous_admiss_day) %>% rename(previous_admiss_day = admiss_day))
dummydata4 <- bn_simulate(bn2, pop_size = population_size, keep_all = FALSE, .id="patient_id", known_df = dummydata3 %>% select(-previous_admiss_day) %>% rename(previous_admiss_day = admiss_day))
dummydata5 <- bn_simulate(bn2, pop_size = population_size, keep_all = FALSE, .id="patient_id", known_df = dummydata4 %>% select(-previous_admiss_day) %>% rename(previous_admiss_day = admiss_day))

day_to_date <- function(data, index_date){
  data %>%
    filter(!is.na(admiss_day)) %>%
    #convert logical to integer as study defs output 0/1 not TRUE/FALSE
    mutate(across(where(is.logical), ~ as.integer(.))) %>%
    #convert integer days to dates since index date and rename vars
    mutate(across(ends_with("_day"), ~ as.Date(as.character(index_date + .)))) %>%
    rename_with(~str_replace(., "_day", "_date"), ends_with("_day"))
}

dummydata1_processed <- day_to_date(dummydata1, index_date)
dummydata2_processed <- day_to_date(dummydata2, index_date)
dummydata3_processed <- day_to_date(dummydata3, index_date)
dummydata4_processed <- day_to_date(dummydata4, index_date)
dummydata5_processed <- day_to_date(dummydata5, index_date)


fs::dir_create(here("dummy-output"))

write_feather(dummydata1_processed, sink = here("dummy-output", "sus_methodA_admission1.feather"))
write_feather(dummydata2_processed, sink = here("dummy-output", "sus_methodA_admission2.feather"))
write_feather(dummydata3_processed, sink = here("dummy-output", "sus_methodA_admission3.feather"))
write_feather(dummydata4_processed, sink = here("dummy-output", "sus_methodA_admission4.feather"))
write_feather(dummydata5_processed, sink = here("dummy-output", "sus_methodA_admission5.feather"))

write_feather(dummydata1_processed, sink = here("dummy-output", "sus_methodB_admission1.feather"))
write_feather(dummydata2_processed, sink = here("dummy-output", "sus_methodB_admission2.feather"))
write_feather(dummydata3_processed, sink = here("dummy-output", "sus_methodB_admission3.feather"))
write_feather(dummydata4_processed, sink = here("dummy-output", "sus_methodB_admission4.feather"))
write_feather(dummydata5_processed, sink = here("dummy-output", "sus_methodB_admission5.feather"))

write_feather(dummydata1_processed, sink = here("dummy-output", "sus_methodC_admission1.feather"))
write_feather(dummydata2_processed, sink = here("dummy-output", "sus_methodC_admission2.feather"))
write_feather(dummydata3_processed, sink = here("dummy-output", "sus_methodC_admission3.feather"))
write_feather(dummydata4_processed, sink = here("dummy-output", "sus_methodC_admission4.feather"))
write_feather(dummydata5_processed, sink = here("dummy-output", "sus_methodC_admission5.feather"))

write_feather(dummydata1_processed, sink = here("dummy-output", "sus_methodD_admission1.feather"))
write_feather(dummydata2_processed, sink = here("dummy-output", "sus_methodD_admission2.feather"))
write_feather(dummydata3_processed, sink = here("dummy-output", "sus_methodD_admission3.feather"))
write_feather(dummydata4_processed, sink = here("dummy-output", "sus_methodD_admission4.feather"))
write_feather(dummydata5_processed, sink = here("dummy-output", "sus_methodD_admission5.feather"))

write_feather(dummydata1_processed, sink = here("dummy-output", "sus_methodE_admission1.feather"))
write_feather(dummydata2_processed, sink = here("dummy-output", "sus_methodE_admission2.feather"))
write_feather(dummydata3_processed, sink = here("dummy-output", "sus_methodE_admission3.feather"))
write_feather(dummydata4_processed, sink = here("dummy-output", "sus_methodE_admission4.feather"))
write_feather(dummydata5_processed, sink = here("dummy-output", "sus_methodE_admission5.feather"))

