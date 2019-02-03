#!/bin/bash

MOVIES=/home/%SEEDUSER%/Medias/Movies
TV=/home/%SEEDUSER%/Medias/TV
MUSIC=/home/%SEEDUSER%/Medias/Music

if [[ -e "$MOVIES" ]] || [[ -e "$TV" ]] || [[ -e "$MUSIC" ]]; then
cd /home/%SEEDUSER%/local
rm -rf $MOVIES $TV $MUSIC
fi