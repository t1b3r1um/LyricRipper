# submit_lyrics.sh

#!/bin/bash

# Function to URL encode a string using jq
url_encode() {
    local string="${1}"
    local encoded
    encoded=$(jq -nr --arg str "$string" '$str|@uri')
    echo "${encoded}"
}

# Function to submit lyrics
submit_lyrics() {
    local artist="$1"
    local track="$2"
    local album="$3"
    local duration="$4"
    local lyrics="$5"
    local publish_token="$6"

    # API endpoint for submitting lyrics
    api_url="https://lrclib.net/api/publish"

    # Construct the JSON payload with "syncedLyrics"
    json_payload=$(jq -n \
      --arg artist "$artist" \
      --arg track "$track" \
      --arg album "$album" \
      --argjson duration "$duration" \
      --arg lyrics "$lyrics" \
      '{artistName: $artist, trackName: $track, albumName: $album, duration: $duration, syncedLyrics: $lyrics}')

    # Print the JSON payload for debugging
    echo "JSON Payload: $json_payload"

    # Print the publish token for debugging
    echo "$publish_token"

    # Submit the lyrics via a POST request with the publish token
    response=$(curl --write-out "%{http_code}\n" -s -X POST "$api_url" \
      -H "Content-Type: application/json" \
      -H "X-Publish-Token: $publish_token" \
      -d "$json_payload")

    # Print the response for debugging
    echo "API Response: $response"

    # Check if the submission was successful
    if [[ "$response" == 200 ]] || [[ "$response" == 201 ]]; then
        echo "Lyrics submitted successfully!"
    else
        echo "Failed to submit lyrics. Response: $response"
    fi
}

# Function to read lyrics from a local .lrc file
read_lyrics_from_file() {
    local file_path="$1"
    local lyrics_content

    # Read the entire file content
    lyrics_content=$(<"$file_path")

    # Encode newline characters for JSON
    lyrics_content=$(echo "$lyrics_content" | jq -sRr @json | sed 's/^"\(.*\)"$/\1/' | sed 's/\\n/\n/g')

    echo "$lyrics_content"
}

# Function to obtain a publish token
get_publish_token() {
    # API endpoint for requesting a challenge
    challenge_url="https://lrclib.net/api/request-challenge"

    # Request a challenge
    challenge_response=$(curl -s -X POST "$challenge_url")
    prefix=$(echo "$challenge_response" | jq -r '.prefix')
    target=$(echo "$challenge_response" | jq -r '.target')

    # Print the challenge response for debugging
    #echo "Challenge Response: $challenge_response"

    # Generate a nonce using the Python script
    nonce=$(python3 solve_nonce.py "$prefix" "$target")

    # Combine prefix and nonce to create the publish token
    publish_token="${prefix}:${nonce}"
    #echo "Publish Token: $publish_token"
    echo "$publish_token"
}

# Example usage of the script
artist="Oh Wonder"
track="Don't Let The Neighborhood Hear"
album="22 Break"
duration=420
lyrics_file_path="/home/nathan/Desktop/cd/scripttest/Music/Oh Wonder/22 Break/5 - Don’t Let the Neighbourhood Hear.lrc"

# Read the lyrics from the .lrc file
lyrics=$(read_lyrics_from_file "$lyrics_file_path")

# Obtain the publish token
publish_token=$(get_publish_token)

# Submit the lyrics
submit_lyrics "$artist" "$track" "$album" "$duration" "$lyrics" "$publish_token"