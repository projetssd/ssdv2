#!/bin/bash

source "${SETTINGS_SOURCE}/includes/functions.sh"
# shellcheck source=${BASEDIR}/includes/variables.sh
source "${SETTINGS_SOURCE}/includes/variables.sh"

#########################################################################
# Title:         Retrieve Plex Token                                    #
# Author(s):     Werner Beroux (https://github.com/wernight)            #
# URL:           https://github.com/wernight/docker-plex-media-server   #
# Description:   Prompts for Plex login and prints Plex access token.   #
#########################################################################
#                           MIT License                                 #
#########################################################################


>&2 echo -n $(gettext "Votre login Plex (e-mail or username) : ")
read PLEX_LOGIN
manage_account_yml plex.ident $PLEX_LOGIN



>&2 echo -n $(gettext "Votre password Plex : ")
read PLEX_PASSWORD
manage_account_yml plex.sesame $PLEX_PASSWORD


>&2 echo 'Retrieving a X-Plex-Token using Plex login/password ...'

#echo "RECAP ${PLEX_LOGIN}:${PLEX_PASSWORD}"

curl -qu "${PLEX_LOGIN}":"${PLEX_PASSWORD}" 'https://plex.tv/users/sign_in.xml' \
    -X POST -H 'X-Plex-Device-Name: PlexMediaServer' \
    -H 'X-Plex-Provides: server' \
    -H 'X-Plex-Version: 0.9' \
    -H 'X-Plex-Platform-Version: 0.9' \
    -H 'X-Plex-Platform: xcid' \
    -H 'X-Plex-Product: Plex Media Server'\
    -H 'X-Plex-Device: Linux'\
    -H 'X-Plex-Client-Identifier: XXXX' --compressed >/tmp/plex_sign_in
X_PLEX_TOKEN=$(sed -n 's/.*<authentication-token>\(.*\)<\/authentication-token>.*/\1/p' /tmp/plex_sign_in)
if [ -z "$X_PLEX_TOKEN" ]; then
    cat /tmp/plex_sign_in
    rm -f /tmp/plex_sign_in
    >&2 echo 'Failed to retrieve the X-Plex-Token.'
    exit 0
else
  manage_account_yml plex.token $X_PLEX_TOKEN
fi

rm -f /tmp/plex_sign_in

echo $X_PLEX_TOKEN
