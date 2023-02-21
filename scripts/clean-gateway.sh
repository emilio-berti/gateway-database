#!/bin/bash

# usage: clean-gateway inputfile outputfile
# inputfile is the filename of the raw dataset from https://doi.org/10.25829/idiv.283-3-756
# outfile is the filename you want the output to be saved to

input=$1
output=$2

# replace ',' in with ';' when between two double quotes (")
awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", ";", $i) } 1' $input > temp-no-semi.csv
# remove double quotes (")
tr -d '"' < temp-no-semi.csv > temp-no-quotes.csv
# remove multiple spaces
tr -s " " < temp-no-quotes.csv > temp-no-spaces.csv
# all characters to lowercase
tr '[:upper:]' '[:lower:]' < temp-no-spaces.csv > $output
# remove all temporary files
rm -f temp-*
