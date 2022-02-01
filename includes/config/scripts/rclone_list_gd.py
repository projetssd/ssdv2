#!/usr/bin/env python3
"""
Script permettant de choisir un google drive
dans le rclone.conf
"""

import ssd_rclone







# Déclaration des variables
dict_td = {}

# Choix du team drive
td = ssd_rclone.detect_gd()


print("   Google drives disponibles : ")
print("-------------------------------")
for (i, item) in enumerate(td, start=1):
    print(i, item)
    dict_td[i] = item

stockage = 0
print("")

stockage = ssd_rclone.choix_td()
while stockage not in dict_td:
    stockage = ssd_rclone.choix_td()
remote = dict_td[stockage]
print("Source sélectionnée : " + remote)

ssd_rclone.get_id_teamdrive(remote)

# Recherche d'un remote de type crypt associé

crypt = ssd_rclone.recherche_crypt(remote)
if not crypt:
    print("Erreur, aucun remote de type crypt trouvé, fallback sur le non chiffré")
    crypt = remote
else:
    print("le remote de type crypt est " + crypt)


f = open("/tmp/choix_crypt", "a")
f.write(crypt)
f.close()
