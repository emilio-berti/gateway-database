#!/bin/bash

function usage { cat << EOF
USAGE
    bash pipeline.sh

DESCRIPTION
    Create the new version of the GATEWAy database

OPTIONS

    --clean                 does EVERYTHING
                            defaults to: no

    --verbose | -v          adds verbose output
                            defaults to: no
EOF
}

clean=no
verbose=no

for arg in "$@"
do
  case "$arg" in
    -\?|--help)
      usage
      exit
      ;;

    --clean)
      clean=yes
      shift
      ;;

    -v|--verbose)
      verbose=yes
      shift
      ;;

    --)
      shift
      break
      ;;

    -*)
      echo "unrecognized option: $1" >&2
      exit 1
      ;;

    *)
      break
      ;;
  esac
done

if [[ $verbose == yes ]]
then
  cat << EOF
  clean=$clean

EOF
fi

bold=$(tput bold)
normal=$(tput sgr0)

echo ""
echo " ${bold}========== GATEWAy v.2.0 ==========${normal} "

# --------------------------------------
# unzip v.1.0
# --------------------------------------
if [[ ! -e data/283_2_FoodWebDataBase_2018_12_10.csv ]]
then
  echo "   - Unzipping v.1.0"
  cd data
  unzip v.1.0.zip
  cd ..
else 
  echo "   - Already unzipped"
fi

# --------------------------------------
# string manipulations of v.1.0
# --------------------------------------
if [[ $clean == yes ]] || [[ ! -e "steps/.cleaned" ]]
then
  echo "   - Cleaning strings"
  cd data
  bash ../scripts/clean-gateway.sh 283_2_FoodWebDataBase_2018_12_10.csv gateway-cleaned.csv &&
  touch ../steps/.cleaned
  cd ..
else
  echo "   - Already cleaned"
fi

# --------------------------------------
# process new data
# --------------------------------------
if [[ $clean == yes ]] || [[ ! -e "steps/.newdata" ]]
then
  echo "   - Process new data"
  Rscript --vanilla scripts/mulder.R &&
  Rscript --vanilla scripts/tagus.R &&
  touch steps/.newdata
else
  echo "   - New data already processed"
fi

if [[ $clean == yes ]] || [[ ! -e "steps/.names" ]]
then
  echo "   - Extracting species names"
  Rscript --vanilla scripts/extract-species-names.R &&
  touch steps/.names
else
  echo "   - Names already extracted"
fi

# --------------------------------------
# query against GBIF
# --------------------------------------
if [[ $clean == yes ]] || [[ ! -e "steps/.gbif" ]]
then
  echo "   - Querying GBIF"
  Rscript --vanilla scripts/taxonomic-backbone.R data &&
  touch steps/.gbif
  cp data/taxonomy.csv data/v.2.0/taxonomy.csv
else
  echo "   - GBIF already queried"
fi

# --------------------------------------
# add new data
# --------------------------------------
if [[ $clean == yes ]] || [[ ! -e "steps/.combined" ]]
then
  echo "   - Add new data"
  Rscript --vanilla scripts/combine.R data/gateway-cleaned.csv &&
  touch steps/.combined
else
  echo "   - New data already added"
fi

# --------------------------------------
# harmonize taxonomy
# --------------------------------------
if [[ $clean == yes ]] || [[ ! -e "steps/.harmonized" ]]
then
  echo "   - Harmonize taxonomy"
  Rscript --vanilla scripts/harmonize-taxonomy.R \
    data/gateway-combined.csv data/taxonomy.csv &&
  touch steps/.harmonized
else
  echo "   - Taxonomy already harmonized"
fi

# --------------------------------------
# rename as v.2.0
# --------------------------------------
cp data/gateway-harmonized.csv data/v.2.0/GATEWAy-v.2.0.csv
echo "   - New dataset is: ${bold}data/v.2.0/GATEWAy-v.2.0.csv${normal}"

# --------------------------------------
# rename and split tables for website
# --------------------------------------
if [[ $clean == yes ]] || [[ ! -e "steps/.renamed" ]]
then
  echo "   - Rename fields and split tables"
  Rscript --vanilla scripts/relational.R data/gateway-v.2.0.csv &&
  touch steps/.renamed
else
  echo "   - Fields already renamed and tables split"

fi

# --------------------------------------
# restructure database for website
# --------------------------------------
if [[ $clean == yes ]] || [[ ! -e "steps/.restructured" ]]
then
  echo "   - Restructure database for SQL"
  Rscript --vanilla scripts/restructure-relational.R data &&
  touch steps/.restructured
else
  echo "   - Tables already restructures"

fi

# --------------------------------------
# shapefiles for website
# --------------------------------------
if [[ $clean == yes ]] || [[ ! -e "steps/.shapefiled" ]]
then
  echo "   - Create shapefile"
  Rscript --vanilla scripts/shapefiles.R data &&
  touch steps/.shapefiled
else
  echo "   - Shapefiles already created"
fi

# --------------------------------------
# summary
# --------------------------------------
echo "  - Summary:"
fw=$(wc -l data/v.2.0/foodwebs.csv | cut -d ' ' -f 1)
n=$(wc -l data/v.2.0/interactions.csv | cut -d ' ' -f 1)
echo "      -- $fw unique food webs"
echo "      -- $n unique interactions"

echo " ================================================== "
echo ""
