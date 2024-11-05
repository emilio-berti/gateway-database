suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(rgbif))
options(readr.show_progress = FALSE)

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  datadir <- args[1]
} else {
  datadir <- "data"
}

original <- read_csv(
  file.path(datadir, "checklist.csv"),
  show_col_types = FALSE
) |> 
  pull(species) |> 
  unique() |> 
  sort()

parsed <- gsub("class |order |family |genus |sp[.]$|[(]juv[)]", "", original)
parsed <- str_to_sentence(parsed)
parsed <- gsub(" $", "", parsed)

slices <- seq(1, ceiling(length(parsed) / 1e3) * 1e3, by = 1e3)
backbone <- as.list(rep(NA, length(slices)))
for(i in seq_along(slices)) {
  start <- slices[i]
  if (i == length(slices)) {
    end <- length(parsed)
  } else {
    end <- slices[i + 1] - 1 
  }
  backbone[[i]] <- name_backbone_checklist(
    parsed[start:end],
    genus = parsed[start:end]
  ) |> 
    transmute(
      original = original[start:end],
      parsed = parsed[start:end],
      gbif = canonicalName,
      rank = tolower(rank),
      key = usageKey,
      status = tolower(status),
      match = tolower(matchType)
    )
}
backbone <- backbone |> bind_rows()
backbone |> write_csv(file.path(datadir, "taxonomy.csv"))
