#!/bin/bash
clear

          echo -e "\e[36m############################################################################################\e[0m"
          echo -e "\e[36m###                        INSTALLATION GLUETUN                                          ###\e[0m"
          echo -e "\e[36m###                                                                                      ###\e[0m"
          echo -e "\e[36m###   Gluetun supporte nativement l'intégration Wireguard pour les providers suivant:    ###\e[0m"
          echo -e "\e[36m###   AirVPN, Ivpn, Mullvad, NordVPN, Surfshark, Windscribe                              ###\e[0m"
          echo -e "\e[36m###   Se référer à la page du wiki pour la configuration de ces vpn                      ###\e[0m"
          echo -e "\e[36m###   Gluetun supporte également une configuration wireguard personnalisée               ###\e[0m"
          echo -e "\e[36m###   pour certains clients notamment Torguard and VPN Unlimited                          ###\e[0m"
          echo -e "\e[36m###                                                                                      ###\e[0m"
          echo -e "\e[36m###   Toutes les informations nécessaires (quelque soit le provider)                     ###\e[0m"
          echo -e "\e[36m###   demandées dans le script figurent dans le lien ci dessous                          ###\e[0m"
          echo -e "\e[36m###   wiki: https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers              ###\e[0m"
          echo -e "\e[36m###                                                                                      ###\e[0m"
          echo -e "\e[36m###                                                                                      ###\e[0m"
          echo -e "\e[36m############################################################################################\e[0m"
          echo ""

source "${SETTINGS_SOURCE}/includes/functions.sh"
manage_account_yml vpn

#demander à l'utilisateur s'il souhaite une config custum
echo -e "\e[32mEst ce que votre VPN demande une config custom ? (O/N) \e[0m"
read reponse
manage_account_yml config "$read reponse"

if [[ "$reponse" = "O" ]] || [[ "$reponse" = "o" ]]; then
  VPN_SERVICE_PROVIDER=custom
  manage_account_yml vpn.service_provider "$VPN_SERVICE_PROVIDER"

  echo -e "\e[32mNom du protocole (openvpn ou wireguard): \e[0m"
  read VPN_TYPE
  VPN_TYPE=$(echo $VPN_TYPE | tr ‘[A-Z]’ ‘[a-z]’)
  manage_account_yml vpn.type "$VPN_TYPE"

  if [[ $VPN_TYPE = wireguard ]]; then
    echo -e "\e[32mAdresse ip de l'Endpoint: \e[0m"
    read VPN_ENDPOINT_IP
    manage_account_yml vpn.endpoint "$VPN_ENDPOINT_IP" 

    echo -e "\e[32mPort de l'Endpoint: \e[0m"
    read VPN_ENDPOINT_PORT
    manage_account_yml vpn.port "$VPN_ENDPOINT_PORT"

    echo -e "\e[32mVotre clé publique: \e[0m"
    read WIREGUARD_PUBLIC_KEY
    manage_account_yml vpn.wireguard_publique "$WIREGUARD_PUBLIC_KEY"

    echo -e "\e[32mVotre clé privée: \e[0m"
    read WIREGUARD_PRIVATE_KEY
    manage_account_yml vpn.wireguard_prive "$WIREGUARD_PRIVATE_KEY"

    echo -e "\e[32mVotre clé preshared: \e[0m"
    read WIREGUARD_PRESHARED_KEY
    manage_account_yml vpn.wireguard_preshared "$WIREGUARD_PRESHARED_KEY"

    echo -e "\e[32mEntrer la plage adresse: \e[0m"
    read WIREGUARD_ADDRESSES
    manage_account_yml vpn.adresse "$WIREGUARD_ADDRESSES"

  else

    echo -e "\e[32mEntrer le chemin ou se situe votre custom.conf openvpn ex: /home/toto/custom.conf \e[0m"
    read OPENVPN_CUSTOM_CONFIG
    OPENVPN_CUSTOM_CONFIG=$(echo $OPENVPN_CUSTOM_CONFIG  | tr ‘[A-Z]’ ‘[a-z]’)
    manage_account_yml vpn.config "$OPENVPN_CUSTOM_CONFIG"

    echo -e "\e[32mEntrer le nom d'utilsateur openvpn \e[0m"
    read OPENVPN_USER
    manage_account_yml vpn.openvpn_user "$OPENVPN_USER"

    echo -e "\e[32mEntrer le mot de passe de votre compte openvpn \e[0m"
    read OPENVPN_PASSWORD
    manage_account_yml vpn.openvpn_password "$OPENVPN_PASSWORD"

  fi

else

  echo -e "\e[32mNom de votre provider: \e[0m"
  read VPN_SERVICE_PROVIDER
  VPN_SERVICE_PROVIDER=$(echo $VPN_SERVICE_PROVIDER  | tr ‘[A-Z]’ ‘[a-z]’)
  manage_account_yml vpn.service_provider "$VPN_SERVICE_PROVIDER"

  echo -e "\e[32mNom du protocole (openvpn ou wireguard): \e[0m"
  read VPN_TYPE
  VPN_TYPE=$(echo $VPN_TYPE  | tr ‘[A-Z]’ ‘[a-z]’)
  manage_account_yml vpn.type "$VPN_TYPE"

  if [[ "$VPN_TYPE" = "openvpn" ]]; then
    echo -e "\e[32mNom d'utilisateur de votre compte openvpn: \e[0m"
    read OPENVPN_USER
    manage_account_yml vpn.openvpn_user "$OPENVPN_USER"

    echo -e "\e[32mMot de passe de votre compte openvpn: \e[0m"
    read OPENVPN_PASSWORD
    manage_account_yml vpn.openvpn_password "$OPENVPN_PASSWORD"

    echo -e "\e[32mLocalité du serveur vpn: \e[0m"
    read SERVER_COUNTRIES
    SERVER_COUNTRIES=$(echo $SERVER_COUNTRIES  | tr ‘[A-Z]’ ‘[a-z]’)
    manage_account_yml vpn.country "$SERVER_COUNTRIES"

  elif [[ "$VPN_TYPE" = "wireguard" ]]; then
    echo -e "\e[32mClé privée de votre compte wireguard: \e[0m"
    read WIREGUARD_PRIVATE_KEY
    manage_account_yml vpn.wireguard_prive "$WIREGUARD_PRIVATE_KEY"

    echo -e "\e[32mEntrer la plage adresse de wireguard: \e[0m"
    read WIREGUARD_ADDRESSES
    manage_account_yml vpn.adresse "$WIREGUARD_ADDRESSES"

    echo -e "\e[32mLocalité du serveur vpn: \e[0m"
    read SERVER_COUNTRIES
    SERVER_COUNTRIES=$(echo $SERVER_COUNTRIES  | tr ‘[A-Z]’ ‘[a-z]’)
    manage_account_yml vpn.country "$SERVER_COUNTRIES"

  fi
fi




