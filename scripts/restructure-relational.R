suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(testthat))
options(readr.show_progress = FALSE)

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  datadir <- args[1]
} else {
  datadir <- "data/v.2.0"
}

# read tables and standardize NAs ----------
species <- read_csv(
  file.path(datadir, "species.csv"), show_col_types = FALSE
) |> 
  mutate(across(everything(), ~ifelse(
    grepl("^na$", .x, ignore.case = TRUE), NA, .x
  ))) |> 
  select(-taxonomicLevel) |>
  mutate(communityID = ID) |>
  select(-"ID")

test_that(
  "Rows are unique",
  expect_equal(
    species |> nrow(),
    species |> distinct_all() |> nrow()
  )
)

interactions <- read_csv(
  file.path(datadir, "interactions.csv"), show_col_types = FALSE
) |> 
  mutate(across(everything(), ~ifelse(
    grepl("^na$", .x, ignore.case = TRUE), NA, .x
  ))) |>
  mutate(interactionID = ID) |>
  select(-"ID")

test_that(
  "Rows are unique",
  expect_equal(
    interactions |> nrow(),
    interactions |> distinct_all() |> nrow()
  )
)

foodwebs <- read_csv(
  file.path(datadir, "foodwebs.csv"), show_col_types = FALSE
) |> 
  mutate(across(everything(), ~ifelse(
    grepl("^na$", .x, ignore.case = TRUE), NA, .x
  ))) |> 
  mutate(foodwebID = ID) |> 
  relocate(foodwebID, .before = "ID") |> 
  select(-ID)

test_that(
  "Rows are unique",
  expect_equal(
    foodwebs |> nrow(),
    foodwebs |> distinct_all() |> nrow()
  )
)

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
  group_by(
    acceptedTaxonName,
    vernacularName,
    taxonRank,
    taxonomicStatus
  ) |> 
  mutate(taxonID = cur_group_id()) |> 
  ungroup() |> 
  mutate(across(contains("ID"), ~as.numeric(.x))) |>
  relocate(taxonID, .before = 1)

# in the old database, get information to know in which food webs species occur
communities <- interactions |>
  pivot_longer(
    cols = c("resourceID", "consumerID"),
    values_to = "communityID"
  ) |>
  distinct_all() |>
  left_join(communities, by = "communityID") |>
  select(
    "communityID", "foodwebID", 
    "metabolicTypeID", "movementTypeID", "lifeStageID",
    "sizeMethodID", "referenceID",
    "lowestMass", "highestMass", "meanMass",
    "shortestLength", "longestLength", "meanLength"
  ) |>
  mutate(biomass = -999) |>
  distinct_all() |>
  left_join(species |> select(communityID, taxonID), by = "communityID") |>
  relocate(taxonID, .after = communityID) |>
  arrange(foodwebID, taxonID, communityID) |>
  rowid_to_column(var = "ID") |>
  relocate(ID, .before = 1)

interactions <- interactions |>
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
  relocate(interactionRemarks, .after = "interactionMethodID") |>
  relocate(interactionID, .before = 1)

species <- species |> 
  select(
    "taxonID", "acceptedTaxonName",
    "taxonRank", "taxonomicStatus",
    "vernacularName"
  ) |>
  distinct_all()

test_that("taxa are unique", 
  expect_equal(max(table(species$taxonID)), 1)
)

test_that(
  "Rows are unique",
  expect_equal(
    communities |> nrow(),
    communities |> distinct_all() |> nrow()
  )
)

test_that(
  "Rows are unique",
  expect_equal(
    interactions |> nrow(),
    interactions |> distinct_all() |> nrow()
  )
)

test_that(
  "Dimensions are kept",
  expect_equal(
    interactions |> nrow(),
    read_csv(file.path(datadir, "GATEWAy-v.2.0.csv")) |> nrow()
  )
)

write_csv(foodwebs, file.path(datadir, "foodwebs.csv"))
write_csv(species, file.path(datadir, "species.csv"))
write_csv(communities, file.path(datadir, "communities.csv"))
write_csv(interactions, file.path(datadir, "interactions.csv"))
write_csv(references, file.path(datadir, "references.csv"))
write_csv(life_stages, file.path(datadir, "lifestages.csv"))
write_csv(movement_types, file.path(datadir, "movement_types.csv"))
write_csv(metabolic_types, file.path(datadir, "metabolic_types.csv"))
write_csv(interaction_types, file.path(datadir, "interaction_types.csv"))
write_csv(interaction_methods, file.path(datadir, "interaction_methods.csv"))
write_csv(size_methods, file.path(datadir, "size_methods.csv"))
