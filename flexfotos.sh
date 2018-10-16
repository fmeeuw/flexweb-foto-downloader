#!/usr/bin/env bash

# FlexFotos.sh for fetching fotos from flexweb app like https://mijn.kmnkindenco.nl./
# Requires curl for performing http requests and jq for parsing json.
function checkArgs() {
    if [ -z "${username}" ]
    then
        echo "Missing or empty username."
        display_usage
    fi
    if [ -z "${password}" ]
    then
        echo "Missing or empty password."
        display_usage
    fi
}
function display_usage() {
    echo "usage: flexfotos -u username -p password -t [target_dir] -s [start_year] -e [end_year]"
    exit 1
}


script_dir=$(cd "$(dirname "$0")" && pwd -P)
cookie_file="${script_dir}/session.cookie"
target_dir=./target
start_year=2014
end_year=2020

# Parse and get script arguments
while getopts ":u:p:t:s:e:" opt; do
  case "${opt}" in
    u)
       username=$OPTARG
       ;;
    p)
       password=$OPTARG
       ;;
    t)
       target_dir=$OPTARG
       ;;
    s)
       start_year=$OPTARG
       ;;
    e)
       end_year=$OPTARG
       ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

checkArgs




# Remove old session cookie if exists
echo "Removing old cookie file stored at ${cookie_file}, if any."
rm -f ${cookie_file}

# Login and save the session cookie
echo "Logging in to https://mijn.kmnkindenco.nl, saving session cookie to ${cookie_file}."
curl 'https://mijn.kmnkindenco.nl/login/login' \
 --cookie-jar ${cookie_file} \
 --data-urlencode "username=${username}" \
 --data-urlencode "password=${password}" \
 --data-urlencode "role=7" \

echo "Navigating to ${target_dir}, creating directories if needed."
mkdir -p ${target_dir}
cd ${target_dir}
for ((year=start_year; year < end_year; year++)); do
    for month in {1..12}; do
        # Set working directory to current year/month.
        wd="${year}-${month}"
        mkdir -p ${wd}
        cd ${wd}


        # Retrieve the fotos for the specific year and month, and also download them.
        echo "Retrieving fotos for ${year}-${month}, storing them at ${target_dir}/${wd}."
        curl 'https://mijn.kmnkindenco.nl/ouder/fotoalbum/standaardalbum' \
         --cookie ${cookie_file} \
         --data-urlencode "year=${year}" \
         --data-urlencode "month=${month}" | \
         jq ".FOTOS | .[]" | \
         xargs -L1 -I'{}' curl 'https://mijn.kmnkindenco.nl/ouder/media/download/media/{}' \
         --cookie ${cookie_file} \
         -o "${year}-${month}-{}.jpg"

         cd ..
    done
done


