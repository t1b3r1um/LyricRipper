#!/bin/bash

artist="Oh+Wonder"
track="Don’t+Let+the+Neighbourhood+Hear"
album="22+Break"
encoded_artist=$(printf '%s' "$artist" | jq -s -R -r @uri)
encoded_track=$(printf '%s' "$track" | jq -s -R -r @uri)
encoded_album=$(printf '%s' "$album" | jq -s -R -r @uri)

response=$(curl -s "https://lrclib.net/api/search?track_name=$encoded_album&artist_name=$encoded_artist")

echo "API Response: $response"

if [[ -z "$response" || "$response" == "[]" ]]; then
  echo "Error: Empty response from API or no results found"
  exit 1
fi

#song=$(echo "$response" | jq -r '.[0].syncedLyrics // "Error: Lyrics not found"')
song=$(echo "$response" | jq)
echo "$song"
