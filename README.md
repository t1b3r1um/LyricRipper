# LyricRipper
LyricRipper is a script that rips audio CDs, encodes each track with metadata, downloads the appropriate lyrics, then imports them into your music library using beets. It can either on demand, or combined with a udev rule to automatically rip audio CDs automatically when a CD is inserted into the cd tray.

# Dependencies
LyricRipper relies on abcde (with cdparanoia) to rip the audio and encode it with metadata from MusicBrainz. Once the tracks have been ripped, the script connects to LRCLIB via API and downloads either a synced or unsyned lyric if available. Finally, beets will move the ripped album to your media directory. 

-abcde
    - By default, this script will use your existing abcde.conf. If you are installing abcde for the first time, the abcde.conf sample in the "Resources" should be used. If you already have abcde.conf customized, refer to the sample if the script fails.

    By default, the script looks for /dev/sr0. 

-LRCLIB
    - LRCLIB is an open source online repository for both "synced" and "unsynced lyrics". LyricRipper will connect to their API with the meta data from the ripped audio file to try and find a match. By default, the script will prefer "synced" lyrics over "plain" lyrics. If synced or plain lytics are not available, it will write the artist and track to a log file. 

-beets
    - "the music geek’s media organizer". Beets is an incredibly powerful music organizer that is used to import both the lyric files and audio files into your media library. If you are installing beets for the first time, the beets_config.yaml sample in the "Resources" should be used. If you already have beets customized, refer to the sample if the script fails.
-!WARNING!
     If you do not have a beets organizing your media, be aware that it will rename and move files around.
    
     The sample beets config.yaml is setup to organize your media library using the following naming scheme:

        └── media root
            └── Artist
                └── Album
                    ├── 01 - Awesome Song.flac
                    ├── 01 - Awesome Song.lrc
                    └── cover.jpg

    If you are using an application like Plexwith your media library, this could cause problems.

