
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
    try:
        id_teamdrive = config[myremote]['team_drive']
    except:
        id_teamdrive = ""
    f2 = open("/tmp/id_teamdrive", "a")
    f2.write(id_teamdrive)
    f2.close()

def detect_gd():
    config = configparser.ConfigParser()
    config.read(os.environ['HOME'] + '/.config/rclone/rclone.conf')

    mytd = []  # la liste des td

    for section in config.sections():
        if "team_drive" not in config[section]:
            if config[section]['type'] != 'crypt' and config[section]['type'] != 'cache':
                mytd.append(section)

    return mytd