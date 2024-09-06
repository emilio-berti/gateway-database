suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(testthat))
options(readr.show_progress = FALSE)

data_dir <- "data"

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  db <- args[1]
} else {
  db <- file.path(data_dir, "gateway-cleaned.csv")
}
stopifnot("db" %in% ls())

db <- read_csv(db, show_col_types = FALSE)
files <- list.files("newdata", pattern = "csv", full.names = TRUE)
message("    - ", length(files), " new datasets to add")
newdata <- lapply(files, "read_csv", show_col_types = FALSE)
newdata <- newdata |> 
  bind_rows() |> 
  mutate(study.site = geographic.location)

db <- bind_rows(db, newdata)
db |> write_csv(file.path(data_dir, "gateway-combined.csv"))
