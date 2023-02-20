library('tidyverse')
library('yaml')
library('here')
library('glue')

# create action functions ----

## create comment function ----
comment <- function(...){
  list_comments <- list(...)
  comments <- map(list_comments, ~paste0("## ", ., " ##"))
  comments
}


## create function to convert comment "actions" in a yaml string into proper comments
convert_comment_actions <-function(yaml.txt){
  yaml.txt %>%
    str_replace_all("\\\n(\\s*)\\'\\'\\:(\\s*)\\'", "\n\\1")  %>%
    #str_replace_all("\\\n(\\s*)\\'", "\n\\1") %>%
    str_replace_all("([^\\'])\\\n(\\s*)\\#\\#", "\\1\n\n\\2\\#\\#") %>%
    str_replace_all("\\#\\#\\'\\\n", "\n")
}


## generic action function ----
action <- function(
  name,
  run,
  arguments=NULL,
  needs=NULL,
  highly_sensitive=NULL,
  moderately_sensitive=NULL,
  ... # other arguments / options for special action types
){

  outputs <- list(
    highly_sensitive = highly_sensitive,
    moderately_sensitive = moderately_sensitive
  )
  outputs[sapply(outputs, is.null)] <- NULL

  action <- list(
    run = paste(c(run, arguments), collapse=" "),
    needs = needs,
    outputs = outputs,
    ... = ...
  )
  action[sapply(action, is.null)] <- NULL

  action_list <- list(name = action)
  names(action_list) <- name

  action_list
}


## core study def function ----

action_extract_sus <- function(method, n){

  needs_list <- list()
  if(as.integer(n) > 1) needs_list <-list(glue("extract_sus_method{method}_admission{n-1}"))

  action(
    name = glue("extract_sus_method{method}_admission{n}"),
    run = glue("cohortextractor:latest generate_cohort --study-definition study_definition_sus --output-file output/admissions/sus_method{method}_admission{n}.csv.gz --param admission_number={n} --param admission_method={method}"),
    needs = needs_list,
    highly_sensitive = lst(
      csv = glue("output/admissions/sus_method{method}_admission{n}.csv.gz")
    )
  )
}

# specify project ----

## defaults ----
defaults_list <- lst(
  version = "3.0",
  expectations= lst(population_size=1000L)
)

## actions ----
actions_list <- splice(

  comment("# # # # # # # # # # # # # # # # # # #",
          "DO NOT EDIT project.yaml DIRECTLY",
          "This file is created by create-project.R",
          "Edit and run create-project.R to update the project.yaml",
          "# # # # # # # # # # # # # # # # # # #"
          ),

  comment("# # # # # # # # # # # # # # # # # # #", "Extract admission date", "# # # # # # # # # # # # # # # # # # #"),


  action_extract_sus("A", 1),
  action_extract_sus("A", 2),
  action_extract_sus("A", 3),
  action_extract_sus("A", 4),
  action_extract_sus("A", 5),

  action_extract_sus("B", 1),
  action_extract_sus("B", 2),
  action_extract_sus("B", 3),
  action_extract_sus("B", 4),
  action_extract_sus("B", 5),

  action_extract_sus("C", 1),
  action_extract_sus("C", 2),
  action_extract_sus("C", 3),
  action_extract_sus("C", 4),
  action_extract_sus("C", 5),

  # action_extract_sus("D", 1),
  # action_extract_sus("D", 2),
  # action_extract_sus("D", 3),
  # action_extract_sus("D", 4),
  # action_extract_sus("D", 5),
  #
  # action_extract_sus("E", 1),
  # action_extract_sus("E", 2),
  # action_extract_sus("E", 3),
  # action_extract_sus("E", 4),
  # action_extract_sus("E", 5),


comment("# # # # # # # # # # # # # # # # # # #", "End", "# # # # # # # # # # # # # # # # # # #")

)




project_list <- splice(
  defaults_list,
  list(actions = actions_list)
)

## convert list to yaml, reformat comments and whitespace ----
thisproject <- as.yaml(project_list, indent=2) %>%
  # convert comment actions to comments
  convert_comment_actions() %>%
  # add one blank line before level 1 and level 2 keys
  str_replace_all("\\\n(\\w)", "\n\n\\1") %>%
  str_replace_all("\\\n\\s\\s(\\w)", "\n\n  \\1")


# if running via opensafely, check that the project on disk is the same as the project created here:
if (Sys.getenv("OPENSAFELY_BACKEND") %in% c("expectations", "tpp")){

  thisprojectsplit <- str_split(thisproject, "\n")
  currentproject <- readLines(here("project.yaml"))

  stopifnot("project.yaml is not up-to-date with create-project.R.  Run create-project.R before running further actions." = identical(thisprojectsplit, currentproject))

# if running manually, output new project as normal
} else if (Sys.getenv("OPENSAFELY_BACKEND") %in% c("")){

## output to file ----
  writeLines(thisproject, here("project.yaml"))
#yaml::write_yaml(project_list, file =here("project.yaml"))

# fail if backend not recognised
} else {
  stop("Backend not recognised")
}

