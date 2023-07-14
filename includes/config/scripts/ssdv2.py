import os
import sys
import subprocess
# gestion des questions/checkboxes
import inquirer
# lancement de playbooks
import ansible_runner
# lecture des yml
import yaml
from yaml.loader import SafeLoader
# menus
from simple_term_menu import TerminalMenu
import gettext

settings_source = os.environ['SETTINGS_SOURCE']
settings_storage = os.environ['SETTINGS_STORAGE']
generique_bash = settings_source + "/includes/config/scripts/generique.sh"

gettext.bindtextdomain('ks', settings_source + '/i18n')
gettext.textdomain('ks')
_ = gettext.gettext

def choix_appli_lance():
    """
    Affiche une liste de choix (checkbox) des applis à installer
    Installe les applis choisies une à une
    """
    list_applis = []
    basepath = settings_source + '/includes/dockerapps/vars/'
    persopath = settings_storage + '/vars/'
    # On fait la liste des applis officielles
    for entry in os.listdir(basepath):
        if os.path.isfile(os.path.join(basepath, entry)):
            # on a un fichier
            if entry.endswith('.yml'):
                # C'est un fichier yaml
                with open(basepath + entry) as f:
                    data = yaml.load(f, Loader=SafeLoader)
                    application = data['pgrole']
                    # on gère le cas où il n'y a pas de description
                    try:
                        description = data['description']
                    except:
                        description = data['pgrole']
                # On crée un tuple (appli - desc, appli)
                list_applis.append((application + ' - ' + description, application))
    # On fait la liste des applis persos
    for entry in os.listdir(persopath):
        if os.path.isfile(os.path.join(persopath, entry)):
            # on a un fichier
            if entry.endswith('.yml'):
                # C'est un fichier yaml
                with open(persopath + entry) as f:
                    data = yaml.load(f, Loader=SafeLoader)
                    application = data['pgrole']
                    # on gère le cas où il n'y a pas de description

                    try:
                        old_description = data['description']
                    except:
                        old_description = data['pgrole']
                    description = '[PERSO] - ' + old_description
                # On regarde si on a déjà cette appli dans la première liste
                if (application + ' - ' + old_description, application) in list_applis:
                    list_applis.remove((application + ' - ' + old_description, application))
                # On crée un tuple (appli - desc, appli)
                list_applis.append((application + ' - ' + description, application))
    # On trie la liste par ordre alpha
    list_applis.sort()
    questions = [
        inquirer.Checkbox('applications',
                          message=_("Sélectionner les applications à") + " " + _("installer"),
                          choices=list_applis,
                          ),
    ]
    lance_applis(inquirer.prompt(questions)['applications'])


def lance_applis(list_applis):
    """
    Lance une liste d'applis (passe par le générique bash pour utiliser une fonction)
    """
    for my_appli in list_applis:
        subprocess.run(
            [generique_bash, "launch_service", my_appli])
