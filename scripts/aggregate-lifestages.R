library(tidyverse)
library(testthat)
options(readr.show_progress = FALSE)

#' @param df data.frame, gateway filtered for one foodweb.
#' @return data.frame, same as df but with aggregated lifestages.
aggregate_lifestage <- function(d) {
  
  sp <- d |> 
    select(res.taxonomy, res.lifestage, res.mass.mean.g.,
           con.taxonomy, con.lifestage, con.mass.mean.g.)
  
  # bind by rows res and cons ----------
  sp <- bind_rows(
    sp |> 
      select(contains("res")) |> 
      rename_with(~gsub("res[.]", "", .x)) |> 
      mutate(role = "res"),
    sp |> 
      select(contains("con")) |> 
      rename_with(~gsub("con[.]", "", .x)) |> 
      mutate(role = "con")
  ) |> 
    replace_na(list(lifestage = "omitted")) |> 
    rename(mass = mass.mean.g.) |> 
    mutate(mass = ifelse(mass < 0, NA, mass))
  
  # assign adult if adult present ----------
  # this is a bit of a complicated massage.
  # It needs a map() to vectorize within groups.
  # map() assures that 'lifestage' is treated as vector 
  # and '.x' as the row entry.
  # I left an example before the real massaging.
  example <- tibble(
    x = c("A", "A", "A", "B", "B"),
    y = c("a", "b", "c", "b", "c")
  ) |> 
    group_by(x) |>
    mutate(y = map_chr(y, ~ifelse(any(y == "a"), "a", .x)))
  
  sp <- sp |> 
    group_by(taxonomy, role) |> 
    mutate(lifestage = map_chr(lifestage, 
                               ~ifelse(any(lifestage == "adult"),
                                       "adult", .x))) |> 
    ungroup()
  
  # average mass and drop duplicates ----------
  sp <- sp |> 
    group_by(taxonomy, lifestage, role) |> 
    add_tally() |> 
    mutate(mass = mean(mass, na.rm = TRUE)) |> 
    mutate(mass = ifelse(is.nan(mass), NA, mass)) |> 
    ungroup() |> 
    distinct_all()
  
  adults <- sp |> filter(lifestage == "adults")
  
  # retain most common lifestage only --------
  non_adults <- sp |> 
    filter(lifestage != "adults") |> 
    group_by(taxonomy, role) |> 
    arrange(desc(n)) |> 
    filter(lifestage != "omitted") |> 
    slice_head(n = 1) |> 
    ungroup() |> 
    anti_join(adults, by = c("taxonomy", "role"))

  omitted <- sp |> 
    filter(lifestage == "omitted") |> 
    anti_join(non_adults, by = c("taxonomy", "role")) |> 
    anti_join(adults, by = c("taxonomy", "role"))

  sp <- bind_rows(
    adults,
    non_adults,
    omitted
  )
  
  test_that(
    "Consumers match",
    testthat::expect_identical(
      d |> pull(con.taxonomy) |> unique() |> sort(),
      sp |> filter(role == "con") |> pull(taxonomy) |> unique() |> sort()
    )
  )
  test_that(
    "Resources match",
    testthat::expect_identical(
      d |> pull(res.taxonomy) |> unique() |> sort(),
      sp |> filter(role == "res") |> pull(taxonomy) |> unique() |> sort()
    )
  )
  
  sp <- d |> 
    select(-res.lifestage, -res.mass.mean.g.,
           -con.lifestage, -con.mass.mean.g.) |> 
    left_join(
      sp |> 
        filter(role == "res") |> 
        select(-role, -n) |> 
        rename_with(~paste0("res.", .x)),
      by = "res.taxonomy"
    ) |> 
    left_join(
      sp |> 
        filter(role == "con") |> 
        select(-role, -n) |> 
        rename_with(~paste0("con.", .x)),
      by = "con.taxonomy"
    )
  
  test_that(
    "Same shape",
    testthat::expect_identical(nrow(sp), nrow(d))
  )
  test_that(
    "Resources match",
    testthat::expect_identical(
      d |> pull(res.taxonomy) |> unique() |> sort(),
      sp |> pull(res.taxonomy) |> unique() |> sort()
    )
  )
  test_that(
    "Consumers match",
    testthat::expect_identical(
      d |> pull(con.taxonomy) |> unique() |> sort(),
      sp |> pull(con.taxonomy) |> unique() |> sort()
    )
  )
  return (sp)
}

data_dir <- "data" # /data/idiv_brose/warming-gateway

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  db <- args[1]
  outdir <- args[2]
  message("Database file: ", db)
  message("Output directory: ", outdir)
} else {
  db <- file.path(data_dir, "gateway-harmonized.csv")
  outdir <- file.path(data_dir, "fws")
}
stopifnot("db" %in% ls())
stopifnot("outdir" %in% ls())

gw <- read_csv(db, show_col_types = FALSE)

fws <- gw |> 
  pull(foodweb.name) |> 
  unique() |> 
  sort()

for (fw in fws) {
  message(fw)
  d <- gw |> filter(foodweb.name == fw)
  aggr <- aggregate_lifestage(d)
  aggr |> write_csv(file.path(outdir, paste0(fw, ".csv")))
}  
