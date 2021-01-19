#!/bin/bash

# Absolute path to this script.
CURRENT_SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
export SCRIPTPATH=$(dirname "$CURRENT_SCRIPT")
cd ${SCRIPTPATH}


# shellcheck source=${BASEDIR}/includes/functions.sh
source "${SCRIPTPATH}/includes/functions.sh"
# shellcheck source=${BASEDIR}/includes/variables.sh
source "${SCRIPTPATH}/includes/variables.sh"
# shellcheck source=${BASEDIR}/includes/functions.sh
source "${SCRIPTPATH}/includes/functions.sh"

if [ ! -f ${SCRIPTPATH}/.prerequis.lock ]; then
    echo "Les prérequis ne sont pas installés"
    echo "Vous devez les lancer en tapant"
    echo "./prerequis.sh"
    exit 1
fi

################################################
# récupération des parametre
# valeurs par défaut
FORCE_ROOT=0
INI_FILE=${SCRIPTPATH}/autoinstall.ini
action=manuel
export mode_install=manuel
# lecture des parametres
OPTS=`getopt -o vhns: --long \
    help,action:,ini-file:,force-root \
    -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "${OPTS}"

while true; do
  case "$1" in
    --action)
      export action=$2
      export mode_install=auto
      shift 2
      ;;

    --force-root)
      FORCE_ROOT=1
      shift
      ;;
      
    --ini-file)
      INI_FILE=$2
      shift 2
      ;;
      
    --help)
      
      usage
      shift
      ;;

    --) shift ; break ;;
    *) echo "Internal error! $2" ; exit 1 ;;
  esac
done

#
# Maintenant, on a toutes les infos
#
if [ ! -f "${SCRIPTPATH}/ssddb" ]; then
  premier_lancement
  # on ajoute le PATH qui va bien, au cas où il ne soit pas pris en compte par le ~/.profile
  export PATH="$HOME/.local/bin:$PATH"
fi

 
case "$action" in
  install_gui)
    if [ ! -f ${INI_FILE} ]
    then
      echo "ERREUR, fichier d'autoinstall non trouvé !"
      exit 1
    fi
    source <(grep = ${INI_FILE})
    install_gui

    exit 0
    ;;
  manuel)
    # pas d'action passée, on sort du case
    ;;
  *)
    echo "Action $action inconnue"
    exit 1
    ;;
esac


# Si on est ici, c'est a priori qu'on n'a pas passé d'option
# ou en tout cas qu'on n'a pas redirigé vers une fonction
# spécifique

################################################
# TEST ROOT USER
if [ "$USER" == "root" ]; then
  if [ "$FORCE_ROOT" == 0]
  then
    echo -e "${CCYAN}-----------------------${CEND}"
    echo -e "${CCYAN}[  Lancement en root  ]${CEND}"
    echo -e "${CCYAN}-----------------------${CEND}"
    echo -e "${CCYAN}Pour des raisons de sécurité, il n'est pas conseillé de lancer ce script en root${CEND}"
    echo -e "${CCYAN}-----------------------${CEND}"
    echo -e "${CCYAN}Vous pouvez continuer en root en passant l'option --force-root en parametre${CEND}"
    read -rp $'\e[33mSouhaitez vous créer un utilisateur dédié (c), ou quitter le script (q) ? (c/r/Q)\e[0m :' CREEUSER
    
    if [[ "${CREEUSER}" = "c" ]] || [[ "${CREEUSER}" = "C" ]]; then
      read -rp $'\e[33mTapez le nom d utilisateur\e[0m :' CREEUSER_USERNAME
      read -rp $'\e[33mTapez le password (pas de \ ni apostrophe dans le password) \e[0m :' CREEUSER_PASSWORD
      ansible-playbook ${BASEDIR}/includes/config/playbooks/cree_user.yml --extra-vars '{"CREEUSER_USERNAME":"'${CREEUSER_USERNAME}'","CREEUSER_PASSWORD":"'${CREEUSER_PASSWORD}'"}'
      echo -e "${CCYAN}L'utilisateur ${CREEUSER_USERNAME} a été créé, merci de vous déloguer et reloguer avec ce user pour continer${CEND}"
      exit 0
    else
      exit 0
    fi
  fi
fi





# on met les droits comme il faut, au cas où il y ait eu un mauvais lancement
sudo chown -R ${USER}: ${SCRIPTPATH}

if [[ -d "${HOME}/.local" ]]
then
  sudo chown -R ${USER}: ${HOME}/.local
fi

# on ajoute le PATH qui va bien, au cas où il ne soit pas pris en compte par le ~/.profile
export PATH="$HOME/.local/bin:$PATH"




################################################
# on vérifie qu'il y ait un vault pass existant
# Sinon ansible va râler au lancement
# Le password sera bien sur écrasé plus tard
if [ ! -f "${HOME}/.vault_pass" ]; then
  echo "0" >  ${HOME}/.vault_pass
fi

IS_INSTALLED=$(select_seedbox_param "installed")




#clear

if [ $mode_install = "manuel" ]
then


  if [[ ${IS_INSTALLED} -eq 0 ]]; then
    # Si on est là, c'est que le prérequis sont installés, mais c'est tout
    # On propose donc l'install de la seedbox
    clear
    logo
    echo -e "${CCYAN}INSTALLATION SEEDBOX DOCKER${CEND}"
    echo -e "${CGREEN}${CEND}"
    echo -e "${CGREEN}   1) Installation Seedbox rclone && gdrive${CEND}"
    echo -e "${CGREEN}   2) Installation Seedbox Classique ${CEND}"
    echo -e "${CGREEN}   3) Restauration Seedbox${CEND}"
    echo -e "${CGREEN}   9) Sortir du script${CEND}"

    echo -e ""
    read -p "Votre choix : " CHOICE
    echo ""
    case $CHOICE in


    1) ## Installation de la seedbox Rclone et Gdrive

      #check_dir "$PWD"
      if [[ ${IS_INSTALLED} -eq 0 ]]; then
        clear
        # on met la timezone
        #ansible-playbook ${BASEDIR}/includes/config/playbooks/timezone.yml
        # Dépendances pour ansible (permet de créer le docker network)
        ansible-galaxy  collection install community.general
        # on vérifie les droits sur répertoire et bdd
        make_dir_writable ${BASEDIR}
        change_file_owner ${BASEDIR}/ssddb
        # On crée le conf dir (par défaut /opt/seedbox) s'il n'existe pas
        conf_dir
        # Maj du système
        update_system
        # On crée le dossier status
        status
        # Install des packages de base
        install_base_packages
        # Install de docker
        install_docker
        #  On part à la pêche aux infos
        create_user_non_systeme
        # récup infos cloudflare
        cloudflare
        # récup infos oauth
        oauth
        # Install de traefik
        # BLOQUANT si erreur
        install_traefik
        # Installation et configuration de rclone
        install_rclone
        # Install de watchtower
        install_watchtower
        # Install fail2ban
        install_fail2ban
        # Choix des dossiers et création de l'arborescence
        choose_media_folder_plexdrive
        # Installation de mergerfs
        # Cette install a une incidence sur docker (dépendances dans systemd)
        unionfs_fuse
        pause
        # Choix des services à installer
        # Jusque là, on ne fait que les choisir, et les stocker dans un fichier texte
        #choose_services
        # On choisit les sous domaines pour les services installés précédemment
        # stocké dans account.yml
        #subdomain
        # On choisit le mode d'authentification, basqiue, oauth, authelia
        # stoké dans account.yml
        #auth
        #Installation de tous les services
        #install_services
        # Mise à jour de plex, ajout des librairies

        #for i in $(docker ps --format "{{.Names}}")
        #do
        #  if [[ "$i" == "plex" ]]; then
        #    plex_sections
        #  fi
        #done

        # Installation de filebot
        # TODO : à laisser ? Ou à mettre dans les applis ?

        #filebot
        # mise en place de la sauvegarde
        sauve
        # Affichage du résumé
        #resume_seedbox
        #pause
        ansible-vault encrypt ${CONFDIR}/variables/account.yml >/dev/null 2>&1
        script_plexdrive
        # on marque la seedbox comme installée
        update_seedbox_param "installed" 1
      else
        script_plexdrive
      fi
      ;;

    2) ## Installation de la seedbox classique

      check_dir "$PWD"
      if [[ ! -d "$CONFDIR" ]]; then
        clear
        conf_dir
        update_system
        install_base_packages
        install_docker
        define_parameters
        cloudflare
        oauth
        install_traefik
        install_watchtower
        install_fail2ban
        choose_media_folder_classique
        choose_services
        subdomain
        install_services
        filebot
        resume_seedbox
        pause
        ansible-vault encrypt ${CONFDIR}/variables/account.yml >/dev/null 2>&1
        touch "${CONFDIR}/media-$SEEDUSER"
        script_classique
      else
        script_classique
      fi
      ;;

    3) ## restauration de la seedbox

      check_dir "$PWD"
      if [[ ! -d "$CONFDIR" ]]; then
        clear
        echo ""
        echo -e "${CRED}---------------------------------------------------------------${CEND}"
        echo -e "${CRED} /!\ ATTENTION : PREPARATION DE LA RESTAURATION DU SERVEUR /!\ ${CEND}"
        echo -e "${CRED}---------------------------------------------------------------${CEND}"
        echo ""
        conf_dir
        update_system
        install_base_packages
        install_docker
        define_parameters
        install_rclone
        install_fail2ban
        sauve
        restore
        choose_media_folder_plexdrive
        rm /etc/systemd/system/mergerfs.service >/dev/null 2>&1
        unionfs_fuse
        cloudflare
        install_traefik
        install_watchtower

        while read line; do echo $line | cut -d'.' -f1; done <"/home/$SEEDUSER/resume" >"$SERVICESUSER$SEEDUSER"
        rm "/home/$SEEDUSER/resume"
        install_services

        ## restauration plex_dupefinder
        PLEXDUPE=/home/$SEEDUSER/scripts/plex_dupefinder/plex_dupefinder.py
        if [[ -e "$PLEXDUPE" ]]; then
          cd "/home/$SEEDUSER/scripts/plex_dupefinder"
          python3 -m pip install -r requirements.txt
        fi

        ## restauration cloudplow
        CLOUDPLOWSERVICE=/etc/systemd/system/cloudplow.service
        if [[ -e "$CLOUDPLOWSERVICE" ]]; then
          cd "/home/$SEEDUSER/scripts/cloudplow"
          python3 -m pip install -r requirements.txt
          ln -s /home/$SEEDUSER/scripts/cloudplow/cloudplow.py /usr/local/bin/cloudplow
          systemctl start cloudplow.service
        fi

        ## restauration plex_autoscan
        PLEXSCANSERVICE=/etc/systemd/system/plex_autoscan.service
        if [[ -e "$PLEXSCANSERVICE" ]]; then
          cd "/home/$SEEDUSER/scripts/plex_autoscan"
          python -m pip install -r requirements.txt
          systemctl start plex_autoscan.service
        fi

        ## restauration des crons
        (
          crontab -l | grep .
          echo "*/1 * * * * ${CONFDIR}/docker/$SEEDUSER/.filebot/filebot-process.sh"
        ) | crontab -
        ln -s "/home/$SEEDUSER/scripts/plex_dupefinder/plex_dupefinder.py" /usr/local/bin/plexdupes
        rm $SERVICESUSER$SEEDUSER
        checking_errors $?
        echo ""
        echo -e "${CRED}---------------------------------------------------------------${CEND}"
        echo -e "${CRED}     /!\ RESTAURATION DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
        echo -e "${CRED}---------------------------------------------------------------${CEND}"
        echo ""
        pause
        ansible-vault encrypt ${CONFDIR}/variables/account.yml >/dev/null 2>&1
        script_plexdrive
      else
        script_plexdrive
      fi
      ;;
    9)
      exit 0
      ;;

    999) ## Installation seedbox webui
        install_gui
     ;;

    esac
  fi
  


  update_status

  PLEXDRIVE="/usr/bin/rclone"
  if [[ -e "$PLEXDRIVE" ]]; then
    script_plexdrive
  else
    script_classique
  fi
fi
