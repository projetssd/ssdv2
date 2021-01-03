#!/bin/bash

# Absolute path to this script.
CURRENT_SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
export SCRIPTPATH=$(dirname "$CURRENT_SCRIPT")

# On disque d'avoir besoin de ces variables d'environnement par la suite
export MYUID=$(id -u)
export MYGID=$(id -g)


if [ ! -f "${SCRIPTPATH}/ssddb" ]; then
   echo "Les prérequis ne sont pas installés"
  read -p "Appuyez sur entrée pour continuer, ou ctrl+c pour sortir"
  ## Constants
  readonly PIP="9.0.3"
  readonly ANSIBLE="2.9"
  ##########################################
  # Pas de configuration existante
  # On installe les prérequis
  ##########################################
 
  echo "Installation en cours ...."
  
  mkdir -p ~/.ansible/inventories
  
  ###################################
  # Configuration ansible
  # Pour le user courant uniquement
  ###################################
  mkdir -p /etc/ansible/inventories/ 1>/dev/null 2>&1
  cat <<EOF > ~/.ansible/inventories/local
  [local]
  127.0.0.1 ansible_connection=local
EOF

  cat <<EOF > ~/.ansible.cfg
  [defaults]
  command_warnings = False
  callback_whitelist = profile_tasks
  deprecation_warnings=False
  inventory = ~/.ansible/inventories/local
  interpreter_python=/usr/bin/python3
  vault_password_file = ~/.vault_pass
  log_path=${SCRIPTPATH}/logs/ansible.log
EOF

  echo "Création de la configuration en cours"
  # On créé la database
  sqlite3 ${SCRIPTPATH}/ssddb <<EOF
    create table seedbox_params(param varchar(50) PRIMARY KEY, value varchar(50));
    replace into seedbox_params (param,value) values ('installed',0);
    replace into seedbox_params (param,value) values ('seedbox_path','/opt/seedbox');
    create table applications(name varchar(50) PRIMARY KEY,
      status integer,
      subdomain varchar(50),
      port integer);
    create table applications_params (appname varchar(50),
      param varachar(50),
      value varchar(50),
      FOREIGN KEY(appname) REFERENCES applications(name));
EOF
  read -p "Appuyez sur entrée pour continuer, ou ctrl+c pour sortir"

fi



# shellcheck source=${BASEDIR}/includes/functions.sh
source "${SCRIPTPATH}/includes/functions.sh"
# shellcheck source=${BASEDIR}/includes/variables.sh
source "${SCRIPTPATH}/includes/variables.sh"

################################################
# on vérifie qu'il y ait un vault pass existant
# Sinon ansible va râler au lancement
# Le password sera bien sur écrasé plus tard
if [ ! -f "${HOME}/.vault_pass" ]; then
  echo "0" >  ${HOME}/.vault_pass
fi

#######################################
# On regarde si le user est dans
# le groupe docker
if getent group docker | grep -q "\b${USER}\b"; then
    # A voir si un réutilise par la suite
    DOCKER_OK=1
else
    ansible-playbook ${BASEDIR}/includes/config/roles/users/tasks/main.yml
    
    echo -e "${RED}-----------------------${CEND}"
    echo -e "${RED}ATTENTION ! ${CEND}"
    echo -e "${RED}Votre utilisateur n'était pas dans le groupe docker${CEND}"
    echo -e "${RED}Il a été ajouté, mais vous devez vous déloguer/reloguer${CEND}"
    echo -e "${RED}avant de relancer le script${CEND}"
    exit 1
fi

IS_INSTALLED=$(select_seedbox_param "installed")


################################################
# TEST ROOT USER
if [ "$USER" == "root" ]; then
  echo -e "${CCYAN}-----------------------${CEND}"
  echo -e "${CCYAN}[  Lancement en root  ]${CEND}"
  echo -e "${CCYAN}-----------------------${CEND}"
  echo -e "${CCYAN}Pour des raisons de sécurité, il n'est pas conseillé de lancer ce script en root${CEND}"
  read -rp $'\e[33mSouhaitez vous créer un utilisateur dédié (c), continuer en root (r) ou quitter le script (q) ? (c/r/Q)\e[0m :' CREEUSER
  if [[ "${CREEUSER}" = "r" ]] || [[ "${CREEUSER}" = "R" ]]; then
    # on ne fait rien et on continue
    :
  elif [[ "${CREEUSER}" = "c" ]] || [[ "${CREEUSER}" = "C" ]]; then
    read -rp $'\e[33mTapez le nom d utilisateur\e[0m :' CREEUSER_USERNAME
    read -rp $'\e[33mTapez le password (pas de \ ni apostrophe dans le password) \e[0m :' CREEUSER_PASSWORD
    ansible-playbook ${BASEDIR}/includes/config/playbooks/cree_user.yml --extra-vars '{"CREEUSER_USERNAME":"'${CREEUSER_USERNAME}'","CREEUSER_PASSWORD":"'${CREEUSER_PASSWORD}'"}'
    echo -e "${CCYAN}L'utilisateur ${CREEUSER_USERNAME} a été créé, merci de vous déloguer et reloguer avec ce user pour continer${CEND}"
    exit 0
  else
    exit 0
  fi
fi


clear






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
      # on met le user dans le bon groupe
      ansible-playbook ${BASEDIR}/includes/config/roles/users/tasks/main.yml
	    ansible-playbook ${BASEDIR}/includes/config/roles/users/tasks/chggroup.yml
      # On part à la pêche aux infos
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
      choose_services
      # On choisit les sous domaines pour les services installés précédemment
      # stocké dans account.yml
      subdomain
      # Installation de tous les services
      install_services
      # Mise à jour de plex, ajout des librairies
      for i in $(docker ps --format "{{.Names}}")
      do
        if [[ "$i" == "plex" ]]; then
          plex_sections
        fi
      done
      # choix des applis à installer
      projects
      # Installation de filebot
      # TODO : à laisser ? Ou à mettre dans les applis ?
      filebot
      # mise en place de la sauvegarde
      sauve
      # Affichage du résumé
      resume_seedbox
      pause
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
      SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
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
      # installation des dépendances, permet de créer les docker network via ansible
      ansible-galaxy collection install community.general
      # On vérifie que le user ait bien les droits d'écriture
      make_dir_writable ${BASEDIR}
      # on vérifie que le user ait bien les droits d'écriture dans la db
      change_file_owner ${BASEDIR}/ssddb
      # On crée le conf dir (par défaut /opt/seedbox) s'il n'existe pas
      conf_dir
      # On part à la pêche aux infos....
      ${BASEDIR}/includes/config/scripts/get_infos.sh
      echo ""
      # On crée les fichier de status à 0
      status
      # Mise à jour du système
      update_system
      # Installation des packages de base
      install_base_packages
      # Installation de docker
      install_docker
      # On ajoute le user courant au groupe docker
      ansible-playbook ${BASEDIR}/includes/config/roles/users/tasks/main.yml
      ansible-playbook ${BASEDIR}/includes/config/roles/users/tasks/chggroup.yml
      # On install nginx
      ansible-playbook ${BASEDIR}/includes/config/roles/nginx/tasks/main.yml
      # Installation de traefik
      install_traefik

      DOMAIN=$(select_seedbox_param "domain")

      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CRED}          /!\ INSTALLATION EFFECTUEE AVEC SUCCES /!\           ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CCYAN}              Adresse de l'interface WebUI                    ${CEND}"
      echo -e "${CCYAN}              https://${SUBDOMAIN}.${DOMAIN}                  ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""

      ansible-vault encrypt ${CONFDIR}/variables/account.yml > /dev/null 2>&1
      echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour sortir du script..."
      read -r
      exit 0
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
