# This is the R script to build the cohorts from the JSON created from Atlas. This is from a Capr fork
# "issue125-decompile" that allows for decompiling the JSON to R code.
# I just copied the file from the github repo, and then source them later.

library(SqlRender)
library(DatabaseConnector)
library(Capr)
library(jsonvalidate)
library(CirceR)
library(CohortGenerator)
library(dplyr)
# remotes::install_github("ohdsi/Capr", "issue125-decompile")
# I just copied the jsonToCapr function from the Capr repo, and then source it later.
# This is the function that takes the JSON and converts it to 'capr' R code that can be used to build the cohorts.

# create the database connection details
absoluteFilePath <- file.path(getwd(), "data", "synthetic.duckdb")

## filepath for the non VA version
absoluteFilePath <- "/Users/michaelconlin/synthetic_OMOP_data/duckdb_data/synthetic.duckdb"

########## Change for VA version ##############
connectionDetails <- createConnectionDetails(
        dbms = "duckdb",
        server = absoluteFilePath
)
cdmDatabaseSchema <- "main"
cohortDatabaseSchema <- "main"
########## End change for VA version ##############

connection <- connect(connectionDetails)
# test the connection
querySql(connection, "SELECT COUNT(*) FROM person;")

# get the table names in the database using the DatabaseConnector function
tableNames <- getTableNames(connection)
print(tableNames)

#
# build the cohorts
# load up the jsonToCapr function (already done)
# source("/Users/michaelconlin/arb_hades_code/jsonToCapr.R", echo = FALSE)

# source("/Users/michaelconlin/arb_hades_code/jsonToCapr_cohort_build.r", echo = TRUE)

# Now source the R scripts to build the cohorts
# ARBS cohort
source("/Users/michaelconlin/arb_hades_code/cohort_build_arbs.r", echo = TRUE)

# ARBS control cohort
source(
        "/Users/michaelconlin/arb_hades_code/cohort_build_arbs_control.r",
        echo = TRUE
)

# ARBS outcome cohort
source(
        "/Users/michaelconlin/arb_hades_code/cohort_build_arbs_outcome.r",
        echo = TRUE
)

# use makeCohortSet (from Capr) to create the cohort definition set
# VA version
cohortsToCreate <- do.call(
        makeCohortSet,
        c(cohortDef, controlCohortDef, outcomeCohortDef)
) |>
        VaTools::refactor()
# non VA version
cohortsToCreate <- makeCohortSet(cohortDef, controlCohortDef, outcomeCohortDef)
# set the cohort table names
cohortTableNames <- CohortGenerator::getCohortTableNames(
        cohortTable = "cohort"
)

### create the cohort tables in the database ###
# First create the empty cohort tables in the database
CohortGenerator::createCohortTables(
        connectionDetails = connectionDetails,
        cohortDatabaseSchema = cohortDatabaseSchema,
        cohortTableNames = cohortTableNames
)
# generate the cohort and populate the tables in the database
cohortsGenerated <- CohortGenerator::generateCohortSet(
        connectionDetails = connectionDetails,
        cdmDatabaseSchema = cdmDatabaseSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        cohortTableNames = cohortTableNames,
        cohortDefinitionSet = cohortsToCreate
)

cohortCounts <- CohortGenerator::getCohortCounts(
        connectionDetails = connectionDetails,
        cohortDatabaseSchema = cohortDatabaseSchema,
        cohortTable = cohortTableNames$cohortTable
) |>
        inner_join(
                cohortsToCreate |> select(cohortId, cohortName),
                by = "cohortId"
        ) |>
        arrange(cohortId)

##### test the cohort generation with just the outcome cohort, to make sure it works before trying to generate all three cohorts together #####

cohortsGenerated <- CohortGenerator::generateCohortSet(
        connectionDetails = connectionDetails,
        cdmDatabaseSchema = cdmDatabaseSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        cohortTableNames = cohortTableNames,
        cohortDefinitionSet = cohortsToCreate %>% filter(cohortId == 3)
)
