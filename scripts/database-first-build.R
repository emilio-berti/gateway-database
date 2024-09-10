library(tidyverse)
library(DBI)
# library(RPostgres)
library(rpostgis)
library(sf)
library(leaflet)

d <- read_csv("data/gateway-v.2.0.csv", show_col_types = FALSE)
con <- RPostgreSQL::dbConnect(
  "PostgreSQL",
  host = "localhost",
  dbname = "gateway",
  user = "postgres"
)
pgPostGIS(con)  # check for PostGIS extensions

ecosystems <- d |> 
  group_by(ecosystem.type) |> 
  tally() |> 
  rownames_to_column(var = "ID") |> 
  rename_with(\(x) gsub("[.]", "_", x))

dbWriteTable(con, "ecosystems", ecosystems, row.names = FALSE)

studies <- d |> 
  select(study.site, foodweb.name) |> 
  distinct_all() |> 
  group_by(study.site) |> 
  tally(name = "n_foodwebs") |> 
  ungroup() |> 
  distinct_all() |> 
  left_join(
    d |> 
      group_by(study.site) |> 
      tally() |> 
      ungroup(),
    by = "study.site"
  ) |> 
  rownames_to_column(var = "ID") |> 
  rename_with(\(x) gsub("[.]", "_", x))

dbWriteTable(con, "studies", studies)

foodwebs <- d |> 
  group_by(foodweb.name, ecosystem.type, longitude, latitude) |> 
  tally() |> 
  ungroup() |> 
  rownames_to_column(var = "ID") |> 
  rename_with(\(x) gsub("[.]", "_", x)) |> 
  left_join(
    ecosystems |> 
      transmute(ecosystem_type, ecosystem_ID = ID), 
    by = "ecosystem_type"
  ) |> 
  select(-ecosystem_type) |> 
  st_as_sf(coords = c("longitude", "latitude"), crs = st_crs(4326))

# dbWriteTable(con, "foodwebs", foodwebs)
pgWriteGeom(
  con,
  "foodwebs",
  foodwebs
)

# dbReadDataFrame(con, "foodwebs")
# pgListGeom(con)
fw <- pgGetGeom(con, "foodwebs")
eco <- dbSendQuery(con, "SELECT * FROM ecosystems")
eco <- dbFetch(eco)

dbDisconnect(con)

pal <- hcl.colors(max(fw$ecosystem_ID), "Set 2")[as.numeric(fw$ecosystem_ID)]
fw |> 
  left_join(eco, join_by(ecosystem_ID == ID)) |> 
  select(-contains("n.")) |> 
  leaflet() |> 
  addCircles(radius = 1e4, color = pal) |>
  addTiles(urlTemplate = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Terrain_Base/MapServer/tile/{z}/{y}/{x}") 
