menu_ajout_supp_applis() {
  clear
  manage_apps
}

menu_secu_system_oauth2() {
  clear
  echo ""
  get_architecture
  "${SETTINGS_SOURCE}/includes/config/scripts/oauth.sh"
}

menu_secu_system_auth_classique() {
  clear
  echo ""
  manage_account_yml oauth.client " "
  manage_account_yml oauth.secret " "
  manage_account_yml oauth.openssl " "
  manage_account_yml oauth.account " "

  ${SETTINGS_SOURCE}/includes/config/scripts/basique.sh
}

menu_secu_system_ajout_adresse_oauth2() {
  clear
  logo
  echo ""
  echo >&2 -n -e "${BWHITE}Compte(s) Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
  read email
  manage_account_yml oauth.email $email
  ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/traefik.yml

  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CRED}     /!\ MISE A JOUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"

  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
  read -r

}

menu_secu_systeme_iptables() {
  clear
  echo ""
  ${SETTINGS_SOURCE}/includes/config/scripts/iptables.sh
}

menu_secu_systeme_cloudflare() {
  ${SETTINGS_SOURCE}/includes/config/scripts/cloudflare.sh
}

menu_change_domaine() {
  clear
  echo ""
  ${SETTINGS_SOURCE}/includes/config/scripts/domain.sh
}

menu_change_sous_domaine() {
  ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/templates/ansible/ansible.yml
  SERVICESPERUSER="$SERVICESUSER${USER}"
  #SEEDUSER=$(cat ${TMPNAME})
  rm ${TMPNAME}
  rm ${SETTINGS_STORAGE}/conf/* >/dev/null 2>&1
  subdomain

  grep "plex" $SERVICESPERUSER >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/plex/tasks/main.yml
    sed -i "/plex/d" $SERVICESPERUSER >/dev/null 2>&1
  fi

  install_services
  echo "Changement effectué"
  pause
}

menu_gestion_motd() {
  clear
  echo ""
  motd
  pause
}

menu_gestion_rtorrent_cleaner() {
  clear
  echo ""
  install-rtorrent-cleaner
  docker run -it --rm -v /home/${USER}/local/rutorrent:/home/${USER}/local/rutorrent -v /run/php:/run/php magicalex/rtorrent-cleaner
  pause
}

menu_gestion_ufw() {
  clear
  install_ufw
}

menu_gestion_backup() {
  clear
  echo -e " ${BLUE}* Configuration du Backup${NC}"
  echo ""
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/backup/tasks/main.yml
  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
  read -r

}

function menu_gestion_install_filebot() {
  clear
  echo -e " ${BLUE}* Installation de filebot${NC}"
  echo ""
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/filebot/tasks/main.yml
  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
  read -r

}

menu_gestoutils_autoscan() {
  clear
  echo ""
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/autoscan/tasks/main.yml
  pause
}

menu_gestoutils_cloudplow() {
  clear
  logo
  echo ""
  install_cloudplow
  pause
}

menu_gestoutils_dupefinder() {
  clear
  plex_dupefinder
  echo ""
  pause
}

########################
function ajout_app_seedbox() {
  echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
  echo ""
  choose_services

  install_services
  echo "Installations terminées"
  pause
}

function ajout_app_autres() {
  echo ""
  choose_other_services

  install_services
  echo "Installations terminées"
  pause
}

function menu_suppression_application() {
  echo -e " ${BWHITE}* Application en cours de suppression${NC}"
  TABSERVICES=()
  for SERVICEACTIVATED in $(docker ps --format "{{.Names}}" | cut -d'-' -f2 | sort -u | grep -v "tor"); do
    SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
    TABSERVICES+=(${SERVICE//\"/} " ")
  done
  APPSELECTED=$(
    whiptail --title "App Manager" --menu \
      "Sélectionner l'Appli à supprimer" 19 45 11 \
      "${TABSERVICES[@]}" 3>&1 1>&2 2>&3
  )
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo -e " ${GREEN}   * $APPSELECTED${NC}"

    suppression_appli ${APPSELECTED} 1
    pause
    affiche_menu_db
  fi
}

function menu_reinit_container() {

  touch $SERVICESPERUSER
  TABSERVICES=()
  for SERVICEACTIVATED in $(docker ps --format "{{.Names}}" | grep -v "tor"); do
    SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
    TABSERVICES+=(${SERVICE//\"/} " ")
  done
  line=$(
    whiptail --title "App Manager" --menu \
      "Sélectionner le container à réinitialiser" 19 45 11 \
      "${TABSERVICES[@]}" 3>&1 1>&2 2>&3
  )
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    echo -e " ${GREEN}   * ${line}${NC}"
    log_write "Reinit du container ${line}"
    subdomain=$(get_from_account_yml "sub.${line}.${line}")

    suppression_appli "${line}"
    rm -f "${SETTINGS_STORAGE}/conf/${line}.yml"
    rm -f "${SETTINGS_STORAGE}/vars/${line}.yml"

    docker volume rm $(docker volume ls -qf "dangling=true") >/dev/null 2>&1
    echo ""
    echo ${line} >>$SERVICESPERUSER
    if [[ "${line}" = zurg ]]; then
      launch_service ${line}
      ansible-playbook "${SETTINGS_SOURCE}/includes/config/roles/rclone/tasks/main.yml"
    else
      launch_service ${line}
    fi
    pause
    checking_errors $?
    echo""
    echo -e "${BLUE}### Le Container ${line} a été Réinitialisé ###${NC}"
    echo ""
    pause
  fi
}
