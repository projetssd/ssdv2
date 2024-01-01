#!/bin/bash
clear

echo -e "\e[36m"$(gettext "INSTALLATION GLUETUN")"\e[0m"
echo ""
echo -e "\e[36m"$(gettext "Gluetun supporte nativement l'intégration Wireguard pour les providers suivant :")"\e[0m"
echo -e "\e[36m"$(gettext "AirVPN, Ivpn, Mullvad, NordVPN, Surfshark, Windscribe")"\e[0m"
echo -e "\e[36m"$(gettext "Se référer à la page du wiki pour la configuration de ces vpn")"\e[0m"
echo -e "\e[36m"$(gettext "Gluetun supporte également une configuration wireguard personnalisée")"\e[0m"
echo -e "\e[36m"$(gettext "pour certains clients notamment Torguard and VPN Unlimited")"\e[0m"
echo -e ""
echo -e "\e[36m"$(gettext "Toutes les informations nécessaires (quelque soit le provider)")"\e[0m"
echo -e "\e[36m"$(gettext "demandées dans le script figurent dans le lien ci dessous")"\e[0m"
echo -e "\e[36m"$(gettext "wiki: https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers")"\e[0m"
echo ""

source "${SETTINGS_SOURCE}/includes/functions.sh"
manage_account_yml vpn

#demander à l'utilisateur s'il souhaite une config custum
echo -e "\e[32m"$(gettext "Est ce que votre VPN demande une config custom ? (y/n)")"\e[0m"
read reponse
manage_account_yml config "$read reponse"

if [[ "$reponse" = "Y" ]] || [[ "$reponse" = "y" ]]; then
  VPN_SERVICE_PROVIDER=custom
  manage_account_yml vpn.service_provider "$VPN_SERVICE_PROVIDER"

  echo -e "\e[32m"$(gettext "Nom du protocole (openvpn ou wireguard) :")"\e[0m"
  read VPN_TYPE
  VPN_TYPE=$(echo $VPN_TYPE | tr ‘[A-Z]’ ‘[a-z]’)
  manage_account_yml vpn.type "$VPN_TYPE"

  if [[ $VPN_TYPE = wireguard ]]; then
    echo -e "\e[32m"$(gettext "Adresse ip de l'Endpoint :")"\e[0m"
    read VPN_ENDPOINT_IP
    manage_account_yml vpn.endpoint "$VPN_ENDPOINT_IP" 

    echo -e "\e[32m"$(gettext "Port de l'Endpoint :")"\e[0m"
    read VPN_ENDPOINT_PORT
    manage_account_yml vpn.port "$VPN_ENDPOINT_PORT"

    echo -e "\e[32m"$(gettext "Votre clé publique :")"\e[0m"
    read WIREGUARD_PUBLIC_KEY
    manage_account_yml vpn.wireguard_publique "$WIREGUARD_PUBLIC_KEY"

    echo -e "\e[32m"$(gettext "Votre clé privée :")"\e[0m"
    read WIREGUARD_PRIVATE_KEY
    manage_account_yml vpn.wireguard_prive "$WIREGUARD_PRIVATE_KEY"

    echo -e "\e[32m"$(gettext "Votre clé preshared :")"\e[0m"
    read WIREGUARD_PRESHARED_KEY
    manage_account_yml vpn.wireguard_preshared "$WIREGUARD_PRESHARED_KEY"

    echo -e "\e[32m"$(gettext "Entrer la plage adresse :")"\e[0m"
    read WIREGUARD_ADDRESSES
    manage_account_yml vpn.adresse "$WIREGUARD_ADDRESSES"

  else

    echo -e "\e[32m"$(gettext "Entrer le chemin ou se situe votre custom.conf openvpn ex: /home/toto/custom.conf")"\e[0m"
    read OPENVPN_CUSTOM_CONFIG
    OPENVPN_CUSTOM_CONFIG=$(echo $OPENVPN_CUSTOM_CONFIG  | tr ‘[A-Z]’ ‘[a-z]’)
    manage_account_yml vpn.config "$OPENVPN_CUSTOM_CONFIG"

    echo -e "\e[32m"$(gettext "Nom d'utilsateur openvpn :")"\e[0m"
    read OPENVPN_USER
    manage_account_yml vpn.openvpn_user "$OPENVPN_USER"

    echo -e "\e[32m"$(gettext "Mot de passe de votre compte openvpn :")"\e[0m"
    read OPENVPN_PASSWORD
    manage_account_yml vpn.openvpn_password "$OPENVPN_PASSWORD"

  fi

else

  echo -e "\e[32m"$(gettext "Nom de votre provider :")"\e[0m"
  read VPN_SERVICE_PROVIDER
  VPN_SERVICE_PROVIDER=$(echo $VPN_SERVICE_PROVIDER  | tr ‘[A-Z]’ ‘[a-z]’)
  manage_account_yml vpn.service_provider "$VPN_SERVICE_PROVIDER"

  echo -e "\e[32m"$(gettext "Nom du protocole (openvpn ou wireguard) :")"\e[0m"
  read VPN_TYPE
  VPN_TYPE=$(echo $VPN_TYPE  | tr ‘[A-Z]’ ‘[a-z]’)
  manage_account_yml vpn.type "$VPN_TYPE"

  if [[ "$VPN_TYPE" = "openvpn" ]]; then
    echo -e "\e[32m"$(gettext "Nom d'utilisateur openvpn :")"\e[0m"
    read OPENVPN_USER
    manage_account_yml vpn.openvpn_user "$OPENVPN_USER"

    echo -e "\e[32m"$(gettext "Mot de passe de votre compte openvpn :")"\e[0m"
    read OPENVPN_PASSWORD
    manage_account_yml vpn.openvpn_password "$OPENVPN_PASSWORD"

    echo -e "\e[32m"$(gettext "Localité du serveur vpn :")"\e[0m"
    read SERVER_COUNTRIES
    SERVER_COUNTRIES=$(echo $SERVER_COUNTRIES  | tr ‘[A-Z]’ ‘[a-z]’)
    manage_account_yml vpn.country "$SERVER_COUNTRIES"

  elif [[ "$VPN_TYPE" = "wireguard" ]]; then
    echo -e "\e[32m"$(gettext "Clé privée de votre compte wireguard :")"\e[0m"
    read WIREGUARD_PRIVATE_KEY
    manage_account_yml vpn.wireguard_prive "$WIREGUARD_PRIVATE_KEY"

    echo -e "\e[32m"$(gettext "Entrer la plage adresse de wireguard :")"\e[0m"
    read WIREGUARD_ADDRESSES
    manage_account_yml vpn.adresse "$WIREGUARD_ADDRESSES"

    echo -e "\e[32m"$(gettext "Localité du serveur vpn :")"\e[0m"
    read SERVER_COUNTRIES
    SERVER_COUNTRIES=$(echo $SERVER_COUNTRIES  | tr ‘[A-Z]’ ‘[a-z]’)
    manage_account_yml vpn.country "$SERVER_COUNTRIES"

  fi
fi




