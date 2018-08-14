#!/bin/bash
# Some magic so we can find sourced scripts if this script is called from outside its own directory
absolute_path=$(readlink -e -- "${BASH_SOURCE[0]}" && echo x) && absolute_path=${absolute_path%?x}
dir=$(dirname -- "$absolute_path" && echo x) && dir=${dir%?x}
file=$(basename -- "$absolute_path" && echo x) && file=${file%?x}

LOC=$1
: ${LOC:-"."}
if [ ! -d $LOC ]; then
    echo "Usage is: ./multiLogParse.sh /path/to/logs/ [optional prefix string for output files]"
else
    echo "Using directory $LOC as LOC"
fi
PREFIX=$2

for i in $LOC/request.*; do
	$dir/requestToUsage.sh $i $PREFIX
done
