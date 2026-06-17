#### This is a script to add condition occurrences representing the diagnosis of
# renal cell carcinoma (RCC) to the condition_occurrence table in the duckdb database

# get the column names from the cohort table in the duckdb database
connection <- connect(connectionDetails)
cohort_columns <- querySql(
  connection,
  "SELECT column_name
   FROM information_schema.columns
   WHERE table_name = 'cohort';"
)$column_name
print(cohort_columns)

# Random sample of 10% of subject_ids from the cohort table
subject_ids <- querySql(
  connection,
  "SELECT DISTINCT subject_id
   FROM cohort
   USING SAMPLE 10 PERCENT;"
)$subject_id

# now use these subject_ids to pull the corresponding rows from the person table in the duckdb database
ids_sql <- paste(subject_ids, collapse = ", ")

person_sample <- querySql(
  connection,
  paste0("SELECT * FROM person WHERE person_id IN (", ids_sql, ");")
)

person_sample <- person_sample |>
  dplyr::mutate(dplyr::across(dplyr::contains("id"), as.integer))

# Random sample of 20 rows from the condition_occurrence table
# to use as a template for the data we will add to the condition_occurrence table
condition_occ_sample <- querySql(
  connection,
  "SELECT * 
   FROM condition_occurrence 
   LIMIT 20;"
)

# add a column to the person sample dataframe title 'condition_start_date' and populate it with
# a random date between 2000-01-01 and 2020-12-31
set.seed(123) # for reproducibility
person_sample <- person_sample |>
  dplyr::mutate(
    condition_start_date = as.Date("2000-01-01") +
      sample(0:7670, n(), replace = TRUE)
  )


# add a column to the person sample dataframe titled 'condition_start_datetime' , populate it with the same date
# as 'condition_start_date' but in a datetime format (i.e. with time component)
person_sample <- person_sample |>
  dplyr::mutate(
    condition_start_datetime = as.POSIXct(condition_start_date)
  )
# add two colums, 'condition_end_date' and 'condition_end_datetime'
# and populate them with the same date as 'condition_start_date' but with a random number
#  days added to it, between 30 and 365 days
person_sample <- person_sample |>
  dplyr::mutate(
    condition_end_date = condition_start_date +
      sample(30:365, n(), replace = TRUE),
    condition_end_datetime = as.POSIXct(condition_end_date)
  )
# add a column to the person_sample dataframe titled 'condition_concept_id'
# and populate it with the value 198985
person_sample <- person_sample |>
  dplyr::mutate(condition_concept_id = 198985)
# add a column to the person_sample dataframe titled 'condition_occurrence_id'
# and populate it with a unique integer value that larger than and not a duplicate of any value
# in the 'condition_occurrence_id' column of the condition_occurrence table of the duckdb database
max_condition_occurrence_id <- querySql(
  connection,
  "SELECT MAX(condition_occurrence_id) AS max_id FROM condition_occurrence;"
)$max_id
person_sample <- person_sample |>
  dplyr::mutate(
    condition_occurrence_id = max_condition_occurrence_id + row_number()
  )
# add a column to the person_sample dataframe titled 'condition_type_concept_id' and populate it with the value 38000200
person_sample <- person_sample |>
  dplyr::mutate(condition_type_concept_id = 38000200)
# drop the columns from the person_sample dataframe that are not in the empty_condition_occurrence dataframe
person_sample <- person_sample |>
  dplyr::select(dplyr::any_of(names(condition_occ_sample)))
# write the person_sample dataframe to the condition_occurrence table in the duckdb database
# using the existing databaseConnector connection and appending the data to the table
dbWriteTable(
  connection,
  "condition_occurrence",
  person_sample,
  append = TRUE
)

# now count the number of rows in the condition ocurrence table that have a condition_concept_id of 198985 and a condition_type_concept_id of 38000200
count_rows <- querySql(
  connection,
  "SELECT COUNT(*) AS count
   FROM condition_occurrence
   WHERE condition_concept_id = 198985
   AND condition_type_concept_id = 38000200;"
)$count
print(count_rows)

querySql(
  connection,
  "SELECT count(*) FROM condition_occurrence;"
)
