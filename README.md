# flexweb-foto-downloader
Downloads fotos from flexWEB Mijn kind en co website, by using cUrl and jq. (You might have to install them seperately)
The script will download all fotos from the specified start_year until the specified end_year and logs in with the suplied username and password.
By default the fotos are stored in ./target, but a different directory can be supplied.

usage: ./flexfotos.sh -u username -p password -t [target_dir] -s [start_year] -e [end_year]