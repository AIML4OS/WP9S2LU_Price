# List of required packages
required_packages <- c(
  "mlr3",
  "mlr3verse",
  "mlr3learners",
  "mlr3fselect",
  "mlr3tuning",
  "mlr3mbo",
  "mlr3misc",
  "mlr3pipelines",
  "ranger",
  "xgboost",
  "paradox",
  "tidyr",
  "R6",
  "dplyr",
  "igraph")


# Install any missing packages
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if (length(missing_packages)) {
  install.packages(missing_packages)
}

# Load all packages
invisible(lapply(required_packages, library, character.only = TRUE))
