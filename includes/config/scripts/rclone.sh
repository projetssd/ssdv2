#!/bin/bash

# shellcheck source=${BASEDIR}/includes/functions.sh
source "${SCRIPTPATH}/includes/functions.sh"
# shellcheck source=${BASEDIR}/includes/variables.sh
source "${SCRIPTPATH}/includes/variables.sh"

mkdir -p ${HOME}/.config/rclone
RCLONE_CONFIG_FILE=${HOME}/.config/rclone/rclone.conf

sed -i '/plexdrive/d' ${CONFDIR}/variables/account.yml >/dev/null 2>&1
sed -i '/remote/d' ${CONFDIR}/variables/account.yml >/dev/null 2>&1
sed -i '/id_teamdrive/d' ${CONFDIR}/variables/account.yml >/dev/null 2>&1
cd /tmp
rm drive.txt team.txt >/dev/null 2>&1

function paste() {
  echo -e "${YELLOW}\nColler le contenu de rclone.conf avec le clic droit, et taper ${CCYAN}STOP${CEND}${YELLOW} pour poursuivre le script.\n${NC}"
  while :; do
    read -p "" EXCLUDEPATH
    if [[ "$EXCLUDEPATH" = "STOP" ]] || [[ "$EXCLUDEPATH" = "stop" ]]; then
      break
    fi
    echo "$EXCLUDEPATH" >>${RCLONE_CONFIG_FILE}
  done
  sed -n -i '1h; 1!H; ${x; s/\n*$//; p}' ${RCLONE_CONFIG_FILE} >/dev/null 2>&1
  echo ""
}

function detection() {
  #clear
  echo ""
  echo -e "${CCYAN}Choisir le remote principal :${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Share Drive ${CEND}"
  echo -e "${CGREEN}   2) Gdrive${CEND}"
  echo ""

  read -rp "Votre choix: " RTYPE

  case "$RTYPE" in
  1)
    #
    # Shared drive
    #
    rm -f /tmp/choix_crypt
    rm -f /tmp/id_teamdrive
    ${SETTINGS_SOURCE}/includes/config/scripts/rclone_list_td.py
    remotecrypt=$(cat /tmp/choix_crypt)
    id_teamdrive=$(cat /tmp/id_teamdrive)
    rm -f /tmp/choix_crypt
    rm -f /tmp/id_teamdrive
    ;;

  2)
    rm -f /tmp/choix_crypt
    rm -f /tmp/id_teamdrive
    ${SETTINGS_SOURCE}/includes/config/scripts/rclone_list_gd.py
    remotecrypt=$(cat /tmp/choix_crypt)
    id_teamdrive=$(cat /tmp/id_teamdrive)
    rm -f /tmp/choix_crypt
    rm -f /tmp/id_teamdrive
    ;;

  *)
    echo -e "${CRED}Action inconnue${CEND}"
    ;;
  esac

}

function clone() {
  ## si rclone n'existe pas
  rclone="/usr/bin/rclone"
  conf="${RCLONE_CONFIG_FILE}"
  ## pas de rclone.conf
  if [ ! -e "${RCLONE_CONFIG_FILE}" ]; then
    curl https://rclone.org/install.sh | bash
  fi
}

function verif() {
  detection
  manage_account_yml rclone.remote $remotecrypt
  manage_account_yml rclone.id_teamdrive $id_teamdrive
  ###sed -i "/rclone/a \ \ \ remote: $remotecrypt" ${CONFDIR}/variables/account.yml > /dev/null 2>&1
  ###sed -i "/rclone/a \ \ \ id_teamdrive: $id_teamdrive" ${CONFDIR}/variables/account.yml > /dev/null 2>&1
  exit
}

function menu() {
  clear
  logo
  if [ ! -e "$rclone" ]; then
    curl https://rclone.org/install.sh | sudo bash
  fi
  echo ""

  echo -e "${CCYAN}Gestion du rclone.conf${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Copier/coller un rclone.conf déjà existant ${CEND}"
  echo -e "${CGREEN}   2) Création rclone.conf${CEND}"
  echo -e "${CGREEN}   3) rclone.conf déjà existant sur le serveur --> ${RCLONE_CONFIG_FILE}${CEND}"

  echo -e ""

  read -p "Votre choix [1-3]: " CHOICE

  case $CHOICE in
  1) ## Copier/coller un rclone.conf déjà existant
    rclone="/usr/bin/rclone"

    rclone >/dev/null 2>&1
    paste
    verif
    ;;
  2) ## Création rclone.conf
    clone
    clear
    ${BASEDIR}/includes/config/scripts/createrclone.sh
    verif
    ;;
  3) ## Création rclone.conf
    clone
    verif
    ;;
  esac
}
menu
cd /tmp
rm drive.txt team.txt >/dev/null 2>&1
