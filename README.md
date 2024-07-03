# LyricRipper
LyricRipper is a script that rips audio CDs, encodes each track with metadata, downloads the appropriate lyrics, then imports them into your music library using beets. It can either on demand, or combined with a udev rule to automatically rip audio CDs when a CD is inserted into the cd tray. By default, this script uses the flac file format.

# Dependencies
LyricRipper relies on abcde (using cdparanoia) to rip the audio and encode it with metadata from MusicBrainz. Once the tracks have been ripped, the script connects to LRCLIB via API and downloads either a synced or unsyned lyric if available. Finally, beets will move the ripped album to your media directory. 

-abcde
    - By default, this script will use your existing abcde.conf. If you are installing abcde for the first time, the abcde.conf sample in the "Resources" folder should be used. If you already have abcde.conf customized, refer to the sample if the script fails. If MusicBrainz isn't able to identify the disk, this script won't continue. See the wiki for a quick start guide on uploading your "Disk ID" if Musicbrainz doesn't already have it in their database.
    By default, the script uses /dev/sr0 for the CD-ROM. 

-LRCLIB
    - LRCLIB is an open source online repository for both "synced" and "unsynced lyrics". LyricRipper will connect to their API with the meta data from the ripped audio file to try and find a match. By default, the script will prefer "synced" lyrics over "plain" lyrics. If synced or plain lytics are not available, it will write the artist and track to a log file. 

-beets
    - "the music geek’s media organizer". Beets is an incredibly powerful music organizer that is used to import both the lyric files and audio files into your media library. If you are installing beets for the first time, the beets_config.yaml sample in the "Resources" folder should be used. If you already have beets customized, refer to the sample if the script fails.
    If you do not have beets currently organizing your media, be aware that it will rename and move files around.
    
    The sample beets config.yaml is setup to organize your media library using the following naming scheme:

        └── media root
            └── Artist
                └── Album
                    ├── 01 - Awesome Song.flac
                    ├── 01 - Awesome Song.lrc
                    └── cover.jpg

If you are using an application like Plexwith your media library, this could cause problems.

# Utility Scripts
The util folder contains two scripts:
- post-lyrics.sh
- get-lyrics.sh
# post-lyrics
This script can be used to upload lrc files to LRCLIB's library. To avoid misuse, you must specify an audio file with the correct metadata along with a matched "synced" lrc file. This script will strip the "synced" lyrics automatically to create a "plain" lyric for LRCLIB's database.
        Usage: ./post-lyrics.sh "Audio File" "Synced Lyric File"
# get-lyrics
This script will scan a directory (aka, your media directory) and download lyric files for every mp3 or flac audio file. This can be handy if you have a media server that supports ".lrc" lyric files and you want to download lyrics for other albums not prviously ripped by LyricRipper. Any songs it wasn't able to find lyrics for will be logged to its own file.

    -LOGFILE="/tmp/get-lyrics.log"
    -lyriclog="/tmp/missinglyrics.log"
This script is basically an extract from the main script that uses an input variable.