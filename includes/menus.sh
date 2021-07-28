menu_ajout_supp_applis() {
  clear
  manage_apps
}

menu_secu_system_oauth2() {
  clear
  echo ""
  ${BASEDIR}/includes/config/scripts/oauth.sh
}

menu_secu_system_auth_classique() {
  clear
  echo ""
  manage_account_yml oauth.client " "
  manage_account_yml oauth.secret " "
  manage_account_yml oauth.openssl " "
  manage_account_yml oauth.account " "

  ${BASEDIR}/includes/config/scripts/basique.sh
}

menu_secu_system_ajout_adresse_oauth2() {
  clear
  logo
  echo ""
  echo >&2 -n -e "${BWHITE}Compte(s) Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
  read email
  ###sed -i "/account:/c\   account: $email" ${CONFDIR}/variables/account.yml
  manage_account_yml oauth.email $email
  ansible-playbook ${BASEDIR}/includes/dockerapps/traefik.yml

  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CRED}     /!\ MISE A JOUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"

  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
  read -r

}

menu_secu_systeme_iptables() {
  clear
  echo ""
  ${BASEDIR}/includes/config/scripts/iptables.sh
}

menu_secu_systeme_cloudflare() {
  ${BASEDIR}/includes/config/scripts/cloudflare.sh
}

menu_change_domaine() {
  clear
  echo ""
  ${BASEDIR}/includes/config/scripts/domain.sh
}

menu_change_sous_domaine() {
  ansible-playbook ${BASEDIR}/includes/dockerapps/templates/ansible/ansible.yml
  SERVICESPERUSER="$SERVICESUSER${USER}"
  #SEEDUSER=$(cat ${TMPNAME})
  rm ${TMPNAME}
  rm ${CONFDIR}/conf/* >/dev/null 2>&1

  while read line; do
    echo ${line} | cut -d'.' -f1
  done </home/${USER}/resume >$SERVICESUSER${USER}
  mv /home/${USER}/resume ${CONFDIR}/resume >/dev/null 2>&1
  subdomain

  grep "plex" $SERVICESPERUSER >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    ansible-playbook ${BASEDIR}/includes/config/roles/plex/tasks/main.yml
    sed -i "/plex/d" $SERVICESPERUSER >/dev/null 2>&1
  fi

  install_services
  mv ${CONFDIR}/resume /home/${USER}/resume >/dev/null 2>&1
  resume_seedbox
}

menu_gestion_motd() {
  clear
  echo ""
  motd
  pause
}

menu_gestion_traktarr() {
  clear
  echo ""
  traktarr
  pause
}

menu_gestion_webtools() {
  clear
  echo ""
  webtools
  pause
}

menu_gestion_rtorrent_cleaner() {
  clear
  echo ""
  rtorrent-cleaner
  docker run -it --rm -v /home/${USER}/local/rutorrent:/home/${USER}/local/rutorrent -v /run/php:/run/php magicalex/rtorrent-cleaner
  pause
}

menu_gestion_plex_patrol() {
  ansible-playbook ${BASEDIR}/includes/config/roles/plex_patrol/tasks/main.yml
  #SEEDUSER=$(ls ${CONFDIR}/media* | cut -d '-' -f2)
  DOMAIN=$(get_from_account_yml user.domain)
  FQDNTMP="plex_patrol.$DOMAIN"
  echo "$FQDNTMP" >>/home/${USER}/resume
  cp "${BASEDIR}/includes/config/roles/plex_patrol/tasks/main.yml" "${CONFDIR}/conf/plex_patrol.yml" >/dev/null 2>&1
  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
  read -r
}

menu_gestion_ufw() {
  clear
  install_ufw
}

menu_gestion_backup() {
  clear
  echo -e " ${BLUE}* Configuration du Backup${NC}"
  echo ""
  ansible-playbook ${BASEDIR}/includes/config/roles/backup/tasks/main.yml
  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
  read -r

}

function menu_gestion_install_filebot() {
  clear
  echo -e " ${BLUE}* Installation de filebot${NC}"
  echo ""
  ansible-playbook ${BASEDIR}/includes/config/roles/filebot/tasks/main.yml
  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
  read -r

}

menu_gestoutils_plexautoscan() {
  clear
  echo ""
  plex_autoscan
  pause
}

menu_gestoutils_autoscan() {
  clear
  echo ""
  ansible-playbook ${BASEDIR}/includes/config/roles/autoscan/tasks/main.yml
  pause
}

menu_gestoutils_cloudplow() {
  clear
  logo
  echo ""
  install_cloudplow
  pause
}

menu_gestoutils_crop() {
  clear
  crop
  echo ""
  pause
}

menu_gestoutils_dupefinder() {
  clear
  plex_dupefinder
  echo ""
  pause
}

function menu_sa_gen() {
  ${BASEDIR}/includes/config/scripts/sa-gen.sh
}

function menu_safire() {
  ${BASEDIR}/includes/config/scripts/safire.sh
}

function menu_migr_donnees() {
  clear
  ${BASEDIR}/includes/config/scripts/migration.sh
}

function menu_copier_donnees() {
  clear
  ${BASEDIR}/includes/config/scripts/sasync.sh
}

function menu_migration_compte_diff_deplace() {
  clear
  ${BASEDIR}/includes/config/scripts/migration.sh
  pause
}

function menu_migration_compte_diff_copie() {
   clear
    ${BASEDIR}/includes/config/scripts/sasync-bwlimit.sh
    pause
}


menu_migr_gdrive2share() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}MIGRATION GDRIVE ==> SHARE DRIVE${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) GDrive et Share Drive font partis du même compte Google ${CEND}"
  echo -e "${CGREEN}   2) GDrive et Share Drive sont sur deux comptes Google Différents ${CEND}"
  echo ""
  read -p "Votre choix [1-3]: " MVEA
  case $MVEA in
  1)
    menu_migr_meme_compte
    ;;
  2)
    menu_migr_compte_diff
    ;;

  esac
}

menu_migr_share2share_compte_diff() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}Share Drive => Share Drive => Compte Google Différents${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Déplacer les données => Vous pouvez directement le faire à partir de l'interface UI${CEND}"
  echo -e "${CGREEN}   2) Copier les données => 10 Tera par jour${CEND}"
  echo ""
  read -p "Votre choix [1-3]: " MVED
  case $MVED in

  1) # Déplacer les données (Pas de limite)
    clear
    logo
    echo ""
    echo -e "${CGREEN} /!\ Vous pouvez directement le faire à partir de l'interface UI /!\ ${CEND}"
    echo ""
    read -rp $'\e[36m   Poursuivre malgré tout avec rclone: (o/n) ? \e[0m' OUI
    if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
      echo ""
      ${BASEDIR}/includes/config/scripts/sasync-share.sh
    fi
    pause
    ;;

  2) # Copier les données (10 Tera par jour)
    ${BASEDIR}/includes/config/scripts/sasync-share.sh
    pause
    ;;

  esac

}

menu_migr_share2share_mm_compte() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}Share Drive => Share Drive ==> Même compte Google${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Déplacer les données => Vous pouvez directement le faire à partir de l'interface UI${CEND}"
  echo -e "${CGREEN}   2) Copier les données =>10 Tera par jour ${CEND}"
  echo ""
  read -p "Votre choix [1-3]: " MVEC
  case $MVEC in

  \
    1) # Déplacer les données (Pas de limite)
    clear
    logo
    echo ""
    echo -e "${CGREEN} /!\ Vous pouvez directement le faire à partir de l'interface UI /!\ ${CEND}"
    echo ""
    read -rp $'\e[36m   Poursuivre malgré tout avec rclone: (o/n) ? \e[0m' OUI

    if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
      echo ""
      ${BASEDIR}/includes/config/scripts/sasync-share.sh
    fi
    pause
    ;;

  2) # Copier les données (10 Tera par jour)
    ${BASEDIR}/includes/config/scripts/sasync-share.sh
    pause
    ;;

  esac

}

menu_migr_share2share() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}Share Drive => Share Drive${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Share Drive et Share Drive font partis du même compte Google${CEND}"
  echo -e "${CGREEN}   2) Share Drive et Share Drive sont sur deux comptes Google Différents${CEND}"
  echo ""
  read -p "Votre choix [1-3]: " SHARE
  case $SHARE in

  1) ## migration share drive -> share drive meme compte
    menu_migr_share2share_mm_compte
    ;;

  2) ## migration share drive -> share drive compte diff
    menu_migr_share2share_compte_diff
    ;;

  esac
}

menu_migr() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}MIGRATION${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) GDrive => Share Drive${CEND}"
  echo -e "${CGREEN}   2) Share Drive => Share Drive${CEND}"
  echo -e ""
  read -p "Votre choix [1-3]: " MIGRE
  case $MIGRE in

  1) ## migration gdrive -> share drive
    menu_migr_gdrive2share
    ;;

  2) ## migration share drive -> share drive
    menu_migr_share2share
    ;;

  esac
}

menu_install_rclone_plexdrive() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}RCLONE && PLEXDRIVE${CEND}"
  echo ""
  echo -e "${CGREEN}   1) Installation rclone vfs${CEND}"
  echo -e "${CGREEN}   2) Installation plexdrive${CEND}"
  echo -e "${CGREEN}   3) Installation plexdrive + rclone vfs${CEND}"
  echo -e ""

  read -p "Votre choix: " RCLONE
  case $RCLONE in

  1)
    ${BASEDIR}/includes/config/scripts/fusermount.sh
    install_rclone
    unionfs_fuse
    rm -rf /mnt/plexdrive
    echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
    read -r
    ;;

  2)
    clear
    ${BASEDIR}/includes/config/scripts/fusermount.sh
    ${BASEDIR}/includes/config/scripts/rclone.sh
    ${BASEDIR}/includes/config/scripts/plexdrive.sh
    install_plexdrive
    echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
    read -r
    ;;

  3)
    clear
    ${BASEDIR}/includes/config/scripts/fusermount.sh
    install_rclone
    unionfs_fuse
    ${BASEDIR}/includes/config/scripts/plexdrive.sh

    plexdrive
    echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
    read -r
    ;;
  esac # case $RCLONE

}

function menu_create_rclone() {
  ${BASEDIR}/includes/config/scripts/createrclone.sh
}

menu_gestion() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}GESTION${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Sécurisation Systeme${CEND}"
  echo -e "${CGREEN}   2) Utilitaires${CEND}"
  echo -e "${CGREEN}   3) Création Share Drive && rclone${CEND}"
  echo -e "${CGREEN}   4) Outils (autoscan, crop, cloudplow, plex-autoscan, plex_dupefinder)${CEND}"
  echo -e "${CGREEN}   5) Comptes de Service${CEND}"
  echo -e "${CGREEN}   6) Migration Gdrive/Share Drive ==> Share Drive${CEND}"
  echo -e "${CGREEN}   7) Installation Rclone vfs && Plexdrive${CEND}"
  echo -e ""
  read -p "Votre choix [1-8]: " GESTION

  case $GESTION in

  \
    6)
    ## 2.6 - gestion - Migration Gdrive - Share Drive --> share drive
    menu_migr
    ;;

  7) # 2.7 - Installation Rclone vfs && Plexdrive
    menu_install_rclone_plexdrive
    ;;

  esac

}

function test_menu_sde() {
  ls
  pause
}

########################
function ajout_app_seedbox() {
  echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
  echo ""
  choose_services

  install_services
  pause
  resume_seedbox
}

function ajout_app_autres() {
  echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
  echo ""
  choose_other_services
  subdomain
  auth
  install_services
  pause
  resume_seedbox
  pause
}

function menu_suppression_application() {
  echo -e " ${BWHITE}* Application en cours de suppression${NC}"
  TABSERVICES=()
  for SERVICEACTIVATED in $(docker ps --format "{{.Names}}" | cut -d'-' -f2 | sort -u); do
    SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
    TABSERVICES+=(${SERVICE//\"/} " ")
  done
  APPSELECTED=$(
    whiptail --title "App Manager" --menu \
      "Sélectionner l'Appli à supprimer" 19 45 11 \
      "${TABSERVICES[@]}" 3>&1 1>&2 2>&3
  )
  [[ "$?" == 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then affiche_menu_db; else script_classique; fi
  echo -e " ${GREEN}   * $APPSELECTED${NC}"

  suppression_appli ${APPSELECTED} 1
  pause
}

function menu_reinit_container() {
  touch $SERVICESPERUSER
  echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
  TABSERVICES=()
  for SERVICEACTIVATED in $(docker ps --format "{{.Names}}"); do
    SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
    TABSERVICES+=(${SERVICE//\"/} " ")
  done
  line=$(
    whiptail --title "App Manager" --menu \
      "Sélectionner le container à réinitialiser" 19 45 11 \
      "${TABSERVICES[@]}" 3>&1 1>&2 2>&3
  )
  [[ "$?" == 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then affiche_menu_db; else script_classique; fi
  echo -e " ${GREEN}   * ${line}${NC}"
  subdomain=$(get_from_account_yml "sub.${line}.${line}")
  ###subdomain=$(grep "${line}" ${CONFDIR}/variables/account.yml | cut -d ':' -f2 | sed 's/ //g')

  sed -i "/${line}/d" ${CONFDIR}/resume >/dev/null 2>&1
  sed -i "/${line}/d" /home/${USER}/resume >/dev/null 2>&1
  suppression_appli "${line}"
  rm -f "${CONFDIR}/conf/${line}.yml"
  rm -f "${CONFDIR}/vars/${line}.yml"

  docker system prune -af >/dev/null 2>&1
  docker volume rm $(docker volume ls -qf "dangling=true") >/dev/null 2>&1
  echo ""
  echo ${line} >>$SERVICESPERUSER

  install_services
  pause
  checking_errors $?
  echo""
  echo -e "${BLUE}### Le Container ${line} a été Réinitialisé ###${NC}"
  echo ""
  resume_seedbox
  pause
}
