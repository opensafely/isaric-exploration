
library('tidyverse')
library('lubridate')
library('glue')
library('fuzzyjoin')
library('data.table')



test_isaric <-
  tibble(
    patient_id = c(1,1,1,2,2,3,3,3),
    admission_date = as.Date(c("2020-01-05", "2020-02-05", "2020-03-05", "2020-01-05", "2020-02-05","2020-01-05", "2020-02-05", "2020-03-05"))
  )

test_susA <-
  tibble(
    patient_id = c(1,1,1,2,2,3,3),
    admission_date = as.Date(c("2020-01-05", "2020-02-04", "2020-03-06", "2020-01-01", "2020-02-05", "2020-02-05", "2020-02-06"))
  ) %>%
  mutate(
    admission_date_susA= admission_date,
    method= "A"
  )


## potentially lower memory version:
function_fuzzy_join <- function(mx, my){
  joined <- fuzzy_left_join(
    mx,
    my,
    by = c("patient_id", "admission_date"),
    match_fun = list(
      patient_id = `==`,
      admission_date = function(x,y){x>=y-1 & x<=y+1}
    )
  )
  renamed <- rename(joined, patient_id=patient_id.x, admission_date=admission_date.x)
  select(renamed, -patient_id.y, -admission_date.y)
}

test_joined_fuzzy <-
  function_fuzzy_join(
    test_isaric,
    test_susA
  )


function_nonequi_join <- function(mx, my){
  joined <- setDT(my)[
    ,
    c("admission_date_pre", "admission_date_post") := list(admission_date-1, admission_date+1)
  ][
    setDT(mx),
    .(patient_id, admission_date = i.admission_date, admission_date_susA, method),
    on = .(patient_id, admission_date_pre<=admission_date, admission_date_post>=admission_date)
  ]

  as_tibble(joined)
}


test_joined_nonequi <-
  function_nonequi_join(
    test_isaric,
    test_susA
  )

identical(test_joined_fuzzy, test_joined_nonequi)
str(test_joined_fuzzy)
str(test_joined_nonequi)
