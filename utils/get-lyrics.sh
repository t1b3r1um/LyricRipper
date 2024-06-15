#!/bin/bash

<< 'END'
        .SYNOPSIS
        Script to download lyrics

        .Date
        6/15/2024

        .DESCRIPTION
        Testing / auxilary script that can be used outside the main cd ripping script to
        download lyrics. Recommended if you've already ripped the CD to your
        media directory and uploaded lyrics to LRCLIB afterwards.

        .VARIABLES
        Change "dir_with_media" to either the root of your media directory, the artist, or the album - depending on the
        scope you want to recheck lyrics for.

         .LINK
        https://github.com/t1b3r1um/cdripandbeetsimport

END

dir_with_media="/mnt/raid5/media/Music/Bring Me the Horizon/That’s the Spirit/"
tmp_dir=$dir_with_media
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

    for row in $(echo "${response}" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }

        current_syncedLyrics=$(_jq '.syncedLyrics')
        current_plainLyrics=$(_jq '.plainLyrics')

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
        log_message "post-lyrics.sh under the utils folder can be used to submit lyrics (.lrc files) to LRCLIB"
        log_message "Missing synced/unsynced lyrics for $artist - $track" >> "$lyriclog"
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

# Function to find and process audio files
get_lyrics() {
    export LOGFILE lyriclog
    export -f log_message url_encode fetch_lyrics extract_metadata
    find "$tmp_dir" -type f \( -iname "*.mp3" -o -iname "*.flac" \) -exec bash -c 'extract_metadata "$0"' {} \;
}
get_lyrics
