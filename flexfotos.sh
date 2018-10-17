#!/usr/bin/env bash

# FlexFotos.sh for fetching fotos from flexweb app like https://mijn.kmnkindenco.nl./
# Requires curl for performing http requests and jq for parsing json.

# This application requires cUrl for retrieving the images, jq for parsing json and exiftool for adding exif metadata.
function checkDependencies() {
    for program in curl jq exiftool
    do
        hash "${program}" 2>/dev/null || { echo >&2 "${program} is required for this script, but it's not installed."; exit 1; }
    done
}

function checkArgs() {
    if [ -z "${username}" ]
    then
        echo >&2 "Missing or empty username."
        display_usage
    fi
    if [ -z "${password}" ]
    then
        echo >&2 "Missing or empty password."
        display_usage
    fi
}
function display_usage() {
    echo "usage: flexfotos -u username -p password -t [target_dir] -s [start_year] -e [end_year] -k [keyword1, keyword2, keyword3] -l [latitude] -o [longitude]"
    echo "The keywords, latitude and longitude are written to the IPTC:Keywords, XMP:Latitude and XMP:longitude metadata of all fotos."
    exit 1
}



script_dir=$(cd "$(dirname "$0")" && pwd -P)
cookie_file="${script_dir}/session.cookie"
target_dir=./target
start_year=2014
end_year=2020
keywords=""
gps_latitude=""
gps_longitude=""

checkDependencies

# Parse and get script arguments
while getopts ":u:p:t:s:e:k:l:o:" opt; do
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
    k)
       keywords=$OPTARG
       ;;
    l)
       gps_latitude=$OPTARG
       ;;
    o)
       gps_longitude=$OPTARG
       ;;
    \?)
      echo >&2 "Invalid option: -$OPTARG"
      exit 1
      ;;
    :)
      echo >&2 "Option -$OPTARG requires an argument."
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
 --data-urlencode "role=7"

echo "Navigating to ${target_dir}, creating directories if needed."
mkdir -p ${target_dir}
cd ${target_dir}
for ((year=start_year; year < end_year; year++)); do
    for month in {1..12}; do

        # Retrieve the ids of the fotos for the specific year and month.
        echo "Retrieving fotos for ${year}-${month}."
        foto_ids=$( \
            curl 'https://mijn.kmnkindenco.nl/ouder/fotoalbum/standaardalbum' \
             --cookie ${cookie_file} \
             --data-urlencode "year=${year}" \
             --data-urlencode "month=${month}" | \
             jq -r ".FOTOS | .[]" \
             )

         for foto_id in ${foto_ids}; do
            echo "Downloading foto ${foto_id}."
            foto_file="${foto_id}.jpg"
            curl "https://mijn.kmnkindenco.nl/ouder/media/download/media/${foto_id}" \
             --cookie ${cookie_file} \
             -o "${foto_file}"

            echo "Retrieving metadata...."
            metadata=$( \
                curl "https://mijn.kmnkindenco.nl/ouder/fotoalbum/fotometa" \
                 --cookie ${cookie_file} \
                 --data-urlencode "id=${foto_id}" | \
                 jq ".[0] | {MEDIA_DAG, MEDIA_BESCHRIJVING}" \
                 )
            image_description=$(echo ${metadata} | jq -r ".MEDIA_BESCHRIJVING")
            image_date=$(echo ${metadata} | jq -r ".MEDIA_DAG")

            echo "Updating metadata setting date to ${image_date}, description to ${image_description} and adding keywords ${keywords} and gps coordinates ${gps_latitude} / ${gps_longitude}."
            exiftool -overwrite_original -sep ", " -keywords+="${keywords}" -imagedescription="${image_description}" \
             -alldates="${image_date}" -xmp:gpslatitude="${gps_latitude}" -xmp:gpslongitude="${gps_longitude}" ${foto_file}
         done
    done
done

 # Rename all fotos so they start with the date part.
 exiftool -overwrite_original "-FileName<CreateDate" -d "%Y-%m-%d_%%f.%%e" .
 # Organize files in a directory hiearchy, a directory per year and per month.
 exiftool -overwrite_original "-directory<CreateDate" -d "%Y/%Y-%m" .