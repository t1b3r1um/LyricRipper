#!/bin/bash

<< 'END'
        .SYNOPSIS
        Script to download lyrics

        .Date
        6/15/2024

        .DESCRIPTION
        Testing / auxilary script that can be used outside the main LyricRipper script to
        download lyrics. Recommended if you've already ripped the CD to your
        media directory and uploaded lyrics to LRCLIB afterwards.

        .USAGE
        {get-lyics.sh} (root/artist/album media folder path)
        ./get-lyics.sh.sh "/mnt/raid5/media/Music/Oh Wonder/Ultralife"

         .LINK
        https://github.com/t1b3r1um/LyricRipper

END

if [ -z "$1" ]; then
  echo "Usage: $0 <directory_with_media>"
  exit 1
fi

tmp_dir="$1"
LOGFILE="/tmp/get-lyrics.log"
lyriclog="/tmp/missinglyrics.log"

log_message() {
    echo "$1" | tee -a "$LOGFILE"
}

# Function to encode the string using jq
url_encode() {
    local string="${1}"
    jq -nr --arg str "$string" '$str|@uri'
}

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
    export LOGFILE lyriclog
    export -f log_message url_encode fetch_lyrics extract_metadata
    find "$tmp_dir" -type f \( -iname "*.mp3" -o -iname "*.flac" \) -exec bash -c 'extract_metadata "$0"' {} \;
}
get_lyrics
