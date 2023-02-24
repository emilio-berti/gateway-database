suppressPackageStartupMessages(library(tidyverse))
options(readr.show_progress = FALSE)

# read files --------
gw <- read_csv("data/gateway-cleaned.csv", show_col_types = FALSE)
files <- list.files("newdata", pattern = ".csv", full.names = TRUE)
d <- lapply(files, read_csv, show_col_types = FALSE)
d <- d |> bind_rows()

# get unique names --------
gw <- union(gw[["res.taxonomy"]], gw[["con.taxonomy"]])
d <- union(d[["res.taxonomy"]], d[["con.taxonomy"]])

# save to table --------
sp <- tibble(species = union(gw, d))
sp |> write_csv("data/checklist.csv")
