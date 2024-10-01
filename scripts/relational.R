suppressPackageStartupMessages(library(tidyverse))
options(readr.show_progress = FALSE)

data_dir <- "data"

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  db <- args[1]
} else {
  db <- file.path(data_dir, "gateway-v.2.0.csv")
}
datapath <- strsplit(db, "/")[[1]]
datapath <- paste(datapath[1 : (length(datapath) - 1)], collapse = "/")
stopifnot("db" %in% ls())

db <- read_csv(db, show_col_types = FALSE)
db$foodweb.name <- ifelse(
  grepl("grand caricaie marsh", db$foodweb.name),  # foodweb name sampled in multiple ecosystems
  paste(db$foodweb.name, db$ecosystem.type, sep = " - "),
  db$foodweb.name
)
db$foodweb.name <- ifelse(
  grepl("carpinteria", db$foodweb.name),  # foodweb name sampled in multiple ecosystems
  paste(db$foodweb.name, db$ecosystem.type, sep = " - "),
  db$foodweb.name
)

# Foodweb table --------------
lookup <- c(
  foodwebName = "foodweb.name",
  decimalLongitude = "longitude",
  decimalLatitude = "latitude",
  ecosystemType = "ecosystem.type",
  geographicLocation = "geographic.location",
  studySite = "study.site",
  verbatimElevation = "altitude",
  verbatimDepth = "depth",
  samplingTime = "sampling.time",
  EarliestDateCollected = "sampling.start.year",
  LatestDateCollected = "sampling.end.year"
)

sites <- db |> 
  select(all_of(lookup)) |> 
  distinct_all() |> 
  mutate(
    verbatimElevation = ifelse(is.na(verbatimElevation), -9999, verbatimElevation),
    verbatimDepth = ifelse(is.na(verbatimDepth), -9999, verbatimDepth)
  ) |> 
  rownames_to_column(var = "ID") |> 
  relocate("ID", .before = "foodwebName")

sites |> write_csv(file.path(datapath, "sites.csv"))

# Species table ---------------
species <- bind_rows(
  db |> 
    select(matches("res")) |> 
    distinct_all() |> 
    rename_with(~sub("res[.]", "", .x)),
  db |> 
    select(matches("con")) |> 
    distinct_all() |> 
    rename_with(~sub("con[.]", "", .x))
)

lookup <- c(
  acceptedTaxonName = "taxonomy",
  taxonRank = "taxonomy.level",
  taxonomicStatus = "taxonomy.status",
  vernacularName = "common",
  taxonomicLevel = "taxonomy.level",
  lifeStage = "lifestage",
  metabolicType = "metabolic.type",
  movementType = "movement.type",
  lowestMass = "mass.min.g.",
  highestMass = "mass.max.g.",
  meanMass = "mass.mean.g.",
  shortestLength = "length.min.cm.",
  longestLength = "length.max.cm.",
  meanLength = "length.mean.cm.",
  sizeMethod = "size.method",
  sizeReference = "size.citation"
)

species <- species |> 
  select(all_of(lookup)) |> 
  distinct_all() |> 
  rownames_to_column(var = "ID") |> 
  mutate(across(where(is.numeric), ~ifelse(is.na(.x), -9999, .x)))

species |> write_csv(file.path(datapath, "species.csv"))

# test taxonID are unique
if (
  (species |> 
    select(-"taxonID") |> 
    distinct_all() |> 
    group_by_all() |> 
    tally() |> 
    pull(n) |> 
    max()) > 1
  ) {
  stop("taxonID is not uniquely identified.")
}

# Interaction table ----------
lookup <- c(
  interactionType = "interaction.type",
  interactionDimensionality = "interaction.dimensionality",
  interactionMethod = "link.methodology",
  interactionReference = "link.citation",
  interactionReference = "link.citation",
  interactionRemarks = "notes",
  foodwebName = "foodweb.name",
  decimalLongitude = "longitude",
  decimalLatitude = "latitude",
  ecosystemType = "ecosystem.type",
  geographicLocation = "geographic.location",
  studySite = "study.site",
  verbatimElevation = "altitude",
  verbatimDepth = "depth",
  samplingTime = "sampling.time",
  EarliestDateCollected = "sampling.start.year",
  LatestDateCollected = "sampling.end.year",
  acceptedTaxonName = "taxonomy",
  taxonRank = "taxonomy.level",
  taxonomicStatus = "taxonomy.status",
  vernacularName = "common",
  taxonomicLevel = "taxonomy.level",
  lifeStage = "lifestage",
  metabolicType = "metabolic.type",
  movementType = "movement.type",
  lowestMass = "mass.min.g.",
  highestMass = "mass.max.g.",
  meanMass = "mass.mean.g.",
  shortestLength = "length.min.cm.",
  longestLength = "length.max.cm.",
  meanLength = "length.mean.cm.",
  sizeMethod = "size.method",
  sizeReference = "size.citation",
  basisOfRecord = "interaction.classification"
)

interaction_res <- db |> 
  select(-matches("con[.]")) |> 
  rename_with(~sub("res[.]", "", .x)) |> 
  select(any_of(lookup)) |>
  mutate(across(where(is.numeric), ~ifelse(is.na(.x), -9999, .x))) |> 
  left_join(species)

interaction_con <- db |> 
  select(-matches("re[.]")) |> 
  rename_with(~sub("con[.]", "", .x)) |> 
  select(any_of(lookup)) |> 
  mutate(across(where(is.numeric), ~ifelse(is.na(.x), -9999, .x))) |> 
  left_join(species)

interaction_con |> filter(is.na(ID)) |> select(ID, acceptedTaxonName)

stopifnot(nrow(interaction_res) == nrow(interaction_con))
stopifnot(all(interaction_res$foodwebName == interaction_con$foodwebName))
stopifnot(
  identical(
    interaction_res |> select(contains("interaction|basis")),
    interaction_con |> select(contains("interaction|basis"))
  )
)

interactions <- bind_cols(
  interaction_res |> 
    select(
      foodwebName,
      resourceID = ID,
      matches("interaction|basis")
    ),
  interaction_con |> 
    transmute(consumerID = ID)
) |> 
  rownames_to_column(var = "ID") |> 
  relocate("ID", .before = "foodwebName") |> 
  relocate("consumerID", .after = "resourceID") |> 
  mutate(basisOfRecord = ifelse(basisOfRecord == "ibi", "individual", "group")) |> 
  left_join(
    foodwebs |> transmute(foodwebID = ID, foodwebName),
    by = "foodwebName",
    multiple = "all"
  ) |> 
  relocate("foodwebID", .before = "foodwebName") |> 
  select(-foodwebName) |> 
  mutate(across(where(is.numeric), ~ifelse(is.na(.x), -9999, .x)))

stopifnot(nrow(db) == nrow(interactions))

interactions |> write_csv(file.path(datapath, "interactions.csv"))
