GATEWAy database from v.1 to v.2
================
Emilio Berti

# Change log

## V.2.0

1.  Removed problematic characters from fields: - `,` replaced with `;`
    when within `"`. - `"` removed. - Multiple spaces trimmed to one
    space. - Convert all uppercase letters to lowercase.
2.  Add data from Mulder et al. (*citation needed*).
3.  Add data from Vinagre et al. (*citation_needed*).
4.  Harmonize taxonomy
5.  Rename columns following the Darwin Core standard:
    <http://rs.tdwg.org/dwc/terms.htm#4>.

Additionally, tables and shapefiles are created to be inserted into a
PostGIS database to feed the website server.

# SQL database

I re-structured the GATEWAy database into \<…\> tables:

1.  <span style="color:blue">Foodwebs</span>
2.  <span style="color:green">Species</span>
3.  <span style="color:red">Interactions</span>

The old database was a single csv file. I colored the columns of this
file with the same color of the tables above. The symbol =\> show
columns that have been renamed. E.g., `A` =\> `B` means `A` was renamed
to `B`, following DarwinCore standards:
<http://rs.tdwg.org/dwc/terms.htm#4>. All column names have been
converted to camelCase. Strike-through columns have been dropped.

<!-- foodwebs -->

<span style="color:blue">foodwebName</span><br> <span
style="color:blue">longitude =\> decimalLongitude</span><br> <span
style="color:blue">latitude =\> decimalLatitude</span> <span
style="color:blue">ecosystemType</span><br> <span
style="color:blue">geographicLocation =\> locality</span><br> <span
style="color:blue">studySite</span><br> <span
style="color:blue">altitude =\> verbatimElevation</span><br> <span
style="color:blue">depth =\> verbatimDepth</span><br> <span
style="color:blue">samplingTime</span><br> <span
style="color:blue">sampling.start.year =\>
EarliestDateCollected</span><br> <span
style="color:blue">sampling.end.year =\> LatestDateCollected</span><br>
<!-- species --> ~~key~~<br> <span style="color:green">taxonID</span>,
identified by the combination of all fields related to species<br> <span
style="color:green">taxonomy =\> acceptedTaxonName</span><br> <span
style="color:green">common =\> vernacularName</span><br> <span
style="color:green">lifeStage</span><br> <span
style="color:green">metabolic.type =\> metabolicType</span><br> <span
style="color:green">movement.type =\> movementType</span><br> <span
style="color:green">mass.min.g. =\> lowestMass</span>, in grams<br>
<span style="color:green">mass.max.g. =\> highestMass</span>, in
grams<br> <span style="color:green">mass.mean.g. =\> meanMass</span>, in
grams<br> <span style="color:green">length.min.cm. =\>
shortestLength</span>, in cm<br> <span
style="color:green">length.max.cm. =\> longestLength</span>, in cm<br>
<span style="color:green">length.mean.cm. =\> meanLength</span>, in
cm<br> <span style="color:green">size.method =\> sizeMethod</span><br>
<span style="color:green">size.citation =\> sizeReference</span><br>
<span style="color:green">taxonomy.status =\> taxonomicStatus</span><br>
<span style="color:green">taxonomy.level =\> taxonRank</span><br>
<!-- interactions --> ~~autoid~~<br> <span
style="color:red">interactionID</span>, identified by unique taxonID and
foodwebName<br> <span style="color:red">interactionType</span><br> <span
style="color:red">interactionDimensionality</span><br> <span
style="color:red">link.methodology =\> interactionMethod</span><br>
<span style="color:red">link.citation =\>
interactionReference</span><br> <span
style="color:red">interaction.classification =\>
basisOfRecord</span><br> <span style="color:red">link.citation =\>
interactionReference</span><br> <span style="color:red">notes =\>
interactionRemarks</span><br>

<img title="relations" alt="relations" src="figures/relations.png" width="100%">

# Pipeline

To run the whole pipeline at once:

``` bash
bash pipeline.sh
```

This runs (in order):

1.  Clean v.1.0 for encoding/parsing errors:
    [scripts/clean-gateway](scripts/clean-gateway).
2.  Process new data to add to the database:
    [scripts/mulder.R](scripts/mulder.R) and
    [scripts/tagus.R](scripts/tagus.R).
3.  Extract species names:
    [scripts/extract-species-names.R](scripts/extract-species-names.R).
4.  Query the species names against GBIF:
    [harmonize-taxonomy.py](harmonize-taxonomy.py).
5.  Combine v.1.0 with new data: [scripts/combine.R](scripts/combine.R).
6.  Harmonize taxonomy of the database:
    [harmonize-taxonomy.R](harmonize-taxonomy.R).
7.  Saves the new database as `gateway-v.2.0.csv`.
8.  Rename fields and split table into relational tables:
    [scripts/relational.R](scripts/relational.R).

Some of this steps can take some time. To avoid re-running already
completed steps, once the step is completed successfully an hidden
(empty) file is added to the [steps](steps) folder. Steps that have such
files will not be re-ran. You can re-run the whole pipeline from scratch
specifying the option `--clean`:

``` bash
bash pipeline.sh --clean
```

To see available options and usage: `bash pipeline.sh --help`.

# PostGRES database

## Create database

``` bash
psql -U postgres
CREATE DATABASE econetlab;
\c econetlab;
CREATE EXTENSION postgis;
```

## Foodwebs table

``` bash
CREATE TABLE foodwebs(
  foodwebID INTEGER PRIMARY KEY,
  foodwebName  VARCHAR,
  decimalLongitude  REAL,
  decimalLatitude  REAL,
  ecosystemType  VARCHAR,
  geographicLocation  VARCHAR,
  studySite  VARCHAR,
  verbatimElevation  REAL,
  verbatimDepth  REAL,
  samplingTime  VARCHAR,
  EarliestDateCollected  VARCHAR,
  LatestDateCollected  VARCHAR
);

COPY foodwebs FROM '/home/eb97ziwi/gateway-database/data/foodwebs.csv' CSV HEADER;
```

## Species table

``` bash
CREATE TABLE species(
  ID INTEGER PRIMARY KEY,
  acceptedTaxonName VARCHAR,
  taxonRank VARCHAR,
  taxonomicStatus VARCHAR,
  vernacularName VARCHAR,
  taxonomicLevel VARCHAR,
  lifeStage VARCHAR,
  metabolicType VARCHAR,
  movementType VARCHAR,
  lowestMass REAL,
  highestMass REAL,
  meanMass REAL,
  shortestLength REAL,
  longestLength REAL,
  meanLength REAL,
  sizeMethod VARCHAR,
  sizeReference VARCHAR
);

COPY species FROM '/home/eb97ziwi/gateway-database/data/species.csv' CSV HEADER;
```

## Interaction table

``` bash
CREATE TABLE interactions(
  ID INTEGER PRIMARY KEY,
  foodwebID INTEGER,
  resourceID INTEGER,
  consumerID INTEGER,
  interactionType VARCHAR,
  interactionDimensionality VARCHAR,
  interactionMethod VARCHAR,
  interactionReference VARCHAR,
  interactionRemarks VARCHAR,
  basisOfRecord VARCHAR
);

COPY interactions FROM '/home/eb97ziwi/gateway-database/data/interactions.csv' CSV HEADER;
```

## Table schema

For <https::/dbdiagram.io/d>

``` bash
Table foodwebs {
  ID INTEGER [primary key]
  foodwebName  VARCHAR
  decimalLongitude  REAL
  decimalLatitude  REAL
  ecosystemType  VARCHAR
  geographicLocation  VARCHAR
  studySite  VARCHAR
  verbatimElevation  REAL
  verbatimDepth  REAL
  samplingTime  VARCHAR
  EarliestDateCollected  VARCHAR
  LatestDateCollected  VARCHAR
}

Table species {
  ID INTEGER [primary key]
  acceptedTaxonName VARCHAR
  taxonRank VARCHAR
  taxonomicStatus VARCHAR
  vernacularName VARCHAR
  taxonomicLevel VARCHAR
  lifeStage VARCHAR
  metabolicType VARCHAR
  movementType VARCHAR
  lowestMass REAL
  highestMass REAL
  meanMass REAL
  shortestLength REAL
  longestLength REAL
  meanLength REAL
  sizeMethod VARCHAR
  sizeReference VARCHAR
}

Table interactions {
  ID INTEGER [primary key]
  foodwebID INTEGER
  resourceID INTEGER
  consumerID INTEGER
  interactionType VARCHAR
  interactionDimensionality VARCHAR
  interactionMethod VARCHAR
  interactionReference VARCHAR
  interactionRemarks VARCHAR
  basisOfRecord VARCHAR
}

Ref: foodwebs.ID < interactions.foodwebID
Ref: species.ID < interactions.consumerID
Ref: species.ID < interactions.resourceID
```

# Generate this HTML Readme

``` bash
Rscript --vanilla -e "rmarkdown::render('README.Rmd')"
pandoc -s --toc -c readme.css README.md -o README.html --metadata title="GATEWAy Database"
```
