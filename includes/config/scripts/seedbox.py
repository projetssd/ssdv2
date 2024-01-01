import inquirer, json, subprocess, os, docker, gettext
from colorama import Fore, Style, init

settings_source = os.environ['SETTINGS_SOURCE']
gettext.bindtextdomain('ks', settings_source + '/i18n')
gettext.textdomain('ks')
_ = gettext.gettext


def install_applis():
    file_path = 'includes/config/services-available'
    translation =_('Sélection des Applications à installer')
    output_path = 'output.json'
    print(f"{Fore.CYAN}{_('Entrée ->')} {Style.RESET_ALL}{Fore.YELLOW}{_('Menu précédent')} && {Style.RESET_ALL}{Fore.CYAN}{_('Barre espace')} -> {Style.RESET_ALL}{Fore.YELLOW}{_('Sélection')}{Style.RESET_ALL}") 

    try:
        selected_lines = inquirer.prompt([
            inquirer.Checkbox('selected_lines', message=f'{Fore.GREEN}{translation}{Style.RESET_ALL}',
                              choices=[line.strip() for line in open(file_path, 'r') if os.path.exists(file_path)])
        ])['selected_lines']

        if selected_lines:
            with open(output_path, 'w') as output_file:
                json.dump({'selected_lines': selected_lines}, output_file, indent=2)

            subprocess.run(['includes/config/scripts/generique.sh', 'ajout_app_seedbox', *selected_lines])
        else:
            print(_('Aucune application sélectionnée'))
    except Exception as e:
        print(f'Une erreur s\'est produite : {e}')

def reinit_container():
    init(autoreset=True)
    client = docker.from_env()
    translation =_('Sélectionner l\'application à réinitialiser')
    quit = _('Quitter le script')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list()] + [(_('Quitter le script'))]
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f'{Fore.GREEN}{translation}{Style.RESET_ALL}',
                      choices=choices)
    ])['container']
    if selected_container != quit:
        print(f"{Fore.GREEN}{_('Application en cours de réinitialisation :')}{Style.RESET_ALL}", selected_container)
        subprocess.run(['includes/config/scripts/generique.sh', 'menu_reinit_container', selected_container])
    else:
        print(_('Vous avez choisi de quitter le script.'))

def suppression_application():
    init(autoreset=True)
    client = docker.from_env()
    translation=_('Sélectionner l\'application à supprimer')
    quit = _('Quitter le script')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list()] + [(_('Quitter le script'))]  
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}{translation}{Style.RESET_ALL}",
                      choices=choices)
    ])['container']
    if selected_container != quit:
        print(f"{Fore.GREEN}{_('Application en cours de suppression :')}{Style.RESET_ALL}", selected_container)
        subprocess.run(['includes/config/scripts/generique.sh', 'menu_suppression_application', selected_container])
    else:
        print(_('Vous avez choisi de quitter le script.'))

def relance_applis():
    init(autoreset=True)
    client = docker.from_env()
    translation=_('Sélectionner l\'application à relancer')
    quit = _('Quitter le script')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list()] + [(_('Quitter le script'))] 
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}{translation}{Style.RESET_ALL}",
                      choices=choices)
    ])['container']

    if selected_container != quit:
        print(f"{Fore.GREEN}{_('Application en cours de relance :')}{Style.RESET_ALL}", selected_container)
        subprocess.run(['includes/config/scripts/generique.sh', 'relance_container', selected_container])
    else:
        print(_('Vous avez choisi de quitter le script.'))

def sauvegarde_applis():
    init(autoreset=True)
    client = docker.from_env()
    translation=_('Sélectionner l\'application à sauvegarder')
    quit = _('Quitter le script')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list()] + [(_('Quitter le script'))] 
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}{translation}{Style.RESET_ALL}",
                      choices=choices)
    ])['container']
    if selected_container != quit:
        print(f"{Fore.GREEN}{_('Application en cours de sauvegarde :')}{Style.RESET_ALL}", selected_container)
        subprocess.run(['includes/config/scripts/generique.sh', 'choix_appli_sauvegarde', selected_container])
    else:
        print(_('Vous avez choisi de quitter le script.'))

def list_files_in_folder(folder_path):
    return [f.name for f in os.scandir(folder_path) if f.is_file()]

def install_applis_perso():
    init(autoreset=True)
    home_directory = os.path.expanduser("~")
    relative_folder_path = "seedbox/vars"
    folder_path = os.path.join(home_directory, relative_folder_path)
    files = list_files_in_folder(folder_path)
    translation =_('Sélectionner l\'application perso à installer')
    quit = _('Quitter le script')
    prompt_message = _('Voulez-vous revenir au menu principal ? (Oui/Non): ')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  

    # Ajouter 'Quitter' à la liste des fichiers
    choices = files + [(_('Quitter le script'))]

    if files:
        question = inquirer.List(
            'selected_file',
            message=f"{Fore.CYAN}{translation}{Style.RESET_ALL}",
            choices=choices,
        )

        selected_file = inquirer.prompt([question])['selected_file']

        # Vérifier si l'option 'Quitter le script' a été choisie
        if selected_file == quit:
            print(_("Vous avez choisi de quitter le script."))
            return

        selected_file_without_extension = os.path.splitext(selected_file)[0]
        print(f"{Fore.GREEN}{_('Vous avez sélectionné le fichier :')} {Style.RESET_ALL}{selected_file_without_extension}")
        subprocess.run(['includes/config/scripts/generique.sh', 'launch_service', selected_file_without_extension])
    else:
        print(f"{Fore.GREEN}{_('Le dossier est vide. Aucune Application personnalisée.')}{Style.RESET_ALL}")
        exit_script = input(prompt_message).lower()

        if exit_script == 'yes':
            print(_("Le script a été quitté."))
            return
        else:
            print(_("Continuer le script..."))
 
def create_applis_perso():
    translation =_('Type d\'applis à créer/copier')
    quit = _('Quitter le script')
    base = _('Applis déjà dans la base')
    nouvelle = _('Nouvelle Appli')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [(_('Applis déjà dans la base'))] + [(_('Nouvelle Appli'))] + [(_('Quitter le script'))]

    questions = [
        inquirer.List('selected_option',  # Ajout du nom de la question ('selected_option')
                      message=f"{Fore.GREEN}{translation}{Style.RESET_ALL}",
                      choices=choices)
    ]

    answers = inquirer.prompt(questions)

    selected_option = answers['selected_option']
    if selected_option == quit:
        return

    elif selected_option == base:
        os.system('clear')
        subprocess.run(['includes/config/scripts/generique.sh', 'logo'])
        copie_applis()
    else:
        subprocess.run(['includes/config/scripts/generique.sh', 'applis_perso_create', selected_option])

def copie_applis():
    file_path = 'includes/config/services-available'
    output_path = 'output.json'
    translation =_('Sélection des Applications à copier dans le dossier vars')

    print(f"{Fore.CYAN}{_('Entrée ->')} {Style.RESET_ALL}{Fore.YELLOW}{_('Menu précédent')} && {Style.RESET_ALL}{Fore.CYAN}{_('Barre espace')} -> {Style.RESET_ALL}{Fore.YELLOW}{_('Sélection')}{Style.RESET_ALL}")

    try:
        selected_lines = inquirer.prompt([
            inquirer.Checkbox('selected_lines', message=f'{Fore.GREEN}{translation}{Style.RESET_ALL}',
                              choices=[line.strip() for line in open(file_path, 'r') if os.path.exists(file_path)])
        ])['selected_lines']

        if selected_lines:
            with open(output_path, 'w') as output_file:
                json.dump({'selected_lines': selected_lines}, output_file, indent=2)
            subprocess.run(['includes/config/scripts/generique.sh', 'copie_applis', *selected_lines])

        else:
            print('Aucune application sélectionnée')
    except Exception as e:
        print(f'Une erreur s\'est produite : {e}')

