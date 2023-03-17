suppressPackageStartupMessages(library(tidyverse))
options(readr.show_progress = FALSE)

data_dir <- "data"

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  db <- args[1]
} else {
  db <- file.path(data_dir, "data/gateway-v.2.0.csv")
}
stopifnot("db" %in% ls())

d <- read_csv(db, show_col_types = FALSE)

n_eco_type <- d |> 
  group_by(ecosystem.type) |> 
  tally(name = "n interactions") |> 
  left_join(
    d |> 
      select(foodweb.name, ecosystem.type) |> 
      distinct_all() |> 
      group_by(ecosystem.type) |> 
      tally(name = "n foodwebs"),
    by = "ecosystem.type"
  ) |> 
  left_join(
    d |> 
      select(ecosystem.type, res.taxonomy, con.taxonomy) |> 
      pivot_longer(
        cols = contains("taxonomy"),
        values_to = "species",
        names_to = "role"
      ) |> 
      select(-role) |> 
      distinct_all() |> 
      group_by(ecosystem.type) |> 
      tally(name = "n species"),
    by = "ecosystem.type"
  )

n_fw <- d |> 
  group_by(foodweb.name) |> 
  tally(name = "n interactions") |> 
  left_join(
    d |> 
      select(foodweb.name, res.taxonomy, con.taxonomy) |> 
      pivot_longer(
        cols = contains("taxonomy"),
        values_to = "species",
        names_to = "role"
      ) |> 
      select(-role) |> 
      distinct_all() |> 
      group_by(foodweb.name) |> 
      tally(name = "n species"),
    by = "foodweb.name"
  )

n_eco_type <- n_eco_type |> arrange(ecosystem.type)
n_fw <- n_fw |> arrange(foodweb.name)

n_eco_type |> write_csv("data/summary-ecosystems.csv")
n_fw |> write_csv("data/summary-foodwebs.csv")