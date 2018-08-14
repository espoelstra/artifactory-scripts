#!/bin/bash
# Some magic so we can find sourced scripts if this script is called from outside its own directory
absolute_path=$(readlink -e -- "${BASH_SOURCE[0]}" && echo x) && absolute_path=${absolute_path%?x}
dir=$(dirname -- "$absolute_path" && echo x) && dir=${dir%?x}
file=$(basename -- "$absolute_path" && echo x) && file=${file%?x}

FILE=$1
if [ ! -f $FILE ]; then
    echo "Correct usage is: $file request.log [optional prefix string for output file]"
fi
PREFIX=$2

# Gets first 8 characters of first timestamp ie YYYYMMDD
OUTPUT=${PREFIX:+${PREFIX}-}$(head -c 8 $FILE).csv

# Replaces | with ,
# Skips any 0-byte requests
# gsub should exist in most implementations of awk
awk '{ gsub(/[|]/, ",") }; !/,0$/' $FILE > $OUTPUT

echo "Successfully reformatted $FILE to CSV as $OUTPUT"

# This script finds the dates in the $OUTPUT file and calculates the transfer per day and overall 
echo "Passing analyzeOutputCSV.sh $OUTPUT"
set -- $OUTPUT
. $dir/analyzeOutputCSV.sh $(readlink -f $OUTPUT)

echo "0,0,0,0,0,0,0,0,0,0,=SUM(J:J)/(1024^3)" >> $OUTPUT
echo "Added calculation line."
echo "Open $OUTPUT in excel or a similar spreadsheet program"
