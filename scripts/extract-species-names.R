suppressPackageStartupMessages(library(tidyverse))
options(readr.show_progress = FALSE)

# read files --------
gw <- read_csv("data/gateway-cleaned.csv", show_col_types = FALSE)
mulder <- read_csv("newdata/mulder.csv", show_col_types = FALSE)

# get unique names --------
gw <- union(gw[["res.taxonomy"]], gw[["con.taxonomy"]])
mulder <- union(mulder[["res.taxonomy"]], mulder[["con.taxonomy"]])

# save to table --------
sp <- tibble(species = union(gw, mulder))
sp |> write_csv("data/checklist.csv")