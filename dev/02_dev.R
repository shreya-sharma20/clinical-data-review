# Building a Prod-Ready, Robust Shiny Application.
#
# Keep track of development steps here.

## Dependencies ----
## Amend DESCRIPTION with dependencies read from package code parsing
## install.packages('attachment') # if needed.
# attachment::att_amend_desc()

## Add modules ----
## Create a module infrastructure in R/
# golem::add_module(name = "explorer", with_test = TRUE)  # Phase 2
# golem::add_module(name = "compare", with_test = TRUE)   # Phase 3

## Add helper functions ----
## Creates fct_* and utils_*
# golem::add_fct("load_data", with_test = TRUE)       # Phase 2
# golem::add_fct("summarize_data", with_test = TRUE)  # Phase 2
# golem::add_fct("compare_data", with_test = TRUE)    # Phase 3

## Tests ----
## Add one line by test you want to create
# usethis::use_test("app")

## Documentation ----
## Vignette ----
# (not needed for this project)

## CI ----
## The workflow lives in .github/workflows/R-CMD-check.yaml
