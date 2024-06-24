#!/bin/bash

<< 'END'
        .SYNOPSIS
        Script to submit lyrics to LRCLIB

        .Date
        6/15/2024

        .DESCRIPTION
        Auxilary script that can be used to upload LRC files to LRCLIB via API as of the date of this script. Script requires
        an input media file (flac,mp3, etc) with accurate metadata to be specified in order to avoid user error. Ensure the 
        metadata in the media you are using matches what is in Mediabrainz. Don't be a tool and upload bad data to their 
        API you script kitty.

        .USAGE
        {post-lyrics.sh} (audio file with metadata) (LRC File)
        ./post-lyrics.sh /Path/To/Audio/File.flac /Path/To/Lyric/File.lrc

        .VARIABLES
        Change "dir_with_media" to either the root of your media directory, the artist, or the album - depending on the 
        scope you want to recheck lyrics for.

         .LINK
        https://github.com/t1b3r1um/cdripandbeetsimport

END

verify_inputs() {
    #Verifies the audio and lyric file contain the necessary information and are formatted correctly.
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <Audio File> <Lyric File>"
        exit 1
    fi

    audiofile="$1"
    if [[ ! "$audiofile" =~ \.(mp3|flac|raw)$ ]]; then
        echo "Error: $1 must have a file extension of .mp3, .flac, or .raw"
        exit 1
    fi

    if [ ! -f "$audiofile" ]; then
        echo "Error: $1 does not exist"
        exit 1
    fi

    lyricfile="$2"
    if [[ ! "$2" =~ \.lrc$ ]]; then
        echo "Error: $2 must have a file extension of .lrc"
        exit 1
    fi

    if [ ! -f "$lyricfile" ]; then
        echo "Error: $2 does not exist"
        exit 1
    fi

    # Verify the presence of timestamps in the lyric file
    if ! grep -q "^\[[0-9]\{2\}:[0-9]\{2\}\.[0-9]\{2\}\]" "$lyricfile"; then
        echo "Error: $lyricfile does not appear to be a valid synced lyric file"
        echo "Please refer to the readme.md for formatting"
        exit 1
    fi
    
    track=$(mediainfo "$audiofile" | grep "Track name *:" | sed 's/.*: //')
    artist=$(mediainfo "$audiofile" | grep "Performer *:" | sed 's/.*: //')
    album=$(mediainfo "$audiofile" | grep "Album *:" | sed 's/.*: //')
    duration=$(mediainfo "$audiofile" | grep "Duration *:" | sed -n '1s/.*: //p')

    # Complain a bunch of meta data is missing
    if [ -z "$track" ]; then
        echo "Error: Track name metadata is missing in $audiofile"
        echo "Please refer to the readme.md for information on metadata requirements"
        exit 1
    fi
    
    if [ -z "$artist" ]; then
        echo "Error: Performer (artist) metadata is missing in $audiofile"
        echo "Please refer to the readme.md for information on metadata requirements"
        exit 1
    fi
    
    if [ -z "$duration" ]; then
        echo "Error: Duration metadata is missing in $audiofile"
        echo "Please refer to the readme.md for information on metadata requirements"
        exit 1
    fi
    
    if [ -z "$album" ]; then
        echo "Error: Album metadata is missing in $audiofile"
        echo "Please refer to the readme.md for information on metadata requirements"
        exit 1
    fi

    export audiofile
    export lyricfile
    echo "Audio file and lyric file passed validation, proceeding to process lyric file"
}

process_lyrics() {
    # Clean any unnecessary information from the lyric file
    sed -i '0,/^\[[0-9]\{2\}:[0-9]\{2\}\.[0-9]\{2\}\]/d' "$lyricfile"
    sed -i '/www\./d' "$lyricfile"

    synced_lyrics=$(<"$lyricfile")
    #synced_lyrics=$(echo "$synced_lyrics" | jq -sRr @json | sed 's/^"\(.*\)"$/\1/' | sed 's/\\n/\n/g')
    synced_lyrics=$(echo "$synced_lyrics")
    # Strip timestamps from lyrics for plain lyrics
    plain_lyrics=$(echo "$synced_lyrics" | sed 's/\[[0-9:.]*\]//g' | sed '/^\s*$/d')

    # Lyrics output for debugging
    #echo "$synced_lyrics"
    echo "$plain_lyrics"

    export synced_lyrics
    export plain_lyrics
}

duration_seconds () {
    #LRCLIB requires the duration to be in seconds. This function converts the duration in the metadata to seconds
    duration=$(mediainfo "$audiofile" | grep "Duration *:" | sed -n '1s/.*: //p')
    minutes=$(echo "$duration" | cut -d' ' -f1)
    seconds=$(echo "$duration" | cut -d' ' -f3)
    total_seconds=$((minutes * 60 + seconds))
    duration_in_seconds=$total_seconds
}

# Function to obtain a publish token

get_publish_token() {
    # API endpoint for requesting a challenge
    challenge_url="https://lrclib.net/api/request-challenge"

    # Challenge request to LRCLIB
    challenge_response=$(curl -s -X POST "$challenge_url")
    prefix=$(echo "$challenge_response" | jq -r '.prefix')
    target=$(echo "$challenge_response" | jq -r '.target')
    nonce=$(python3 solve_nonce.py "$prefix" "$target")

    echo "${prefix}:${nonce}"
}

submit_lyrics() {
    # API endpoint for submitting lyrics
    api_url="https://lrclib.net/api/publish"

    echo "Solving LRCLIB challenge, this may take up to 30 seconds"
    publish_token=$(get_publish_token)

    # Construct the JSON payload
    json_payload=$(jq -n \
      --arg artist "$artist" \
      --arg track "$track" \
      --arg album "$album" \
      --argjson duration "$duration_in_seconds" \
      --arg syncedLyrics "$synced_lyrics" \
      --arg plainLyrics "$plain_lyrics" \
      '{artistName: $artist, trackName: $track, albumName: $album, duration: $duration, syncedLyrics: $syncedLyrics, plainLyrics: $plainLyrics}')

    # Print the JSON payload for debugging
    #echo "JSON Payload: $json_payload"

    # Print the publish token for debugging
    # echo "$publish_token"

    # Song information
    echo "Identified metadata:"
    echo ""
    echo "Artist: $artist"
    echo "Track: $track"
    echo "Album: $album"
    echo "Duration: $duration_in_seconds"
    echo ""
    echo "Submitting to LRCLIB..."

    # Submit the lyrics via a POST request with the publish token
    response=$(curl --write-out "%{http_code}\n" -s -X POST "$api_url" \
      -H "Content-Type: application/json" \
      -H "X-Publish-Token: $publish_token" \
      -d "$json_payload")

    # Print the response for debugging
    #echo "API Response: $response"

    if [[ "$response" == 200 ]] || [[ "$response" == 201 ]]; then
        echo "Lyrics submitted successfully!"
    else
        echo "Failed to submit lyrics. Response: $response"
    fi
}

debugging () {
    # This function helps with debugging by outputting useful information to the console:
    echo ""
    echo "******************************************************************************"
    echo ""
    echo "Debugging has been enabled:"
    echo ""
    # Input data
    echo "Input audio file: $audiofile"
    echo "Input lyric file: $lyricfile"
    echo ""
    # Song information
    echo "Identified metadata being passed to the submit_lyrics function"
    echo ""
    echo "Artist: $artist"
    echo "Track: $track"
    echo "Album: $album"
    echo "Duration: $duration_in_seconds"
    echo ""

    # Print the JSON payload for debugging
    #echo "JSON Payload: $json_payload"
    echo ""

    # Print the publish token for debugging
    echo "Publish token: $publish_token"
    echo ""

    # Print the response for debugging
    echo "API Response to lyric submission: $response"
    echo ""
}

main () {
    verify_inputs "$@"
    process_lyrics
    duration_seconds
    submit_lyrics
    # Uncomment to enable debugging
    #debugging
}

main "$@"