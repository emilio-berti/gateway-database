#!/bin/bash

function usage { cat << EOF
USAGE
    bash pipeline.sh

DESCRIPTION
    Create the new version of the GATEWAy database

OPTIONS
   --aggregate             aggregate lifestages
                            defaults to: no

    --clean                 does EVERYTHING
                            defaults to: no

    --add-new-data          add new datasets
                            defaults to: no
                            this is used by the database maintainers when needed

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

    --aggregate)
      aggregate=yes
      shift
      ;;

    --clean)
      clean=yes
      shift
      ;;

    --add-new-data)
      add=yes
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

# if [[ $verbose == yes ]]
# then
#   cat << EOF
# EOF
# fi

bold=$(tput bold)
normal=$(tput sgr0)

echo ""
echo " ${bold}===== Creating GATEWAy v.2.0 =====${normal} "
echo ""

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
if [[ $clean == yes ]] || [[ ! -e "steps/.newdata" ]] && [[ $add == yes ]]
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
  python3 scripts/harmonize-taxonomy.py &&
  touch steps/.gbif
else
  echo "   - GBIF already queried"
fi

# --------------------------------------
# add new data
# --------------------------------------
if [[ $clean == yes ]] || [[ ! -e "steps/.combined" ]]
then
  echo "   - Add new data"
  Rscript --vanilla scripts/combine.R \
  data/gateway-cleaned.csv &&
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
cp data/gateway-harmonized.csv data/gateway-v.2.0.csv
echo "   - New dataset is: ${bold}data/gateway-v.2.0.csv${normal}"

# --------------------------------------
# summary tables for website
# --------------------------------------

if [[ $clean == yes ]] || [[ ! -e "steps/.summarized" ]]
then
  echo "   - Summary Tables"
  Rscript --vanilla scripts/summarize.R \
  data/gateway-v.2.0.csv &&
  touch steps/.summarized
else
  echo "   - Summary tables already created"
fi

# --------------------------------------
# final summary
# --------------------------------------
echo "   - Summary:"
fw=$(cat data/gateway-harmonized.csv | cut -d ',' -f 44 | sort | uniq | wc -l)
n=$(wc -l data/gateway-harmonized.csv | cut -d ' ' -f 1)
echo "    -- $fw unique food webs"
echo "    -- $n unique interactions"

echo ""
echo " ================================== "
echo ""
