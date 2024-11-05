suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(terra))
terraOptions(progress = 0)

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  datadir <- args[1]
} else {
  datadir <- "data"
}

d <- read_csv(file.path(datadir, "v.2.0", "foodwebs.csv"), show_col_types = FALSE)
p <- d |> vect(geom = c("decimalLongitude", "decimalLatitude"), crs = "EPSG:4326")
writeVector(p, file.path(datadir, "v.2.0", "foodwebs.shp"), overwrite = TRUE)
