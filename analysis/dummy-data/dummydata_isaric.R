
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

sim_list = lst(

  corona_ieorres = bn_node(
    ~rfactor(n=..n, levels = c("Yes", "No"), p = c(0.51, 0.49)),
    missing_rate = ~0.1
  ),

  coriona_ieorres2 = bn_node(
    ~rfactor(n=..n, levels = c("Yes", "No"), p = c(0.51, 0.49)),
    missing_rate = ~0.1
  ),

  coriona_ieorres3 = bn_node(
    ~rfactor(n=..n, levels = c("Yes", "No"), p = c(0.51, 0.49)),
    missing_rate = ~0.1
  ),

  inflammatory_mss = bn_node(
    ~rfactor(n=..n, levels = c("Yes", "No"), p = c(0.51, 0.49)),
    missing_rate = ~0.1
  ),

  covid19_vaccine = bn_node(
    ~rfactor(n=..n, levels = c("Yes", "No", "N/K"), p = c(0.50, 0.40, 0.1)),
    missing_rate = ~0.1
  ),

  age = bn_node(
    ~rnorm(n=..n, mean=60, sd=14)
  ),

  calc_age = bn_node(
    ~floor(age)
  ),

  sex = bn_node(
    ~rfactor(n=..n, levels = c("Female", "Male"), p = c(0.51, 0.49)),
    missing_rate = ~0.001 # this is shorthand for ~(rbernoulli(n=..n, p = 0.2))
  ),

  hostdat = bn_node(
    ~as.integer(seq_len(..n)*(500/..n)), # uniformly distributed over day 0 to 500
    missing_rate = ~0
  ),

  diabetes = bn_node(
    ~rbernoulli(..n, 0.1),
  ),

  chronic_cardiac_disease = bn_node(
    ~rbernoulli(..n, 0.1),
  ),

  # dsstdat = bn_node(
  #   ~as.integer(runif(n=..n, hostdat-20, hostdat)),
  #   missing_rate = ~0
  # ),

)

bn <- bn_create(sim_list, known_variables = known_variables)

bn_plot(bn)
bn_plot(bn, connected_only=TRUE)

set.seed(10)

dummydata <- bn_simulate(bn, pop_size = population_size, keep_all = FALSE, .id="patient_id")

day_to_date <- function(data, index_date){
  data %>%
    #convert logical to integer as study defs output 0/1 not TRUE/FALSE
    mutate(across(where(is.logical), ~ as.integer(.))) %>%
    #convert integer days to dates since index date and rename vars
    mutate(across(c("hostdat"), ~ as.Date(as.character(index_date + .))))
}

dummydata_processed <- day_to_date(dummydata, index_date)


fs::dir_create(here("output", "admissionsdummy"))

write_feather(dummydata_processed, sink = here("output", "admissionsdummy", "isaric_admission1.feather"))
write_csv(dummydata_processed, here("dummy-tables", "isaric_raw.csv"))
