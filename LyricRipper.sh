#!/bin/bash

# Define the root directory and log file
tmp_dir="/mnt/raid5/tmp"
LOGFILE="/tmp/lyricripper.log"
LYRICLOG="/tmp/missinglyrics.log"
# Log messages to both terminal and log file
log_message() {
    echo "$1" | tee -a "$LOGFILE"
}

# Function to rip audio CDs
cd_rip() {
    log_message "Starting Audio CD rip"
    
    CMD="abcde -a cddb,read,encode,tag,move,clean -d /dev/sr0 -o flac -V -N"
    OUTPUT=$(mktemp)
    $CMD 2>&1 | tee "$OUTPUT" | tee -a "$LOGFILE"

    # Check for errors in the output
    if grep -q "WARNING" "$OUTPUT"; then
        log_message "Error: something went wrong while querying the CD. Are you sure this is an Audio CD?"
        rm -f "$OUTPUT"
        eject
        exit 1
    elif grep -q "ERROR" "$OUTPUT"; then
        log_message "abcde threw a fatal error, script cannot continue."
        rm -f "$OUTPUT"
        rm -rf "$tmp_dir"/*
        eject
        exit 1
    else
        log_message "Audio rip complete, proceeding grab lyrics"
    fi

    # Remove the temporary output file
    rm -f "$OUTPUT"
}

# Function to check that directory contains an identifiable artist
check_directory() {
    if [ ! -d "$tmp_dir" ]; then
        log_message "Error: Directory '$tmp_dir' does not exist."
        exit 1
    fi

    artists=()
    while IFS= read -r -d '' artist; do
        artists+=("$artist")
    done < <(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d -print0)

    if [ ${#artists[@]} -eq 0 ]; then
        log_message "No album rips were found. Check log file for more information: $LOGFILE"
        exit 1
    else
        for artist in "${artists[@]}"; do
            artist_name=$(basename "$artist")
            if [[ "$artist_name" == "Various Artists" || "$artist_name" == "Unknown Artist" ]]; then
                log_message "MusicBrainz wasn't able to identify the artist."
                log_message "Consider adding this CD to their database: https://musicbrainz.org/doc/How_to_Add_Disc_IDs"
                log_message "Script cannot continue without this information..."
                rm -rf "$artist"
                exit 1
                return
            fi
        done

        for artist in "${artists[@]}"; do
            log_message "Artist found: $(basename "$artist")"
            albums=()
            while IFS= read -r -d '' album; do
                albums+=("$album")
            done < <(find "$artist" -mindepth 1 -maxdepth 1 -type d -print0)
            for album in "${albums[@]}"; do
                log_message "Album found: $(basename "$album")"
            done
        done
    fi
}


# Function to encode the request string using jq
url_encode() {
    local string="${1}"
    jq -nr --arg str "$string" '$str|@uri'
}

# Function to fetch lyrics from LRCLIB and save to .lrc file
fetch_lyrics() {
    local artist="$1"
    local track="$2"
    local tracknumber="$3"
    local output_dir="$4"

    encoded_artist=$(url_encode "$artist")
    encoded_track=$(url_encode "$track")

    response=$(curl -s "https://lrclib.net/api/search?track_name=$encoded_track&artist_name=$encoded_artist")

    syncedLyrics=null
    plainLyrics=null

    #Uncomment if you want to see the API response
    #echo $response

    for row in $(echo "${response}" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }

        current_syncedLyrics=$(_jq '.syncedLyrics')
        current_plainLyrics=$(_jq '.plainLyrics')
        is_instrumental=$(_jq '.instrumental')

        if [ "$is_instrumental" = "true" ]; then
            log_message "This song is instrumental: ${track}"
            exit 0
        fi

        if [ "$current_syncedLyrics" != "null" ]; then
            syncedLyrics="$current_syncedLyrics"
            break
        elif [ "$plainLyrics" = "null" ]; then
            plainLyrics="$current_plainLyrics"
        fi
    done

    output_file="${output_dir}/${tracknumber} - ${track}.lrc"

        if [ "$syncedLyrics" != "null" ]; then
            log_message "Synced lyrics available for: ${track}"
            echo "$syncedLyrics" | sed 's/\\n/\n/g' > "$output_file"
        elif [ "$plainLyrics" != "null" ]; then
            log_message "Synced lyrics are not available, falling back to plain lyrics for ${track}"
            echo "$plainLyrics" | sed 's/\\n/\n/g' > "$output_file"
            log_message "Missing synced lyrics for: $artist - $track" >> "$lyriclog"
        else
            log_message "Lyrics not found for: ${track}, consider contributing!"
            log_message "Missing synced/unsynced lyrics for $artist - $track" >> "$lyriclog"
        fi
}

# Function to extract metadata using "mediainfo"
extract_metadata() {
    local file="$1"
    local dir="$(dirname "$file")"
    local track=$(mediainfo "$file" | grep "Track name *:" | sed 's/.*: //')
    local artist=$(mediainfo "$file" | grep "Performer *:" | sed 's/.*: //')
    local tracknumber=$(mediainfo "$file" | grep "Track name/Position  *:" | sed 's/.*: //')
    fetch_lyrics "$artist" "$track" "$tracknumber" "$dir"
}

# Function to find and process audio files
get_lyrics() {
    export LOGFILE LYRICLOG
    export -f log_message url_encode fetch_lyrics extract_metadata
    find "$tmp_dir" -type f \( -iname "*.mp3" -o -iname "*.flac" \) -exec bash -c 'extract_metadata "$0"' {} \;
}

# Function to import music to media directory via beets
music_import() {
    log_message "Starting beets import"
    CMD="beet import $tmp_dir"
    OUTPUT=$(mktemp)
    $CMD 2>&1 | tee "$OUTPUT" | tee -a "$LOGFILE"
    log_message "Beets import complete"
    rm -f "$OUTPUT"
}

# Function to clean up temporary files
cleanup() {
    log_message "Cleaning up temporary files"
    rm -rf "$tmp_dir"/*
    log_message "Ejecting CD"
    #eject
}

# Function for debugging
script_debugging() {
    log_message "CD rip script started successfully, proceeding to output debug information"
    
    {
        echo "Temporary directory location"
        echo "$tmp_dir"

        echo "Current session variables"
        echo $PATH

        echo "Setting some default variables"
        echo "If enabling debugging fixes your issue, your issue probably lies with your PATH variable"
        export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games

        echo "Running nslookup..."
        nslookup google.com

        echo "Running ping..."
        ping -c 2 google.com
        ping -c 2 8.8.8.8

        echo "DNS resolver: /etc/resolv.conf..."
        cat /etc/resolv.conf

        echo "Network interfaces..."
        ip a

        echo "Current routing table..."
        ip route
    } >> "$LOGFILE" 2>&1

    log_message "Debugging commands finished"
}

# Main function to orchestrate the script execution
main() {
    # Uncomment the line below to enable debugging
    # script_debugging

    cd_rip
    check_directory
    get_lyrics
    music_import
    cleanup
}

main