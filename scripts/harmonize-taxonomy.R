suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(testthat))
options(readr.show_progress = FALSE)

data_dir <- "data"

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  db <- args[1]
  taxonomy <- args[2]
} else {
  db <- file.path(data_dir, "gateway-combined.csv")
  taxonomy <- file.path(data_dir, "taxonomy.csv")
}
stopifnot("db" %in% ls())
stopifnot("taxonomy" %in% ls())

db <- read_csv(db, show_col_types = FALSE)
shape <- dim(db)
taxonomy <- suppressMessages(
  taxonomy |> 
    read_csv(show_col_types = FALSE) |> 
    select(-`...1`) |> 
    distinct_all()
)

# count not found ----------
not_found <- taxonomy |> 
  filter(is.na(gbif)) |> 
  distinct_all() |> 
  pull(original) |> 
  length()

message("    - ", not_found, " names not found in GBIF.")

# save changed to summary files ------
taxonomy |> 
  filter(!is.na(gbif), gbif != original) |> 
  distinct_all() |> 
  write_csv(file.path(data_dir, "names-changed.csv"))

taxonomy |> 
  filter(!is.na(gbif)) |> 
  group_by(gbif != original) |> 
  tally() |> 
  write_csv(file.path(data_dir, "tally-changed.csv"))

# reassign gbif to gateway ---------
db <- db |> 
  select(-res.taxonomy.level, -con.taxonomy.level) |> 
  left_join(
    taxonomy |> 
      transmute(res.taxonomy = original,
                res.gbif = gbif,
                res.taxonomy.level = rank,
                res.taxonomy.status = status,
                res.key = key),
    by = "res.taxonomy"
  ) |> 
  left_join(
      taxonomy |> 
        transmute(con.taxonomy = original,
                  con.gbif = gbif,
                  con.taxonomy.level = rank,
                  con.taxonomy.status = status,
                  con.key = key),
    by = "con.taxonomy"
  )

stopifnot(any(!is.na(db[["res.taxonomy.status"]])))
stopifnot(any(!is.na(db[["res.taxonomy.level"]])))
stopifnot(any(!is.na(db[["con.taxonomy.status"]])))
stopifnot(any(!is.na(db[["con.taxonomy.level"]])))
test_that(
  "Same rows after adding gbif",
  expect_equal(shape[1], nrow(db))
)
db <- db |> 
  mutate(res.taxonomy = ifelse(is.na(res.gbif),
                               res.taxonomy,
                               res.gbif),
         con.taxonomy = ifelse(is.na(con.gbif),
                               con.taxonomy,
                               con.gbif)) |> 
  select(-res.gbif, -con.gbif)

stopifnot(any(!is.na(db[["res.taxonomy"]])))
stopifnot(any(!is.na(db[["con.taxonomy"]])))
test_that(
  "Same rows after assigning gbif",
  expect_equal(shape[1], nrow(db))
)
test_that(
  "Same columns + 4 for status and key",
  expect_equal(shape[2] + 4, ncol(db))
)

db |> write_csv(file.path(data_dir, "gateway-harmonized.csv"))
