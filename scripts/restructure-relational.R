suppressPackageStartupMessages(library(tidyverse))
options(readr.show_progress = FALSE)

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  datadir <- args[1]
} else {
  datadir <- "data"
}

# read tables and standardize NAs ----------
species <- read_csv(
  file.path(datadir, "species.csv"), show_col_types = FALSE
) |> 
  mutate(across(everything(), ~ifelse(
    grepl("^na$", .x, ignore.case = TRUE), NA, .x
  ))) |> 
  select(-taxonomicLevel)

interactions <- read_csv(
  file.path(datadir, "interactions.csv"), show_col_types = FALSE
) |> 
  mutate(across(everything(), ~ifelse(
    grepl("^na$", .x, ignore.case = TRUE), NA, .x
  )))

foodwebs <- read_csv(
  file.path(datadir, "foodwebs.csv"), show_col_types = FALSE
) |> 
  mutate(across(everything(), ~ifelse(
    grepl("^na$", .x, ignore.case = TRUE), NA, .x
  )))

# reference table ------
references <- tibble(
  reference = c(
    species |> pull(sizeReference) |> unique(),
    interactions |> pull(interactionReference) |> unique()
  ) |> 
    unique()
) |> 
  distinct(reference) |> 
  arrange(reference) |> 
  rownames_to_column(var = "referenceID")

# lifestage table ----------
life_stages <- tibble(
  lifeStage = species |> pull(lifeStage) |> unique()
) |>
  distinct(lifeStage) |> 
  arrange(lifeStage) |> 
  rownames_to_column(var = "lifeStageID")

# size methods ---------
size_methods <- tibble(
  sizeMethod = species |> pull(sizeMethod) |> unique()
) |>
  distinct(sizeMethod) |> 
  arrange(sizeMethod) |> 
  rownames_to_column(var = "sizeMethodID")

# movement types --------
movement_types <- tibble(
  movementType = species |> pull(movementType) |> unique()
) |>
  distinct(movementType) |> 
  arrange(movementType) |> 
  rownames_to_column(var = "movementTypeID")

# metabolic types ---------
metabolic_types <- tibble(
  metabolicType = species |> pull(metabolicType) |> unique()
) |>
  distinct(metabolicType) |> 
  arrange(metabolicType) |> 
  rownames_to_column(var = "metabolicTypeID")

# interaction types ----------
interaction_types <- tibble(
  interactionType = interactions |> pull(interactionType) |> unique()
) |>
  distinct(interactionType) |> 
  arrange(interactionType) |> 
  rownames_to_column(var = "interactionTypeID")

# interaction methods -------
interaction_methods <- tibble(
  interactionMethod = interactions |> pull(interactionMethod) |> unique()
) |>
  distinct(interactionMethod) |> 
  arrange(interactionMethod) |> 
  rownames_to_column(var = "interactionMethodID")

# For a similar taxon name, using rank can give to 2 different species IDs.
# Emilio: similar or identical?

# add IDs and drop columns ----------
species <- species |> 
  left_join(
    metabolic_types,
    join_by(metabolicType == metabolicType),
    keep = FALSE
  ) |> 
  select(-metabolicType) |> 
  left_join(
    movement_types,
    join_by(movementType == movementType),
    keep = FALSE
  ) |> 
  select(-movementType) |> 
  left_join(
    life_stages,
    join_by(lifeStage == lifeStage),
    keep = FALSE
  ) |> 
  select(-lifeStage) |> 
  left_join(
    size_methods,
    join_by(sizeMethod == sizeMethod),
    keep = FALSE
  ) |> 
  select(-sizeMethod) |> 
  left_join(
    references,
    join_by(sizeReference == reference),
    keep = FALSE
  ) |> 
  select(-sizeReference)

# when a species has multiple vernacular names, combine them in one cell
# NOTE: it could be better to address cases where one of the entry is na 
# (like 'na, red fox' that should be 'red fox')
# Emilio: I prefer not, as this will modify the original information.
# Vernacular names should be provided by the data collector and not
# inferred.
species <- species |> 
  group_by(acceptedTaxonName) |> 
  mutate(vernacularName = paste(unique(vernacularName), collapse=";")) |> 
  unnest(col = vernacularName) |> 
  ungroup()

communities <- species

species <- species |> 
  select(
    ID,
    acceptedTaxonName,
    vernacularName,
    taxonRank,
    taxonomicStatus
  ) |> 
  group_by(
    acceptedTaxonName,
    vernacularName,
    taxonRank,
    taxonomicStatus
  ) |> 
  mutate(speciesID = cur_group_id()) |> 
  ungroup() |> 
  mutate(across(contains("ID"), ~as.numeric(.x)))

# in the old database, get information to know in which food webs species occur
communities <- bind_rows(
  communities |> 
    left_join(
      interactions |> select(foodwebID, resourceID),
      by = c('ID' = 'resourceID')
    ),
  communities |> 
    left_join(
      interactions |> select(foodwebID, consumerID),
      by = c('ID' = 'consumerID')
    )
)

communities <- communities |> 
  left_join(species) |> 
  select(-ID, -acceptedTaxonName, -taxonRank, -taxonomicStatus, -vernacularName) |> 
  select(
    foodwebID, speciesID, lifeStageID, metabolicTypeID, movementTypeID,
    sizeMethodID, referenceID,
    lowestMass, highestMass, meanMass,
    shortestLength, longestLength, meanLength
  ) |> 
  distinct_all() |> 
  mutate(biomass = -999) |> 
  arrange(foodwebID, speciesID)

interactions <- interactions |>
  left_join(species |> transmute(sID = ID, speciesID), join_by("resourceID" == "sID")) |> 
  mutate(resourceID = speciesID) |> 
  select(-speciesID) |> 
  left_join(species |> transmute(sID = ID, speciesID), join_by("consumerID" == "sID")) |> 
  mutate(consumerID = speciesID) |> 
  select(-speciesID) |> 
  left_join(interaction_types, join_by(interactionType)) |> 
  select(-interactionType) |> 
  left_join(references, by = c('interactionReference' = 'reference')) |> 
  select(-interactionReference) |> 
  left_join(interaction_methods, join_by(interactionMethod)) |> 
  select(-interactionMethod) |> 
  mutate(interactionDimensionality = case_when(
      interactionDimensionality == "2d" ~ 2,
      interactionDimensionality == "3d" ~ 3,
      .default = NA
  )) |> 
  relocate(interactionRemarks, .after = "interactionMethodID")

species <- species |> 
  relocate(speciesID, .before = "ID") |> 
  relocate(vernacularName, .after = "taxonomicStatus") |> 
  select(-ID) |> 
  distinct_all()

stopifnot(
  communities |> distinct_all() |> nrow() == communities |> nrow()
)

stopifnot(
  interactions |> distinct_all() |> nrow() == interactions |> nrow()
)

stopifnot(
  species |> distinct_all() |> nrow() == species |> nrow()
)

write_csv(foodwebs, file.path(datadir, "v.2.0", "foodwebs.csv"))
write_csv(species, file.path(datadir, "v.2.0", "species.csv"))
write_csv(communities, file.path(datadir, "v.2.0", "communities.csv"))
write_csv(interactions, file.path(datadir, "v.2.0", "interactions.csv"))
write_csv(references, file.path(datadir, "v.2.0", "references.csv"))
write_csv(life_stages, file.path(datadir, "v.2.0", "lifestages.csv"))
write_csv(movement_types, file.path(datadir, "v.2.0", "movement_types.csv"))
write_csv(metabolic_types, file.path(datadir, "v.2.0", "metabolic_types.csv"))
write_csv(interaction_types, file.path(datadir, "v.2.0", "interaction_types.csv"))
write_csv(interaction_methods, file.path(datadir, "v.2.0", "interaction_methods.csv"))
write_csv(size_methods, file.path(datadir, "v.2.0", "size_methods.csv"))
