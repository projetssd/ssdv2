menu_ajout_supp_applis() {
  clear
  ## Ajout d'Applications
  echo""
  clear
  manage_apps
}

menu_secu_system_oauth2() {
  clear
  echo ""
  ${BASEDIR}/includes/config/scripts/oauth.sh
  script_plexdrive
}

menu_secu_system_auth_classique() {
  clear
  echo ""
  manage_account_yml oauth.client " "
  manage_account_yml oauth.secret " "
  manage_account_yml oauth.openssl " "
  manage_account_yml oauth.account " "
  #          sed -i "/client:/c\   client: " ${CONFDIR}/variables/account.yml
  #          sed -i "/secret:/c\   secret: " ${CONFDIR}/variables/account.yml
  #          sed -i "/openssl:/c\   openssl: " ${CONFDIR}/variables/account.yml
  #          sed -i "/account:/c\   account: " ${CONFDIR}/variables/account.yml

  ${BASEDIR}/includes/config/scripts/basique.sh
  script_plexdrive
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

  script_plexdrive
}

menu_secu_systeme_iptables() {
  clear
  echo ""
  ${BASEDIR}/includes/config/scripts/iptables.sh
  script_plexdrive
}

menu_secu_systeme_cloudflare() {
  ${BASEDIR}/includes/config/scripts/cloudflare.sh
  script_plexdrive
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
  script_plexdrive
}

menu_gestion_domaine() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}CHANGEMENT DOMAINE && SOUS DOMAINES${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Changement du nom de domaine ${CEND}"
  echo -e "${CGREEN}   2) Modifier les sous domaines${CEND}"
  echo -e "${CGREEN}   3) Retour Menu principal${CEND}"

  echo -e ""
  read -p "Votre choix [1-3]: " DOMAIN
  case $DOMAIN in

  1) ## Changement nom de domaine
    menu_change_domaine
    ;;

  2) ## Modifier les sous domaines
    menu_change_sous_domaine
    ;;

  3)
    # Retour menu principal
    script_plexdrive
    ;;
  esac # case DOMAIN
}

menu_securisation_systeme() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}SECURISER APPLIS DOCKER${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Sécuriser Traefik avec Google OAuth2${CEND}"
  echo -e "${CGREEN}   2) Sécuriser avec Authentification Classique${CEND}"
  echo -e "${CGREEN}   3) Ajout / Supression adresses mail autorisées pour Google OAuth2${CEND}"
  echo -e "${CGREEN}   4) Modification port SSH, mise à jour fail2ban, installation Iptables${CEND}"
  echo -e "${CGREEN}   5) Mise à jour Seedbox avec Cloudflare${CEND}"
  echo -e "${CGREEN}   6) Changement de Domaine && Modification des sous domaines${CEND}"
  echo -e "${CGREEN}   7) Retour menu principal${CEND}"

  echo -e ""
  read -p "Votre choix [1-8]: " OAUTH
  case $OAUTH in

  1)
    menu_secu_system_oauth2
    ;;

  2) ## auth classique, on supprime les valeurs oauth
    menu_secu_system_auth_classique
    ;;

  3)
    menu_secu_system_ajout_adresse_oauth2
    ;;

  4)
    menu_secu_systeme_iptables
    ;;

  5) ## Mise à jour Cloudflare
    menu_secu_systeme_cloudflare
    ;;

  6) ## Changement du nom de domaine
    menu_gestion_domaine
    ;;

  7)
    script_plexdrive
    ;;
  esac # case oauth
}

menu_gestion_motd() {
  clear
  echo ""
  motd
  pause
  script_plexdrive
}

menu_gestion_traktarr() {
  clear
  echo ""
  traktarr
  pause
  script_plexdrive
}

menu_gestion_webtools() {
  clear
  echo ""
  webtools
  pause
  script_plexdrive
}

menu_gestion_rtorrent_cleaner() {
  clear
  echo ""
  rtorrent-cleaner
  docker run -it --rm -v /home/${USER}/local/rutorrent:/home/${USER}/local/rutorrent -v /run/php:/run/php magicalex/rtorrent-cleaner
  pause
  script_plexdrive
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
  script_plexdrive
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

  script_plexdrive
}

function menu_gestion_install_filebot() {
  clear
  echo -e " ${BLUE}* Installation de filebot${NC}"
  echo ""
  ansible-playbook ${BASEDIR}/includes/config/roles/filebot/tasks/main.yml
  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
  read -r

  script_plexdrive
}

menu_gestion_utilitaires() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}UTILITAIRES${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Installation du motd${CEND}"
  echo -e "${CGREEN}   2) Traktarr${CEND}"
  echo -e "${CGREEN}   3) Webtools${CEND}"
  echo -e "${CGREEN}   4) rtorrent-cleaner de ${CCYAN}@Magicalex-Mondedie.fr${CEND}${NC}"
  echo -e "${CGREEN}   5) Plex_Patrol${CEND}"
  echo -e "${CGREEN}   6) Bloquer les ports non vitaux avec UFW${CEND}"
  echo -e "${CGREEN}   7) Configuration du Backup${CEND}"
  echo -e "${CGREEN}   8) Installation de filebot${CEND}"
  echo -e "${CGREEN}   10) Retour menu principal${CEND}"
  echo -e ""

  read -p "Votre choix [1-8]: " UTIL
  case $UTIL in

  \
    1) ## Installation du motd
    menu_gestion_motd
    ;;

  2) ## Installation de traktarr
    menu_gestion_traktarr
    ;;

  3) ## Installation de Webtools
    menu_gestion_webtools
    ;;

  4) ## Installation de rtorrent-cleaner
    menu_gestion_rtorrent_cleaner
    ;;

  5) ## Installation Plex_Patrol
    menu_gestion_plex_patrol
    ;;

  6)
    menu_gestion_ufw
    ;;

  7)
    menu_gestion_backup
    ;;

  8)
    menu_gestion_install_filebot
    ;;

  10)
    script_plexdrive
    ;;
  esac
}

menu_gestoutils_plexautoscan() {
  clear
  echo ""
  plex_autoscan
  pause
  script_plexdrive
}

menu_gestoutils_autoscan() {
  clear
  echo ""
  ansible-playbook ${BASEDIR}/includes/config/roles/autoscan/tasks/main.yml
  pause
  script_plexdrive
}

menu_gestoutils_cloudplow() {
  clear
  logo
  echo ""
  install_cloudplow
  pause
  script_plexdrive
}

menu_gestoutils_crop() {
  clear
  crop
  echo ""
  pause
  script_plexdrive
}

menu_gestoutils_dupefinder() {
  clear
  plex_dupefinder
  echo ""
  pause
  script_plexdrive
}

menu_gestoutils() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}OUTILS${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Plex_autoscan${CEND}"
  echo -e "${CGREEN}   2) Autoscan (Nouvelle version de Plex_autoscan)${CEND}"
  echo -e "${CGREEN}   3) Cloudplow${CEND}"
  echo -e "${CGREEN}   4) Crop (Nouvelle version de Cloudplow) => Experimental${CEND}"
  echo -e "${CGREEN}   5) Plex_dupefinder${CEND}"
  echo -e "${CGREEN}   6) Retour menu principal${CEND}"

  echo -e ""
  read -p "Votre choix [1-6]: " OUTILS
  case $OUTILS in

  1) ## Installation Plex_autoscan
    menu_gestoutils_plexautoscan
    ;;

  2) ## Installation Autoscan
    menu_gestoutils_autoscan
    ;;

  3) ## Installation Cloudplow
    menu_gestoutils_cloudplow
    ;;

  4) ## Installation Crop
    menu_gestoutils_crop
    ;;

  5) ## Installation plex_dupefinder
    menu_gestoutils_dupefinder
    ;;

  6)
    script_plexdrive
    ;;
  esac # case outils
}

menu_gest_service_account() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}COMPTES DE SERVICES${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Création des SA avec sa_gen${CEND}"
  echo -e "${CGREEN}   2) Création des SA avec safire${CEND}"
  echo -e "${CGREEN}   3) Retour menu principal${CEND}"
  echo -e ""
  read -p "Votre choix [1-3]: " SERVICES
  case $SERVICES in

  1) ## Création des SA avec gen-sa
    ${BASEDIR}/includes/config/scripts/sa-gen.sh
    script_plexdrive
    ;;

  2) ## Creation des SA avec safire
    ${BASEDIR}/includes/config/scripts/safire.sh
    script_plexdrive
    ;;

  3)
    script_plexdrive
    ;;
  esac # case services
}

menu_migr_meme_compte() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}MIGRATION GDRIVE ==> SHARE DRIVE$ => MEME COMPTE GOOGLE{CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Déplacer les données => Pas de limite ${CEND}"
  echo -e "${CGREEN}   2) Copier les données => 10 Tera par jour ${CEND}"
  echo -e "${CGREEN}   3) Retour menu principal${CEND}"
  echo ""
  read -p "Votre choix [1-3]: " MVEB
  case $MVEB in

  1) # Déplacer les données (Pas de limite)
    clear
    ${BASEDIR}/includes/config/scripts/migration.sh
    pause
    script_plexdrive
    ;;

  2) # Copier les données (10 Tera par jour)
    clear
    ${BASEDIR}/includes/config/scripts/sasync.sh
    pause
    script_plexdrive
    ;;

  3)
    script_plexdrive
    ;;
  esac
}

menu_migr_compte_diff() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}MIGRATION GDRIVE ==> SHARE DRIVE => COMPTES GOOGLE DIFFERENTS${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Déplacer les données => Pas de limite ${CEND}"
  echo -e "${CGREEN}   2) Copier les données => 1,8 Tera par jour ${CEND}"
  echo -e "${CGREEN}   3) Retour menu principal${CEND}"
  echo ""
  read -p "Votre choix [1-3]: " MVEBC
  case $MVEBC in

  1) # Déplacer les données (Pas de limite)
    clear
    ${BASEDIR}/includes/config/scripts/migration.sh
    pause
    script_plexdrive
    ;;

  2) # Copier les données (1,8 Tera par jour)
    clear
    ${BASEDIR}/includes/config/scripts/sasync-bwlimit.sh
    pause
    script_plexdrive
    ;;

  3)
    script_plexdrive
    ;;
  esac
}

menu_migr_gdrive2share() {
  clear
  logo
  echo ""
  echo -e "${CCYAN}MIGRATION GDRIVE ==> SHARE DRIVE${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) GDrive et Share Drive font partis du même compte Google ${CEND}"
  echo -e "${CGREEN}   2) GDrive et Share Drive sont sur deux comptes Google Différents ${CEND}"
  echo -e "${CGREEN}   3) Retour menu principal${CEND}"
  echo ""
  read -p "Votre choix [1-3]: " MVEA
  case $MVEA in
  1)
    menu_migr_meme_compte
    ;;
  2)
    menu_migr_compte_diff
    ;;
  3)
    script_plexdrive
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
  echo -e "${CGREEN}   3) Retour menu principal${CEND}"
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
    script_plexdrive
    ;;

  2) # Copier les données (10 Tera par jour)
    ${BASEDIR}/includes/config/scripts/sasync-share.sh
    pause
    script_plexdrive
    ;;

  3)
    script_plexdrive
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
  echo -e "${CGREEN}   3) Retour menu principal${CEND}"
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
    script_plexdrive
    ;;

  2) # Copier les données (10 Tera par jour)
    ${BASEDIR}/includes/config/scripts/sasync-share.sh
    pause
    script_plexdrive
    ;;

  3)
    script_plexdrive
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
  echo -e "${CGREEN}   3) Retour menu principal${CEND}"
  echo ""
  read -p "Votre choix [1-3]: " SHARE
  case $SHARE in

  1) ## migration share drive -> share drive meme compte
    menu_migr_share2share_mm_compte
    ;;

  2) ## migration share drive -> share drive compte diff
    menu_migr_share2share_compte_diff
    ;;
  3)
    script_plexdrive
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
  echo -e "${CGREEN}   3) Retour menu principal${CEND}"
  echo -e ""
  read -p "Votre choix [1-3]: " MIGRE
  case $MIGRE in

  1) ## migration gdrive -> share drive
    menu_migr_gdrive2share
    ;;

  2) ## migration share drive -> share drive
    menu_migr_share2share
    ;;
  3)
    script_plexdrive
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
    script_plexdrive
    ;;

  2)
    clear
    ${BASEDIR}/includes/config/scripts/fusermount.sh
    ${BASEDIR}/includes/config/scripts/rclone.sh
    ${BASEDIR}/includes/config/scripts/plexdrive.sh
    install_plexdrive
    echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
    read -r
    script_plexdrive
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
    script_plexdrive
    ;;
  esac # case $RCLONE

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
  echo -e "${CGREEN}   8) Retour menu principal${CEND}"
  echo -e ""
  read -p "Votre choix [1-8]: " GESTION

  case $GESTION in

  1) ## 2.1 sécurisation systeme
    menu_securisation_systeme
    ;;
  2) ## 2.2 Gestion - utilitaires
    menu_gestion_utilitaires
    ;;

  3) ### 2.3 - gestion -  creation share drive + rclone.conf
    clear
    echo ""
    ${BASEDIR}/includes/config/scripts/createrclone.sh
    ;;

  4) ## 2 . 4 - gestion - Outils
    menu_gestoutils
    ;;

  5) ## 2.5 - Gestion - Comptes de Services
    menu_gest_service_account
    ;;

  6) ## 2.6 - gestion - Migration Gdrive - Share Drive --> share drive
    menu_migr
    ;;

  7) # 2.7 - Installation Rclone vfs && Plexdrive
    menu_install_rclone_plexdrive
    ;;

  8) ## 2.8 - Gestion retour menu principal
    script_plexdrive
    ;;
  esac
}


function test_menu_sde() {
  ls
  pause
}
