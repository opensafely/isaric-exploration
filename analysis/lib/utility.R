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

# Import custom user functions from lib
import_extract <- function(custom_file_path, studydef_file_path){

  if(Sys.getenv("OPENSAFELY_BACKEND") %in% c("", "expectations")){

    # ideally in future this will check column existence and types from metadata,
    # rather than from a cohort-extractor-generated dummy data

    data_studydef_dummy <- read_csv(studydef_file_path) %>%
      # because date types are not returned consistently by cohort extractor
      mutate(across(ends_with("_date"), ~ as.Date(.))) %>%
      mutate(patient_id = as.integer(patient_id))

    data_custom_dummy <- read_feather(custom_file_path)

    not_in_studydef <- names(data_custom_dummy)[!( names(data_custom_dummy) %in% names(data_studydef_dummy) )]
    not_in_custom  <- names(data_studydef_dummy)[!( names(data_studydef_dummy) %in% names(data_custom_dummy) )]


    if(length(not_in_custom)!=0) stop(
      paste(
        "These variables are in studydef but not in custom: ",
        paste(not_in_custom, collapse=", ")
      )
    )

    if(length(not_in_studydef)!=0) stop(
      paste(
        "These variables are in custom but not in studydef: ",
        paste(not_in_studydef, collapse=", ")
      )
    )

    # reorder columns
    data_studydef_dummy <- data_studydef_dummy[,names(data_custom_dummy)]

    unmatched_types <- cbind(
      map_chr(data_studydef_dummy, ~paste(class(.), collapse=", ")),
      map_chr(data_custom_dummy, ~paste(class(.), collapse=", "))
    )[ (map_chr(data_studydef_dummy, ~paste(class(.), collapse=", ")) != map_chr(data_custom_dummy, ~paste(class(.), collapse=", ")) ), ] %>%
      as.data.frame() %>% rownames_to_column()


    # if(nrow(unmatched_types)>0) stop(
    #   #unmatched_types
    #   "inconsistent typing in studydef : dummy dataset\n",
    #   apply(unmatched_types, 1, function(row) paste(paste(row, collapse=" : "), "\n"))
    # )

    data_extract <- data_custom_dummy
  } else {
    data_extract <- read_csv(studydef_file_path) %>%
      #because date types are not returned consistently by cohort extractor
      mutate(across(ends_with("_date"),  as.Date))
  }
  data_extract
}


ceiling_any <- function(x, to=1){
  # round to nearest 100 millionth to avoid floating point errors
  ceiling(plyr::round_any(x/to, 1/100000000))*to
}

roundmid_any <- function(x, to=1){
  # like ceiling_any, but centers on (integer) midpoint of the rounding points
  ceiling(x/to)*to - (floor(to/2)*(x!=0))
}


fct_case_when <- function(...) {
  # uses dplyr::case_when but converts the output to a factor,
  # with factors ordered as they appear in the case_when's  ... argument
  args <- as.list(match.call())
  levels <- sapply(args[-1], function(f) f[[3]])  # extract RHS of formula
  levels <- levels[!is.na(levels)]
  factor(dplyr::case_when(...), levels=levels)
}


# Elsie's skim function, from https://github.com/opensafely/covid-vaccine-effectiveness-sequential-vs-single/blob/7189811b2a752bcc7fa5c714a8932f687393267b/analysis/functions/utility.R
os_skim <- function(
    .data, # dataset to be summarised
    path,
    id_suffix = "_id" # (set to NULL if no id columns)
){

  # specify summary function for each class
  my_skimmers <- list(
    logical = skimr::sfl(
    ),
    # numeric applied to numeric and integer
    numeric = skimr::sfl(
      mean = ~ mean(.x, na.rm=TRUE),
      sd = ~ sd(.x, na.rm=TRUE),
      min = ~ min(.x, na.rm=TRUE),
      p10 = ~ quantile(.x, p=0.1, na.rm=TRUE, type=1),
      p25 = ~ quantile(.x, p=0.25, na.rm=TRUE, type=1),
      p50 = ~ quantile(.x, p=0.5, na.rm=TRUE, type=1),
      p75 = ~ quantile(.x, p=0.75, na.rm=TRUE, type=1),
      p90 = ~ quantile(.x, p=0.9, na.rm=TRUE, type=1),
      max = ~ max(.x, na.rm=TRUE)
    ),
    character = skimr::sfl(),
    factor = skimr::sfl(),
    Date = skimr::sfl(
      # wrap in as.Date to avoid errors when all missing
      min = ~ as.Date(min(.x, na.rm=TRUE)),
      p50 = ~ as.Date(quantile(.x, p=0.5, na.rm=TRUE, type=1)),
      max = ~ as.Date(max(.x, na.rm=TRUE))
    ),
    POSIXct = skimr::sfl(
      # wrap in as.POSIXct to avoid errors when all missing
      min = ~ as.POSIXct(min(.x, na.rm=TRUE)),
      p50 = ~ as.POSIXct(quantile(.x, p=0.5, na.rm=TRUE, type=1)),
      max = ~ as.POSIXct(max(.x, na.rm=TRUE))
    )
  )

  my_skim_fun <- skimr::skim_with(
    !!!my_skimmers,
    append = FALSE
  )

  # summarise factors as the printing is not very nice or flexible in skim
  summarise_factor <- function(var) {

    out <- .data %>%
      group_by(across(all_of(var))) %>%
      count() %>%
      ungroup() %>%
      mutate(across(n, ~roundmid_any(.x, to = 7))) %>%
      mutate(percent = round(100*n/sum(n),2)) %>%
      arrange(!! sym(var))

    total <- nrow(out)

    out %>%
      slice(1:min(total, 10)) %>%
      knitr::kable(
        format = "pipe",
        caption = glue::glue("{min(total, 10)} of {total} factor levels printed")
      ) %>%
      print()

  }

  vars <- .data %>%
    select(-ends_with(id_suffix)) %>%
    select(where(~ is.factor(.x) | is.character(.x))) %>%
    names()

  options(width = 120)
  capture.output(
    {
      cat("The following id variables are removed from this summary:\n")
      print(.data %>% select(ends_with(id_suffix)) %>% names())
      cat("\n")
      print(my_skim_fun(.data, -ends_with(id_suffix)))
      cat("\n")
      cat("--- counts for factor and character variables ---")
      for (v in vars) {
        summarise_factor(v)
      }
    },
    file = path,
    append = FALSE
  )
}
