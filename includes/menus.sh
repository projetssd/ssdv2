menu_ajout_supp_applis() {
  clear
  manage_apps
}


menu_change_domaine () {
  "${SETTINGS_SOURCE}/includes/config/scripts/domain.sh"
}


menu_secu_system_oauth2() {
  clear
  echo ""
  get_architecture
  "${SETTINGS_SOURCE}/includes/config/scripts/oauth.sh"
}

menu_secu_system_oauth2_proxy() {
  clear
  echo ""
  get_architecture
  "${SETTINGS_SOURCE}/includes/config/scripts/oauth2-proxy.sh"
}

menu_install_authelia() {
  clear
  logo
  echo -e "${CRED}-------------------------------------${CEND}"
  echo -e "${CCYAN}"$(gettext "INSTALLATION AUTHELIA")"${CEND}"
  echo -e "${CRED}-------------------------------------${CEND}"


  # Installation Authelia
  launch_service authelia


  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CRED}"$(gettext "Réinitialiser manuellement les applis qui seront")"${CEND}"
  echo -e "${CRED}"$(gettext "Concernées par l'authentification Authelia") "${CEND}"
  echo -e "${CRED}"$(gettext "Choix 1 puis 3 dans le menu")                     "${CEND}"


  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo ""
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CCYAN}"    IMPORTANT:  $(gettext "Avant la 1ere connexion")"${CEND}"
  echo -e "${CCYAN}"        - $(gettext "Nettoyer l'historique de votre navigateur")"${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo ""
  echo -e "\n $(gettext "Appuyer sur") ${CCYAN}[$(gettext "ENTREE")]${CEND} $(gettext "pour continuer")"
  read -r
}


menu_ajout_users_authelia() {
  clear
  logo
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CRED}"$(gettext "Ajout Utilisateurs Authelia")                     "${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo ""
  ansible-playbook "${SETTINGS_SOURCE}/includes/config/playbooks/add_users_authelia.yml"
  docker restart authelia >/dev/null 2>&1
  echo -e "\n"$(gettext "Appuyer sur")"${CCYAN} ["$(gettext "ENTREE")"]${CEND}" $(gettext "pour continuer")
  read -r
}


menu_suppression_utilisateur_authelia() {
  clear
  logo
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CRED}"$(gettext "Suppression Utilisateurs Authelia")               "${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo ""
  grep displayname "${SETTINGS_STORAGE}/docker/${USER}/authelia/users.yml" | cut -d: -f2 | tr -d '"' | cat -n | sed 's/[ ]\+/ /g' | tr " " " " | tr "\t" " " > temp
  while read LIGNE
  do echo -e "${CCYAN}"$LIGNE"${CEND}"
  done < temp
  echo ""
  echo >&2 -n -e "${CCYAN}"$(gettext "Choisir le numéro de l'utilisateur :") "${CEND}"
  read NUMERO_LIGNE
  UTILISATEUR=$(sed -n "${NUMERO_LIGNE}p" temp | cut -d ' ' -f 4)
  sed -i "/##${UTILISATEUR}##/,/##${UTILISATEUR}##/d" "${SETTINGS_STORAGE}/docker/${USER}/authelia/users.yml"
  rm temp
  echo ""
  echo -e "\e[32m"$(gettext "L'utilisateur ${UTILISATEUR} a été supprimé")"\e[0m"
  docker restart authelia >/dev/null 2>&1
  echo -e "\n"$(gettext "Appuyer sur")"${CCYAN} ["$(gettext "ENTREE")"]${CEND}" $(gettext "pour continuer")
  read -r
}


menu_secu_system_ajout_adresse_oauth2() {
  clear
  logo
  echo ""
  echo >&2 -n -e "${BWHITE}"$(gettext "Compte(s) Gmail utilisé(s), séparés d'une virgule si plusieurs :")"${CEND}"
  read email
  manage_account_yml oauth.account $email
  ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/traefik.yml


  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CRED}     /!\ "$(gettext "MISE A JOUR EFFECTUEE AVEC SUCCES")" /!\  ${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"


  echo -e "\n"$(gettext "Appuyer sur")"${CCYAN} ["$(gettext "ENTREE")"]${CEND}" $(gettext "pour continuer")
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
  echo $(gettext "Changement effectué")
  echo ""
  echo -e "\n $(gettext "Appuyer sur") ${CCYAN}[$(gettext "ENTREE")]${CEND} $(gettext "pour continuer")"
  read -r
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
  echo -e " ${BLUE}*" $(gettext "Configuration du Backup")"${NC}"
  echo ""
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/backup/tasks/main.yml
  echo -e "\n"$(gettext "Appuyer sur")"${CCYAN} ["$(gettext "ENTREE")"]${CEND}" $(gettext "pour continuer")
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


menu_gestoutils_kometa() {
  clear
  echo""
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/kometa/tasks/main.yml
  pause
}


menu_gestoutils_ygg-rss-proxy() {
  clear
  echo""
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/ygg-rss-proxy/tasks/main.yml
  pause
}

menu_manage_apps_auth() {

clear

logo

echo -e "${BLUE}### GESTION DE L'AUTHENTIFICATION DES APPLICATIONS ###${NC}"

echo ""

# Vérifier que le script Python existe
if [ ! -f "${SETTINGS_SOURCE}/includes/config/scripts/manage_auth.py" ]; then
    echo -e "${CRED}❌ Script manage_auth.py introuvable${CEND}"
    echo -e "${CCYAN}Chemin attendu: ${SETTINGS_SOURCE}/includes/config/scripts/manage_auth.py${CEND}"
    echo ""
    echo -e "${BWHITE}ENTER pour continuer${CEND}"
    read -r
    return 1
fi

# Vérifier que le venv Python existe
if [ ! -f "${SETTINGS_SOURCE}/venv/bin/activate" ]; then
    echo -e "${CRED}❌ Environnement Python virtuel introuvable${CEND}"
    echo ""
    echo -e "${BWHITE}ENTER pour continuer${CEND}"
    read -r
    return 1
fi

# Activer le venv et lancer le script Python
source "${SETTINGS_SOURCE}/venv/bin/activate"

python3 "${SETTINGS_SOURCE}/includes/config/scripts/manage_auth.py"

deactivate

echo ""

echo -e "${BWHITE}ENTER pour continuer${CEND}"

read -r

}


function ajout_app_seedbox() {
  echo ""
  choose_services
  install_services
  echo -e "\e[32m"$(gettext "Installations terminées")"\e[0m" 
  pause
}


function menu_suppression_application() {
  line=$1
  suppression_appli ${line} 1
  pause
  affiche_menu_db
}


function menu_reinit_container() {
  line=$1
  log_write "Reinit du container ${line}" >/dev/null 2>&1
  echo -e "\e[32m"$(gettext "Les volumes ne seront pas supprimés")"\e[0m" 
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
  checking_errors $?
  echo ""
  echo -e "${BLUE}### ${line}" $(gettext "a été Réinitialisé") "###${NC}"
  echo ""
  echo ""
  echo -e "\n $(gettext "Appuyer sur") ${CCYAN}[$(gettext "ENTREE")]${CEND} $(gettext "pour continuer")"
  read -r
}

