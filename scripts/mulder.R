suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(testthat))
library(readxl)

load_data <- function(sheet) {
  d <- read_xlsx(
    "newdata/mulder/Who eats whom in our ten soil food webs.xlsx",
    sheet = sheet
  )
  ans <- d |> 
    transmute(
      res.taxonomy = Resource,
      con.taxonomy = Consumer,
      res.mass = 10 ^ Mres,
      con.mass = 10 ^ Mconsumer,
      foodweb.name = paste("A", sheet, sep = "-")
    )
  return (ans)
}

# interactions ---------
sheets <- as.character(243:252)
d <- lapply(sheets, load_data)
d <- d |> 
  bind_rows() |> 
  distinct_all()

# environmental data --------
env <- read_xlsx(
  "newdata/mulder/Who eats whom in our ten soil food webs.xlsx",
  sheet = "Table S1"
)
xy <- env |> 
  transmute(
    foodweb.name = `Site number`,
    longitude = `Degrees E` + `Minutes E` / 60,
    latitude = `Degrees N` + `Minutes N` / 60,
    ecosystem.type = "terrestrial belowground",
    geographic.location = "Dutch agroecosystems"
  )

test_that(
  "All sites in geo table",
  expect_identical(
    sort(unique(d[["foodweb.name"]])),
    sort(unique(xy[["foodweb.name"]]))
  )
)
test_that(
  "All sites in interaction table",
  expect_identical(
    sort(unique(xy[["foodweb.name"]])),
    sort(unique(d[["foodweb.name"]]))
  )
)

# write interactions to table ----------
d <- d |> left_join(xy, by = "foodweb.name")
d |> write_csv("newdata/mulder.csv")

# literature sources ------
suppressMessages(
  sources <- read_xlsx(
    "newdata/mulder/Who eats whom in our ten soil food webs.xlsx",
    sheet = "Literature",
    col_names = FALSE
  ) |> 
    pull(`...1`)
)

writeLines(sources, "newdata/mulder-sources.txt")
