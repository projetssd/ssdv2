#!/usr/bin/env python3
"""
Script permettant de choisir un teamdrive
dans le rclone.conf
"""
import configparser
import os


def detect_td():
    config = configparser.ConfigParser()
    config.read(os.environ['HOME'] + '/.config/rclone/rclone.conf')

    mytd = []  # la liste des td

    for section in config.sections():
        if "team_drive" in config[section]:
            mytd.append(section)

    return mytd


def choix_td():
    mystockage = input("Choisir le stockage principal associé à la seedbox : ")
    try:
        mystockage = int(mystockage)
        return mystockage
    except:
        choix_td()


def recherche_crypt(myremote):
    config = configparser.ConfigParser()
    config.read(os.environ['HOME'] + '/.config/rclone/rclone.conf')
    for section in config.sections():
        if config[section]['type'] == 'crypt':
            if myremote in config[section]['remote']:
                return section
    return False


def get_id_teamdrive(myremote):
    config = configparser.ConfigParser()
    config.read(os.environ['HOME'] + '/.config/rclone/rclone.conf')
    id_teamdrive = config[myremote]['team_drive']
    f2 = open("/tmp/id_teamdrive", "a")
    f2.write(id_teamdrive)
    f2.close()


# Déclaration des variables
dict_td = {}

# Choix du team drive
td = detect_td()


print("   Shared drives disponibles : ")
print("-------------------------------")
for (i, item) in enumerate(td, start=1):
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
