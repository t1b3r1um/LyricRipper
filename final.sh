#!/bin/bash

# Define the root directory
tmp_dir="/mnt/raid5/tmp/"
LOGFILE="/tmp/cdrip-script.log"

#Function to rip audio CDs
cd_rip () {
  # Define the command
  CMD="abcde -a cddb,read,encode,tag,move,clean -d /dev/sr0 -o flac -V -N"

  # Script output when starting cd_rip
  echo "Starting Audio CD rip"

  # Run the command and capture the output, while displaying it in the terminal
  OUTPUT=$(mktemp)
  $CMD 2>&1 | tee "$OUTPUT"

  # Check for errors in the output
  if grep -q "WARNING" "$OUTPUT"; then
    echo "Error: something went wrong while querying the CD."
    echo "Are you sure this is an Audio CD?"
    rm -f "$OUTPUT"
    eject
    exit 1
  elif grep -q "ERROR" "$OUTPUT"; then
    echo "abcde threw a fatal error, script cannot continue."
    rm -f "$OUTPUT"
    rm -rf "$tmp_dir"/*
    eject
    exit 1

  else
    echo "Audio rip complete, proceeding to move album to Plex library"
  fi

  # Remove the temporary output file
  rm -f "$OUTPUT"
}

#Function to check that directory isn't empty
check_directory() {
    #local tmp_dir="$1"

    # Check if the directory exists
    if [ ! -d "$tmp_dir" ]; then
        echo "Error: Directory '$tmp_dir' does not exist."
        exit 1
    fi

    # Get a list of subdirectories (folders) in the root directory
    subdirectories=()
    while IFS= read -r -d '' folder; do
        subdirectories+=("$folder")
    done < <(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d -print0)

    if [ ${#subdirectories[@]} -eq 0 ]; then
        echo "No album rips were found, usually this is because abcde threw an error the script didn't catch"
        echo "Check log file for more information: /tmp/cdrip-script.log"
        exit 1
    else
        # Check for "Various Artists" or "Unknown Artist" folders and rename them
        for folder in "${subdirectories[@]}"; do
            folder_name=$(basename "$folder")
            if [[ "$folder_name" == "Various Artists" || "$folder_name" == "Unknown Artist" ]]; then
                echo "MusicBrainz wasn't able to identify the artist. This is usually because the artist or album CDDA metadata isn't in their database"
                echo "You should create an account on their website and add this CD: https://musicbrainz.org/doc/How_to_Add_Disc_IDs"
                echo "This script can't continue, since Beets won't import it..."
                rm -rf "$folder"
                return
            fi
        done

        # Print the names of all folders found
        for folder in "${subdirectories[@]}"; do
            echo "Artist found: $(basename "$folder")"
            # Get a list of sub-subdirectories (folders two levels deep)
            sub_subdirectories=()
            while IFS= read -r -d '' sub_folder; do
                sub_subdirectories+=("$sub_folder")
            done < <(find "$folder" -mindepth 1 -maxdepth 1 -type d -print0)
            # Print the names of sub-subdirectories
            for sub_subfolder in "${sub_subdirectories[@]}"; do
                echo "Album found: $(basename "$sub_subfolder")"
            done
        done
    fi
}

retrieve_lyrics (){

# Function to URL encode a string using jq
url_encode() {
    local string="${1}"
    local encoded
    encoded=$(jq -nr --arg str "$string" '$str|@uri')
    echo "${encoded}"
}

# Function to fetch lyrics and save to .lrc file
fetch_lyrics() {
    local artist="$1"
    local track="$2"
    local tracknumber="$3"
    local output_dir="$4"

    # URL encode the artist and track names
    encoded_artist=$(url_encode "$artist")
    encoded_track=$(url_encode "$track")

    response=$(curl -s "https://lrclib.net/api/search?track_name=$encoded_track&artist_name=$encoded_artist")

    # Initialize variables
    syncedLyrics=null
    plainLyrics=null

    # Iterate over the JSON array to find syncedLyrics
    for row in $(echo "${response}" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }

        current_syncedLyrics=$(_jq '.syncedLyrics')
        current_plainLyrics=$(_jq '.plainLyrics')

        # Check if syncedLyrics are available
        if [ "$current_syncedLyrics" != "null" ]; then
            syncedLyrics="$current_syncedLyrics"
            break
        elif [ "$plainLyrics" = "null" ]; then
            plainLyrics="$current_plainLyrics"
        fi
    done

    # Set the output file name
    output_file="${output_dir}/${tracknumber} - ${track}.lrc"

    # Check if syncedLyrics are available
    if [ "$syncedLyrics" != "null" ]; then
        echo "Synced lyrics available for: ${track}!"
        echo "$syncedLyrics" | sed 's/\\n/\n/g' > "$output_file"
    elif [ "$plainLyrics" != "null" ]; then
        echo "Synced lyrics are not available, falling back to plain lyrics for ${track}"
        echo "$plainLyrics" | sed 's/\\n/\n/g' > "$output_file"
        echo "Missing synced lyrics for: $artist - $track" >> /tmp/missinglyrics.log
    else
        echo "Lyrics not found for: ${track}, consider contributing!"
        echo "Unencoded"
        echo "$artist / $track"
        echo "encoded"
        echo "$encoded_artist / $encoded_track"
        echo "Missing synced/unsynced lyrics for $artist - $track" >> /tmp/missinglyrics.log
    fi
}

# Function to extract metadata using mediainfo and fetch lyrics
extract_metadata() {
    local file="$1"
    local dir="$(dirname "$file")"
    local track=$(mediainfo "$file" | grep "Track name *:" | sed 's/.*: //')
    local artist=$(mediainfo "$file" | grep "Performer *:" | sed 's/.*: //')
    local tracknumber=$(mediainfo "$file" | grep "Track name/Position  *:" | sed 's/.*: //')
    fetch_lyrics "$artist" "$track" "$tracknumber" "$dir"
}

# Export the functions to use with find's -exec
export -f url_encode
export -f fetch_lyrics
export -f extract_metadata

# Find all mp3 and flac files in the specified media directory and process them
find "$tmp_dir" -type f \( -iname "*.mp3" -o -iname "*.flac" \) -exec bash -c 'extract_metadata "$0"' {} \;
}

#Function to import music to media directory via beets
music_import () {
      # Define the command
  CMD="beet import $tmp_dir"

  # Script output when starting cd_rip
  echo "Starting beets import"

  # Run the command and capture the output, while displaying it in the terminal
  OUTPUT=$(mktemp)
  $CMD 2>&1 | tee "$OUTPUT"

  echo "beets import complete"
  rm -f "$OUTPUT"
}

#Any tasks to run after media has been imported
cleanup() {
    #This function originally rescanned Plex libraries, but for some reason the scanner hangs up and the scrip never finishes.
    #Plex has a built in feature to re-scan libraries when the directory change. I recommend you enable this feature if using Plex
    #echo "Rescanning Plex libraries"
    # Run the Plex Media Scanner with a timeout of 15 seconds
    #timeout 15 "/usr/lib/plexmediaserver/Plex Media Scanner" --scan &
    # Wait for the Plex Media Scanner to finish or timeout
    #wait $!
    echo "Cleaning up temporary files"
    rm -rf "$tmp_dir"/*
    echo "Ejecting CD"
    #eject
}



#This function is not enabled by default, however can be useful for debugging. By default, when run from udev directly (instead of using a service), this 
#script isn't able to resolve/communicate with musicbrainz servers. Using a service is easier than making rule changes. 
script_debugging (){
echo "CD rip script started successfully, proceeding to output debug information" > $LOGFILE

{
    echo $tmp_dir

    echo "Setting env paths manually"
    export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games

    echo "Running nslookup..."
    nslookup google.com

    echo "Running ping..."
    ping -c 2 google.com
    ping -c 2 8.8.8.8

    echo "grabbing DNS resolver: /etc/resolv.conf..."
    cat /etc/resolv.conf

    echo "Network interfaces..."
    ip a

    echo "Current routing table..."
    ip route
} >> $LOGFILE 2>&1

echo "Debugging commands finished" >> $LOGFILE
}

main (){
#Debugging is below. Uncomment to enable debugging.
#script_debugging >> $LOGFILE
# Call function to rip CDs via abcde
cd_rip >> $LOGFILE
# Call function to check if directory are empty
check_directory >> $LOGFILE
# Call function to retrieve lyrics
retrieve_lyrics >> $LOGFILE
# Call function to import to media directory
#music_import >> $LOGFILE
# Call function to scan Plex
#cleanup >> $LOGFILE
}

main
