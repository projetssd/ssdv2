import inquirer, json, subprocess, os, docker
from colorama import Fore, Style, init

def install_applis():
    file_path = 'includes/config/services-available'
    output_path = 'output.json'

    try:
        selected_lines = inquirer.prompt([
            inquirer.Checkbox('selected_lines', message=f'{Fore.GREEN}Sélectionnez les Applications à installer{Style.RESET_ALL}',
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
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}Sélectionner l'application à réinitialiser{Style.RESET_ALL}",
                      choices=[container.name for container in client.containers.list()])
    ])['container']
    print(f"{Fore.GREEN}Application en cours de réinitialisation :{Style.RESET_ALL}", selected_container)
    subprocess.run(['includes/config/scripts/generique.sh', 'menu_reinit_container', selected_container])

def suppression_application():
    init(autoreset=True)
    client = docker.from_env()
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}Sélectionner l'application à supprimer{Style.RESET_ALL}",
                      choices=[container.name for container in client.containers.list()])
    ])['container']
    print(f"{Fore.GREEN}Application en cours de suppression :{Style.RESET_ALL}", selected_container)
    subprocess.run(['includes/config/scripts/generique.sh', 'menu_suppression_application', selected_container])

def relance_applis():
    init(autoreset=True)
    client = docker.from_env()
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}Sélectionner l'application à relancer{Style.RESET_ALL}",
                      choices=[container.name for container in client.containers.list()])
    ])['container']
    print(f"{Fore.GREEN}Application sélectionnée :{Style.RESET_ALL}", selected_container)
    subprocess.run(['includes/config/scripts/generique.sh', 'relance_container', selected_container])

def sauvegarde_applis():
    init(autoreset=True)
    client = docker.from_env()
    selected_container = inquirer.prompt([
        inquirer.List('container',
                      message=f"{Fore.GREEN}Sélectionner l'application à sauvegarder{Style.RESET_ALL}",
                      choices=[container.name for container in client.containers.list()])
    ])['container']
    print(f"{Fore.GREEN}Application en cours de sauvegarde :{Style.RESET_ALL}", selected_container)
    subprocess.run(['includes/config/scripts/generique.sh', 'choix_appli_sauvegarde', selected_container])

def list_files_in_folder(folder_path):
    return [f.name for f in os.scandir(folder_path) if f.is_file()]

def install_applis_perso():
    home_directory = os.path.expanduser("~")
    relative_folder_path = "seedbox/vars"
    folder_path = os.path.join(home_directory, relative_folder_path)
    files = list_files_in_folder(folder_path)

    if files:
        question = [
            inquirer.List(
                'selected_file',
                message=f"{Fore.GREEN}Sélectionnez une Appli perso à installer{Style.RESET_ALL}",
                choices=files,
            ),
        ]
        answer = inquirer.prompt(question)
        selected_file = answer['selected_file']
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