#!/bin/bash

tmp_dir="/home/nathan/Desktop/cd/scripttest/Music/"
# tmp_dir="/tmp/abcde_tmp"
# tmp_dir="$1"

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
