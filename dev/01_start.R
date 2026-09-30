# Building a Prod-Ready, Robust Shiny Application.
#
# README: each step of the dev files is optional, and you don't have to
# fill every dev scripts before getting started.
# 01_start.R should be filled at start.
# 02_dev.R should be used to keep track of your development during the project.
# 03_deploy.R should be used once you need to deploy your app.

## Fill the DESCRIPTION ----
## Add meta data about your application and set some default {golem} options
golem::fill_desc(
  pkg_name = "adamreview",
  pkg_title = "ADaM Dataset Explorer: Review CDISC ADaM Datasets in a Shiny App",
  pkg_description = "A small golem-based Shiny application for exploring CDISC ADaM datasets, comparing them with diffdf.",
  authors = person("Shreya", "Sharma", email = "sshreya319@gmail.com", role = c("aut", "cre")),
  repo_url = "https://github.com/shreya-sharma20/clinical-data-review",
  pkg_version = "0.0.0.9000",
  set_options = TRUE
)

## Install the required dev dependencies ----
golem::install_dev_deps()

## Create Common Files ----
usethis::use_mit_license("Shreya Sharma")
usethis::use_testthat(3)

## Use git ----
## (Done by the repo owner; this project never commits on its own.)

## Init Testing Infrastructure ----
golem::use_recommended_tests()
