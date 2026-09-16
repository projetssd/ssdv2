import inquirer, json, subprocess, os, docker, gettext
from colorama import Fore, Style, init

settings_source = os.environ['SETTINGS_SOURCE']
generique_script = os.path.join(settings_source, 'includes/config/scripts/generique.sh')
services_available = os.path.join(settings_source, 'includes/config/services-available')
gettext.bindtextdomain('ks', settings_source + '/i18n')
gettext.textdomain('ks')
_ = gettext.gettext


def read_services_available():
    if not os.path.exists(services_available):
        return []
    with open(services_available, 'r') as services_file:
        return [line.strip() for line in services_file if line.strip()]


def run_bash_function(function_name, *args):
    subprocess.run([generique_script, function_name, *args])


def install_applis():
    translation = _('Sélection des Applications à installer')
    output_path = 'output.json'

    # Choix entre liste et recherche
    choice_prompt = inquirer.prompt([
        inquirer.List('choice',
                      message=f'{Fore.GREEN}Choisissez une option{Style.RESET_ALL}',
                      choices=['Afficher la liste des applications', 'Rechercher une application', 'Quitter']
                      )
    ])['choice']

    selected_lines = []

    if choice_prompt == 'Afficher la liste des applications':

        try:
            print(f"{Fore.CYAN}{_('Entrée ->')} {Style.RESET_ALL}{Fore.YELLOW}{_('Quitter')} && {Style.RESET_ALL}{Fore.CYAN}{_('Barre espace')} -> {Style.RESET_ALL}{Fore.YELLOW}{_('Sélection')}{Style.RESET_ALL}")
            choices = read_services_available()
            selected_lines = inquirer.prompt([
                inquirer.Checkbox('selected_lines', message=f'{Fore.GREEN}{translation}{Style.RESET_ALL}',
                                  choices=choices)
            ])['selected_lines']
        except Exception as e:
            print(f'Une erreur s\'est produite : {e}')
    elif choice_prompt == 'Rechercher une application':

        search_field = inquirer.Text('search', message=f'{Fore.GREEN}Nom Application{Style.RESET_ALL}')
        search_term = inquirer.prompt([search_field])['search']

        if search_term.strip():  # Vérifier si un terme de recherche a été saisi
            # Filter choices based on search term
            choices = read_services_available()
            filtered_choices = [choice for choice in choices if choice.lower().startswith(search_term.lower())]

            print(f"{Fore.CYAN}{_('Entrée ->')} {Style.RESET_ALL}{Fore.YELLOW}{_('Quitter')} && {Style.RESET_ALL}{Fore.CYAN}{_('Barre espace')} -> {Style.RESET_ALL}{Fore.YELLOW}{_('Sélection')}{Style.RESET_ALL}")
            selected_lines = inquirer.prompt([
                inquirer.Checkbox('selected_lines', message=f'{Fore.GREEN}{translation}{Style.RESET_ALL}',
                                  choices=filtered_choices)
            ])['selected_lines']
        else:
            print('Aucun terme de recherche saisi.')
    elif choice_prompt == 'Quitter':
        return

    if selected_lines:
        with open(output_path, 'w') as output_file:
            json.dump({'selected_lines': selected_lines}, output_file, indent=2)

        run_bash_function('ajout_app_seedbox', *selected_lines)
    else:
        print(_('Aucune application sélectionnée'))

def reinit_container():
    init(autoreset=True)
    client = docker.from_env()
    translation =_('Sélectionner l\'application à réinitialiser')
    quit = _('Quitter le script')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list(all=True)] + [(_('Quitter le script'))]
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f'{Fore.GREEN}{translation}{Style.RESET_ALL}',
                      choices=choices)
    ])['container']
    if selected_container != quit:
        print(f"{Fore.GREEN}{_('Application en cours de réinitialisation :')}{Style.RESET_ALL}", selected_container)
        run_bash_function('menu_reinit_container', selected_container)
    else:
        print(_('Vous avez choisi de quitter le script.'))

def suppression_application():
    init(autoreset=True)
    client = docker.from_env()
    translation=_('Sélectionner l\'application à supprimer')
    quit = _('Quitter le script')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list(all=True)] + [(_('Quitter le script'))]  
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}{translation}{Style.RESET_ALL}",
                      choices=choices)
    ])['container']
    if selected_container != quit:
        print(f"{Fore.GREEN}{_('Application en cours de suppression :')}{Style.RESET_ALL}", selected_container)
        run_bash_function('menu_suppression_application', selected_container)
    else:
        print(_('Vous avez choisi de quitter le script.'))

def relance_applis():
    init(autoreset=True)
    client = docker.from_env()
    translation=_('Sélectionner l\'application à relancer')
    quit = _('Quitter le script')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list(all=True)] + [(_('Quitter le script'))] 
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}{translation}{Style.RESET_ALL}",
                      choices=choices)
    ])['container']

    if selected_container != quit:
        print(f"{Fore.GREEN}{_('Application en cours de relance :')}{Style.RESET_ALL}", selected_container)
        run_bash_function('relance_container', selected_container)
    else:
        print(_('Vous avez choisi de quitter le script.'))

def sauvegarde_applis():
    init(autoreset=True)
    client = docker.from_env()
    translation=_('Sélectionner l\'application à sauvegarder')
    quit = _('Quitter le script')
    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list(all=True)] + [(_('Quitter le script'))] 
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}{translation}{Style.RESET_ALL}",
                      choices=choices)
    ])['container']
    if selected_container != quit:
        print(f"{Fore.GREEN}{_('Application en cours de sauvegarde :')}{Style.RESET_ALL}", selected_container)
        run_bash_function('choix_appli_sauvegarde', selected_container)
    else:
        print(_('Vous avez choisi de quitter le script.'))

def list_files_in_folder(folder_path):
    if not os.path.isdir(folder_path):
        return []
    return [f.name for f in os.scandir(folder_path) if f.is_file()]

def install_applis_perso():
    init(autoreset=True)
    settings_storage = os.environ.get('SETTINGS_STORAGE', os.path.expanduser("~/seedbox"))
    folder_path = os.path.join(settings_storage, "vars")
    files = list_files_in_folder(folder_path)
    translation =_('Sélectionner l\'application perso à installer')
    quit = _('Quitter le script')
    prompt_message = _('Voulez-vous revenir au menu principal ? (yes/no): ')
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
        run_bash_function('launch_service', selected_file_without_extension)
    else:
        print(f"{Fore.GREEN}{_('Le dossier est vide. Aucune Application personnalisée.')}{Style.RESET_ALL}")
        exit_script = input(prompt_message).lower()

        if exit_script == 'yes':
            print(_("Le script a été quitté."))
            return
        else:
            print(_("Continuer le script..."))

def copie_applis():
    try:
        output_path = 'output.json'
        translation = _('Application à copier dans le dossier vars')
        selected_lines = []

        question = inquirer.Text('search', message=f'{Fore.GREEN}Nom Application{Style.RESET_ALL}')
        search_term = inquirer.prompt([question])['search']

        if search_term.strip():
            choices = read_services_available()
            filtered_choices = [choice for choice in choices if choice.lower().startswith(search_term.lower())]

            print(f"{Fore.CYAN}{_('Entrée ->')} {Style.RESET_ALL}{Fore.YELLOW}{_('Quitter')} && {Style.RESET_ALL}{Fore.CYAN}{_('Barre espace')} -> {Style.RESET_ALL}{Fore.YELLOW}{_('Sélection')}{Style.RESET_ALL}")
            selected_lines = inquirer.prompt([
                inquirer.Checkbox('selected_lines', message=f'{Fore.GREEN}{translation}{Style.RESET_ALL}',
                                  choices=filtered_choices)
            ])['selected_lines']
        else:
            print('Aucun terme de recherche saisi.')

        if selected_lines:
            with open(output_path, 'w') as output_file:
                json.dump({'selected_lines': selected_lines}, output_file, indent=2)
            run_bash_function('copie_applis', *selected_lines)
        else:
            print('Aucune application sélectionnée')
    except Exception as e:
        print(f'Une erreur s\'est produite : {e}')

def create_applis_perso():
    translation = _('Type d\'applis à créer/copier')
    quit_option = _('Quitter le script')
    base_option = _('Applis déjà dans la base')
    new_option = _('Nouvelle Appli')

    print(f"{Fore.CYAN}{_('Sélectionner `Quitter le script` pour revenir au menu précédent')}{Style.RESET_ALL}")  
    choices = [base_option, new_option, quit_option]

    questions = [
        inquirer.List('selected_option',
                      message=f"{Fore.GREEN}{translation}{Style.RESET_ALL}",
                      choices=choices)
    ]

    answers = inquirer.prompt(questions)

    selected_option = answers['selected_option']
    if selected_option == quit_option:
        return

    elif selected_option == base_option:
        # os.system('clear')
        pass
        copie_applis()
    else:
        run_bash_function('applis_perso_create', selected_option)
