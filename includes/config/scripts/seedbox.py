import inquirer, json, subprocess, os, docker
from colorama import Fore, Style, init

def install_applis():
    file_path = 'includes/config/services-available'
    output_path = 'output.json'
    print(f"{Fore.CYAN}Entrée -> {Style.RESET_ALL}{Fore.YELLOW}Menu précédent && {Style.RESET_ALL}{Fore.CYAN}Barre espace -> {Style.RESET_ALL}{Fore.YELLOW}Sélection{Style.RESET_ALL}")  

    try:
        selected_lines = inquirer.prompt([
            inquirer.Checkbox('selected_lines', message=f'{Fore.GREEN}Sélection des Applications à installer{Style.RESET_ALL}',
                              choices=[line.strip() for line in open(file_path, 'r') if os.path.exists(file_path)])
        ])['selected_lines']

        if selected_lines:
            with open(output_path, 'w') as output_file:
                json.dump({'selected_lines': selected_lines}, output_file, indent=2)

            subprocess.run(['includes/config/scripts/generique.sh', 'ajout_app_seedbox', *selected_lines])
        else:
            print('Aucune application sélectionnée')
    except Exception as e:
        print(f'Une erreur s\'est produite : {e}')

def reinit_container():
    init(autoreset=True)
    client = docker.from_env()
    print(f"{Fore.CYAN}Sélectionner 'Quitter le script' pour revenir au menu précédent{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list()] + ['Quitter le script'] 
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}Sélectionner l'application à réinitialiser{Style.RESET_ALL}",
                      choices=choices)
    ])['container']
    if selected_container != 'Quitter le script':
        print(f"{Fore.GREEN}Application en cours de réinitialisation :{Style.RESET_ALL}", selected_container)
        subprocess.run(['includes/config/scripts/generique.sh', 'menu_reinit_container', selected_container])
    else:
        print("Vous avez choisi de quitter le script.")

def suppression_application():
    init(autoreset=True)
    client = docker.from_env()
    print(f"{Fore.CYAN}Sélectionner 'Quitter le script' pour revenir au menu précédent{Style.RESET_ALL}")  
    choices = [container.name for container in client.containers.list()] + ['Quitter le script']  
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}Sélectionner l'application à supprimer{Style.RESET_ALL}",
                      choices=choices)
    ])['container']
    if selected_container != 'Quitter le script':
        print(f"{Fore.GREEN}Application en cours de suppression :{Style.RESET_ALL}", selected_container)
        subprocess.run(['includes/config/scripts/generique.sh', 'menu_suppression_application', selected_container])
    else:
        print("Vous avez choisi de quitter le script.")

def relance_applis():
    init(autoreset=True)
    client = docker.from_env()
    print(f"{Fore.CYAN}Sélectionner 'Quitter le script' pour revenir au menu précédent{Style.RESET_ALL}")    
    choices = [container.name for container in client.containers.list()] + ['Quitter le script']

    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}Sélectionner l'application à relancer{Style.RESET_ALL}",
                      choices=choices)
    ])['container']

    if selected_container != 'Quitter le script':
        print(f"{Fore.GREEN}Application sélectionnée :{Style.RESET_ALL}", selected_container)
        subprocess.run(['includes/config/scripts/generique.sh', 'relance_container', selected_container])
    else:
        print("Vous avez choisi de quitter le script.")

def sauvegarde_applis():
    init(autoreset=True)
    client = docker.from_env()
    print(f"{Fore.CYAN}Sélectionner 'Quitter le script' pour revenir au menu précédent{Style.RESET_ALL}")    
    choices = [container.name for container in client.containers.list()] + ['Quitter le script']
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}Sélectionner l'application à sauvegarder{Style.RESET_ALL}",
                      choices=choices)
    ])['container']
    if selected_container != 'Quitter le script':
        print(f"{Fore.GREEN}Application en cours de sauvegarde :{Style.RESET_ALL}", selected_container)
        subprocess.run(['includes/config/scripts/generique.sh', 'choix_appli_sauvegarde', selected_container])
    else:
        print("Vous avez choisi de quitter le script.")

def list_files_in_folder(folder_path):
    return [f.name for f in os.scandir(folder_path) if f.is_file()]

def install_applis_perso():
    init(autoreset=True)

    home_directory = os.path.expanduser("~")
    relative_folder_path = "seedbox/vars"
    folder_path = os.path.join(home_directory, relative_folder_path)
    files = list_files_in_folder(folder_path)
    print(f"{Fore.GREEN}Sélectionner 'Quitter le script' pour revenir au menu précédent{Style.RESET_ALL}")    

    # Ajouter 'Quitter' à la liste des fichiers
    choices = files + ['Quitter le script']

    if files:
        question = inquirer.List(
            'selected_file',
            message=f"{Fore.CYAN}Sélectionnez une Appli perso à installer{Style.RESET_ALL}",
            choices=choices,
        )

        selected_file = inquirer.prompt([question])['selected_file']

        # Vérifier si l'option 'Quitter le script' a été choisie
        if selected_file == 'Quitter le script':
            print("Vous avez choisi de quitter le script.")
            return

        selected_file_without_extension = os.path.splitext(selected_file)[0]
        print(f"{Fore.GREEN}Vous avez sélectionné le fichier : {Style.RESET_ALL}{selected_file_without_extension}")
        subprocess.run(['includes/config/scripts/generique.sh', 'launch_service', selected_file_without_extension])
    else:
        print(f"{Fore.GREEN}Le dossier est vide. Aucune Application personnalisée.{Style.RESET_ALL}")
        exit_script = input("Voulez-vous revenir au menu principal ? (Oui/Non): ").lower()

        if exit_script == 'oui':
            print("Le script a été quitté.")
            return
        else:
            print("Continuer le script...")

def create_applis_perso():    
    print(f"{Fore.CYAN}Sélectionner 'Quitter le script' pour revenir au menu précédent{Style.RESET_ALL}")
    choices = ['Applis déjà dans la base', 'Nouvelle Appli', 'Quitter le script']

    questions = [
        inquirer.List('selected_option',  # Ajout du nom de la question ('selected_option')
                      message=f"{Fore.GREEN}Type d'applis à créer/copier{Style.RESET_ALL}",
                      choices=choices)
    ]

    answers = inquirer.prompt(questions)

    selected_option = answers['selected_option']
    if selected_option == 'Quitter le script':
        return

    elif selected_option == 'Applis déjà dans la base':
        os.system('clear')
        subprocess.run(['includes/config/scripts/generique.sh', 'logo'])
        copie_applis()
    else:
        subprocess.run(['includes/config/scripts/generique.sh', 'applis_perso_create', selected_option])

def copie_applis():
    file_path = 'includes/config/services-available'
    output_path = 'output.json'
    print(f"{Fore.CYAN}Entrée -> {Style.RESET_ALL}{Fore.YELLOW}Menu précédent && {Style.RESET_ALL}{Fore.CYAN}Barre espace -> {Style.RESET_ALL}{Fore.YELLOW}Sélection{Style.RESET_ALL}")  

    try:
        selected_lines = inquirer.prompt([
            inquirer.Checkbox('selected_lines', message=f'{Fore.GREEN}Sélection des Applications à copier dans le dossier vars{Style.RESET_ALL}',
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

