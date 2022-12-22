#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Bibliotheques pour gérer les fonctions python
d'interaction avec rclone pour ssd
"""
import configparser
import os


def detect_td():
    """
    Fonction de choix d'un teamdrive
    Génère une liste des td
    """
    config = configparser.ConfigParser()
    config.read(os.environ['HOME'] + '/.config/rclone/rclone.conf')

    mytd = []  # la liste des td

    for section in config.sections():
        if "team_drive" in config[section]:
            mytd.append(section)

    return mytd


def detect_gd():
    """
    Fonction de choix d'un google drive
    Génère une liste des gd
    """
    config = configparser.ConfigParser()
    config.read(os.environ['HOME'] + '/.config/rclone/rclone.conf')

    mytd = []  # la liste des td

    for section in config.sections():
        if config[section]['type'] == 'drive':
            mytd.append(section)
    return mytd


def choix_td():
    """
    Juste la fonction d'input
    teste si on a bien un integer, si oui, le retourne
    sinon, revient sur elle même
    :return: integer
    """
    mystockage = input("Choisir le stockage principal associé à la seedbox : ")
    try:
        mystockage = int(mystockage)
        return mystockage
    except:
        choix_td()


def recherche_crypt(myremote):
    """
    Recherche si un remote de type crypt existe
    pour le remote donné en parametre
    :param myremote: nom du remote
    :return: remote chiffré associé
    """
    config = configparser.ConfigParser()
    config.read(os.environ['HOME'] + '/.config/rclone/rclone.conf')
    for section in config.sections():
        if config[section]['type'] == 'crypt':
            if myremote in config[section]['remote']:
                return section
    return False


def get_id_teamdrive(myremote):
    """
    Cherche l'id du teamdrive associé au remote
    :param myremote: nom du remote
    :return: nom du team drive|False
    """
    config = configparser.ConfigParser()
    config.read(os.environ['HOME'] + '/.config/rclone/rclone.conf')
    try:
        id_teamdrive = config[myremote]['team_drive']
    except:
        id_teamdrive = ""
    f2 = open("/tmp/id_teamdrive", "a")
    f2.write(id_teamdrive)
    f2.close()


def affiche_drive(drives):
    """
    Affiche la liste des drives, et demande au user de choisir
    :param drives: liste de remotes
    :return:
    """
    dict_td = {}
    print("-------------------------------")
    for (i, item) in enumerate(drives, start=1):
        print(i, item)
        dict_td[i] = item

    stockage = 0
    print("")

    stockage = choix_td()
    while stockage not in dict_td:
        stockage = choix_td()
    remote = dict_td[stockage]
    print("Source sélectionnée : " + remote)

    get_id_teamdrive(remote)

    # Recherche d'un remote de type crypt associé

    crypt = recherche_crypt(remote)
    if not crypt:
        print("Erreur, aucun remote de type crypt trouvé, fallback sur le non chiffré")
        crypt = remote
    else:
        print("le remote de type crypt est " + crypt)

    f = open("/tmp/choix_crypt", "a")
    f.write(crypt)
    f.close()
