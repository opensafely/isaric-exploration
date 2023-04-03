
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

  admission_date = bn_node(
    ~as.integer(seq_len(..n)*(500/..n)), # uniformly distributed over day 0 to 500
    missing_rate = ~0
  ),

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

  ccd_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  hypertension_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  chronicpul_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  asthma_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  ckd_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  mildliver_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  modliver_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  neuro_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  cancer_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  haemo_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  hiv_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  obesity_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  diabetes_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  diabetescom_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  rheumatologic_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  dementia_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),

  malnutrition_isaric = bn_node(
    ~rfactor(n=..n, levels = c("YES", "NO", "Unknown"), p = c(0.1, 0.89, 0.01)),
  ),


  ccd_pc = bn_node(
    ~if_else(ccd_isaric=="YES", runif(..n)<0.99, runif(..n)>0.99)*1L,
  ),

  hypertension_pc = bn_node(
    ~if_else(hypertension_isaric=="YES", runif(..n)<0.99, runif(..n)>0.99)*1L,
  ),

  copd_pc = bn_node(
    ~if_else(chronicpul_isaric=="YES", runif(..n)<0.90, runif(..n)>0.99)*1L,
  ),
  asthma_pc = bn_node(
    ~if_else(asthma_isaric=="YES", runif(..n)<0.99, runif(..n)>0.99)*1L,
  ),
  ckd_pc = bn_node(
    ~if_else(ckd_isaric=="YES", runif(..n)<0.99, runif(..n)>0.99)*1L,
  ),
  neuro_pc = bn_node(
    ~if_else(neuro_isaric=="YES", runif(..n)<0.99, runif(..n)>0.99)*1L,
  ),
  cancer_haemo_pc = bn_node(
    ~if_else(cancer_isaric=="YES", runif(..n)<0.20, runif(..n)>0.99)*1L,
  ),
  cancer_lung_pc = bn_node(
    ~if_else(cancer_isaric=="YES", runif(..n)<0.20, runif(..n)>0.99)*1L,
  ),
  cancer_other_pc = bn_node(
    ~if_else(cancer_isaric=="YES", runif(..n)<0.70, runif(..n)>0.99)*1L,
  ),
  hiv_pc = bn_node(
    ~if_else(hiv_isaric=="YES", runif(..n)<0.99, runif(..n)>0.99)*1L,
  ),
  diabetes_pc = bn_node(
    ~if_else(diabetes_isaric=="YES", runif(..n)<0.99, runif(..n)>0.99)*1L,
  ),
  diabetes_t1_pc = bn_node(
    ~if_else(diabetes_pc=="YES", runif(..n)<0.20, runif(..n)>0.99)*1L,
  ),
  diabetes_t2_pc = bn_node(
    ~if_else(diabetes_pc=="YES" & !diabetes_t1_pc, runif(..n)<0.95, runif(..n)>0.99)*1L,
  ),

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
    mutate(across(c("admission_date"), ~ as.Date(as.character(index_date + .))))
}

dummydata_processed <- day_to_date(dummydata, index_date)


fs::dir_create(here("output", "admissionsdummy"))

write_feather(dummydata_processed, sink = here("dummy-output", "isaric_admission1.feather"))
write_csv(dummydata_processed, here("dummy-tables", "isaric_raw.csv"))
