suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(testthat))
library(readxl)

load_data <- function(sheet, skip) {
  d <- suppressMessages(
    read_xlsx(
      "newdata/tagus/PredatorPrey\ Data\ Tagus\ by\ site_original.xlsx",
      sheet = sheet,
      skip = skip
    )
  )
  return (d)
}

# load food webs ----------
sheets <- paste0("T", 1:30)
d <- lapply(sheets, function(s) {
  i <- 0 
  d <- load_data(s, skip = i)
  while (!grepl("pred", names(d)[1], ignore.case = TRUE) && i < 10) {
    i <- i + 1
    d <- load_data(s, skip = i)
  }
  ans <- d |> 
    transmute(
      res.taxonomy = PreyName,
      con.taxonomy = PredName,
      foodweb.name = s
    )
  return (ans)
})
d <- d |> 
  bind_rows() |> 
  drop_na()

test_that(
  "All foodwebs loaded",
  expect_identical(sheets, d |> pull(foodweb.name) |> unique())
)

# add coordinates ---------
# I georeferenced this in QGIS
xy <- tribble(
  ~foodweb.name, ~longitude, ~latitude,
  "T1",-8.97297672897837,38.9573133084067,
  "T2",-9.00512841029311,38.9201620141859,
  "T3",-9.01212518091295,38.8969458723949,
  "T4",-9.02134952855499,38.8779096247879,
  "T5",-9.06414973828951,38.8486443203579,
  "T6",-9.08052091682146,38.8121869062134,
  "T7",-9.0199249916435,38.7631561443505,
  "T8",-9.03897984883436,38.7713180260136,
  "T9",-9.06581238834891,38.7781793011163,
  "T11",-9.07682241178218,38.7514490356864,
  "T12",-9.02923734282108,38.7981153646694,
  "T10",-9.08871039823383,38.7809277077206,
  "T13",-8.97837160462802,38.7811349715975,
  "T14",-8.99735236168596,38.7657798149807,
  "T15",-8.99146307287867,38.7540358938209,
  "T16",-9.02757260864617,38.7306190997507,
  "T17",-9.06084052578456,38.7007842580265,
  "T18",-9.09383329052985,38.6728710354661,
  "T19",-9.09820147477547,38.7131264724348,
  "T20",-9.12154610396268,38.7000725327111,
  "T21",-9.17056673797215,38.685717393192,
  "T22",-9.20415301057062,38.6826285083101,
  "T23",-9.23291391817252,38.68600489753,
  "T24",-9.25895003170188,38.6898290878821,
  "T25",-9.28694532711192,38.6451932002888,
  "T28",-9.35132339379454,38.6675977249797,
  "T29",-9.37941346779921,38.6771228459819,
  "T26",-9.29041509933042,38.6249160419427,
  "T27",-9.27164045655869,38.6087314766762,
  "T30",-9.40045614559487,38.6899786472565
)
d <- d |> 
  left_join(xy, by = "foodweb.name") |> 
  mutate(
    ecosystem.type = "marine",
    geographic.location = "Tagus estuary (Lisboa)"
  )

d |> write_csv("newdata/tagus.csv")
