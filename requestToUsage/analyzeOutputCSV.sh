#!/bin/bash
set -u -o pipefail

absolute_path=$(readlink -e -- "${BASH_SOURCE[0]}" && echo x) && absolute_path=${absolute_path%?x}
dir=$(dirname -- "$absolute_path" && echo x) && dir=${dir%?x}
file=$(basename -- "$absolute_path" && echo x) && file=${file%?x}

out () { echo "$@"; }
out 'Number of arguments seen when sourced'
out $#
out First arg
echo "$1"
# All args
echo "$0"
echo $@
# This file can be run or sourced by another script like requestToUsage.sh
failwhale () {
  # Function accepts a message to print when triggering an early exit not due to failure
  errcode=$?
  # No sense trapping ourselves
  trap - EXIT
  MESSAGE=${1:-}
  ERROR_MESSAGE="Attempted ${BASH_COMMAND} and exited with ${errcode} at line ${BASH_LINENO[0]}"
  [ ! $errcode -eq 0 ] && MESSAGE=${ERROR_MESSAGE}
  echo "${MESSAGE}"

  # This line allows the script to be sourced without killing the shell with `exit` on failure
  return $errcode 2> /dev/null || exit $errcode
}
trap failwhale INT ERR EXIT

main () {
  required_args
  ordered_arg_array
  parse_files
}

required_args () {
  # If sourced the number of arguments is reduced
  #[[ "$0" != "$BASH_SOURCE" ]] && required=0 || required=1
  required=1
  # Number of required arguments
  if ! [  "$#" -ge $required ]; then
    echo "Usage is: $file LOGDATE.csv [LOGDATE2.csv]"
    echo "Also supports globs: $file 2018*.csv"
    echo "$@"
  else
    echo "$@"
  fi
}

ordered_arg_array () {
  # Make array global
  declare -ga filearray
  #IFS=$'\n' read -d '' -a filearray < <(printf '%s\n' "${BASH_ARGV[@]}"|tac)
  shift
  IFS=$'\n' read -d '' -a filearray < <(printf '%s\n' $@)
}

parse_files () {
  for eachfile in ${filearray[@]}; do
    if [ ! -f $eachfile ] || [ ! "${eachfile##*.}" == 'csv' ]; then
      echo "File not found or not a CSV file: ${eachfile}"
      continue
    fi
    analyze_csv $eachfile
  done
}
get_dates () {
    # Reads output and assigns into an array for easier indexing below
    # Here !/^0/ ignores the 0,..,=SUM line provided for spreadsheet lovers
    DATES_IN_FILE=($(awk -F',' '!/^0/ {print $1}' $OUTPUT | cut -c1-8 | uniq))
}

analyze_csv () {
    # Set/reset OUTPUT to file being examined
    local OUTPUT
    OUTPUT=$1
    get_dates
    parse_each_date_total $OUTPUT
    parse_file_total $OUTPUT
}

calculate_gigabytes () {
  # from https://unix.stackexchange.com/a/374877
  echo "$1" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }'
}

parse_each_date_total () {
# Takes a file and loops over the dates detected
for eachday in "${DATES_IN_FILE[@]}"; do
  local DAY_TOTAL
  DAY_TOTAL=0
  # Don't need !/^0/  here because -v day="^$eachday" limits to lines beginning with valid days
  for requestsize in $(awk -v day="^$eachday" -F',' '{ if ( $0 ~ day){ print $NF }}' $OUTPUT); do
    let "DAY_TOTAL += requestsize";
  done
  echo "$eachday had $(calculate_gigabytes $DAY_TOTAL) transferred"
done
}

parse_file_total () {
  # Here !/^0/ ignores the 0,..,=SUM line provided for spreadsheet lovers
  local TOTAL
  TOTAL=0
  for request in $(awk -F',' '!/^0/ { print $NF }' $OUTPUT ); do
    let "TOTAL += request";
  done
  local FILE_TOTAL
  FILE_TOTAL=$(calculate_gigabytes $TOTAL)

  echo "Approximate data transfer total in $OUTPUT between ${DATES_IN_FILE[0]} and ${DATES_IN_FILE[@]: -1} is $FILE_TOTAL"
}

main "$@"
