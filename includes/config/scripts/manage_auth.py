#!/usr/bin/env python3
import os
import sys
import subprocess
import re
import time
import termios
import tty
from typing import Dict, List

# --- Configuration ---
USER_HOME = os.path.expanduser("~")
FUNCTIONS_SCRIPT = os.path.join(USER_HOME, "seedbox-compose/includes/functions.sh")

ENV_VARS = os.environ.copy()
if "SETTINGS_SOURCE" not in ENV_VARS:
    ENV_VARS["SETTINGS_SOURCE"] = os.path.join(USER_HOME, "seedbox-compose")
if "SETTINGS_STORAGE" not in ENV_VARS:
    ENV_VARS["SETTINGS_STORAGE"] = "/opt/seedbox"

class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[0;33m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'

AUTH_TYPES = {
    '1': 'basique',
    '2': 'oauth',
    '3': 'authelia',
    '4': 'aucune',
    '5': 'oauth2-proxy'
}

AUTH_MENU_ORDER = ['1', '2', '3', '4', '5']  # ordre d'affichage

# ---------- Lecture clavier bas niveau (flèches, espace, etc.) ----------

def read_key() -> str:
    """
    Lit une touche en mode brut et renvoie une chaîne :
    - 'UP', 'DOWN'
    - 'SPACE'
    - 'ENTER'
    - 'q', 'a', 'c', 's', 'm' ...
    """
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch1 = sys.stdin.read(1)
        if ch1 == '\x1b':  # séquence d'échappement
            ch2 = sys.stdin.read(1)
            if ch2 == '[':
                ch3 = sys.stdin.read(1)
                if ch3 == 'A':
                    return 'UP'
                if ch3 == 'B':
                    return 'DOWN'
            return ''
        elif ch1 == ' ':
            return 'SPACE'
        elif ch1 in ('\r', '\n'):
            return 'ENTER'
        else:
            return ch1
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

# ---------- Pont Bash ----------

def call_bash_function(func_name: str, *args) -> str:
    args_str = " ".join(f"'{arg}'" for arg in args)
    bash_script = f"""
    export SETTINGS_SOURCE="{ENV_VARS['SETTINGS_SOURCE']}"
    export SETTINGS_STORAGE="{ENV_VARS['SETTINGS_STORAGE']}"
    [ -f "{FUNCTIONS_SCRIPT}" ] && source "{FUNCTIONS_SCRIPT}"
    {func_name} {args_str}
    """
    try:
        result = subprocess.run(
            bash_script,
            shell=True,
            executable='/bin/bash',
            capture_output=True,
            text=True,
            env=ENV_VARS
        )
        return result.stdout.strip()
    except Exception as e:
        print(f"{Colors.RED}Erreur lors de l'appel bash {func_name}: {e}{Colors.NC}")
        return ""

def call_bash_function_live(func_name: str, *args) -> bool:
    args_str = " ".join(f"'{arg}'" for arg in args)
    bash_script = f"""
    export SETTINGS_SOURCE="{ENV_VARS['SETTINGS_SOURCE']}"
    export SETTINGS_STORAGE="{ENV_VARS['SETTINGS_STORAGE']}"
    [ -f "{FUNCTIONS_SCRIPT}" ] && source "{FUNCTIONS_SCRIPT}"
    {func_name} {args_str}
    """
    try:
        proc = subprocess.run(
            bash_script,
            shell=True,
            executable='/bin/bash',
            env=ENV_VARS
        )
        return proc.returncode == 0
    except Exception:
        return False

def get_from_account_yml(key: str) -> str:
    val = call_bash_function("get_from_account_yml", key)
    if not val:
        return "notfound"
    lines = [line for line in val.split('\n') if line.strip()]
    return lines[-1] if lines else "notfound"

def manage_account_yml(key: str, value: str) -> bool:
    output = call_bash_function("manage_account_yml", key, value)
    if "impossible de continuer" in output or "ERROR" in output:
        return False
    return True

def launch_service(app_name: str) -> bool:
    return call_bash_function_live("launch_service", app_name)

# ---------- Gestion Auth Apps ----------

class AuthManager:
    def __init__(self):
        self.apps: List[str] = []
        self.app_data: Dict[str, dict] = {}
        self.cursor_index: int = 0  # position du curseur dans la liste

    def check_environment(self) -> bool:
        if not os.path.exists(FUNCTIONS_SCRIPT):
            print(f"{Colors.RED}❌ Fichier de fonctions introuvable : {FUNCTIONS_SCRIPT}{Colors.NC}")
            return False
        return True

    def load_docker_apps(self) -> bool:
        try:
            cmd = 'docker ps --format "{{.Names}}" --filter "network=traefik_proxy"'
            output = subprocess.check_output(cmd, shell=True).decode('utf-8').strip()
        except subprocess.CalledProcessError:
            return False

        if not output:
            return False

        self.apps = sorted(output.split('\n'))
        print(f"{Colors.BLUE}Chargement des configurations...{Colors.NC}")
        for app in self.apps:
            current = get_from_account_yml(f"sub.{app}.auth")
            if current == "notfound" or current == "":
                current = "---"
            self.app_data[app] = {
                'current': current,
                'new': None,
                'selected': False
            }
        if self.apps:
            self.cursor_index = 0
        return True

    def get_selected_count(self) -> int:
        return sum(1 for app in self.apps if self.app_data[app]['selected'])

    def print_menu(self):
        os.system('cls' if os.name == 'nt' else 'clear')
        print(f"{Colors.BLUE}#################################{Colors.NC}")
        print(f"{Colors.BLUE}GESTION DE L'AUTHENTIFICATION DES APPS{Colors.NC}")
        print(f"{Colors.BLUE}#################################{Colors.NC}\n")

        print(f"{Colors.WHITE}Applications ({len(self.apps)}):{Colors.NC}\n")

        for idx, app in enumerate(self.apps):
            data = self.app_data[app]
            checkbox = "[✓]" if data['selected'] else "[ ]"
            auth_display = data['current']
            if data['new']:
                auth_display = f"{Colors.CYAN}{data['new']} (modifié){Colors.NC}"

            # Curseur visuel
            if idx == self.cursor_index:
                prefix = "➤"  # curseur
                line_color_start = Colors.WHITE
                line_color_end = Colors.NC
            else:
                prefix = " "
                line_color_start = ""
                line_color_end = ""

            print(f"{line_color_start}{prefix} {checkbox} {idx+1:2d}) {app:<20} {auth_display}{line_color_end}")

        print(f"\n{Colors.YELLOW}Auth types: 1=basique 2=oauth 3=authelia 4=aucune 5=oauth2-proxy{Colors.NC}\n")
        print(f"{Colors.WHITE}Commandes:{Colors.NC}")
        print(" ↑ / ↓  = naviguer dans la liste")
        print(" SPACE  = cocher/décocher l'app sur la ligne courante")
        print(" a      = sélectionner TOUT")
        print(" c      = désélectionner tout")
        print(" m      = modifier l'auth pour les apps sélectionnées")
        print(" s      = APPLIQUER (écriture YAML + relance optionnelle)")
        print(" q      = quitter\n")

        count = self.get_selected_count()
        if count > 0:
            print(f"{Colors.GREEN}{count} sélectionnée(s){Colors.NC}")

        print("\nAppuyez sur une touche (flèches, espace, a/c/m/s/q)...")

    def show_auth_choice_menu(self) -> str:
        """
        Affiche le menu vertical des auths possibles.
        Retourne la clé choisie ('1'..'5') ou '' si annulation.
        """
        while True:
            os.system('cls' if os.name == 'nt' else 'clear')
            print(f"{Colors.BLUE}MODIFIER AUTHENTIFICATION{Colors.NC}\n")
            print(f"{Colors.WHITE}Appliquer à toutes les applications sélectionnées :{Colors.NC}")
            print("Choisissez un type d'authentification :\n")

            for k in AUTH_MENU_ORDER:
                print(f" {k}) {AUTH_TYPES[k]}")
            print(" 0) Annuler\n")

            choice = input("Numéro : ").strip()
            if choice == '0' or choice == '':
                return ""
            if choice in AUTH_TYPES:
                confirm = input(f"Confirmer changement pour TOUTES les apps sélectionnées en '{AUTH_TYPES[choice]}' ? (y/n) : ").lower()
                if confirm == 'y':
                    return choice

    def apply_bulk_auth_change(self):
        """
        Mode 'modifier' : changer le type d'auth pour toutes les apps sélectionnées (en mémoire).
        """
        if self.get_selected_count() == 0:
            print(f"{Colors.YELLOW}Aucune application sélectionnée.{Colors.NC}")
            time.sleep(1.5)
            return

        choice_key = self.show_auth_choice_menu()
        if not choice_key:
            return

        new_auth = AUTH_TYPES[choice_key]
        for app in self.apps:
            if self.app_data[app]['selected']:
                self.app_data[app]['new'] = new_auth

    def apply_changes(self):
        apps_to_change = [app for app in self.apps if self.app_data[app]['new']]

        if not apps_to_change:
            print(f"\n{Colors.YELLOW}Aucune modification en attente.{Colors.NC}")
            input(f"{Colors.WHITE}ENTER pour continuer{Colors.NC}")
            return

        os.system('cls' if os.name == 'nt' else 'clear')
        print(f"{Colors.BLUE}APPLIQUER LES MODIFICATIONS{Colors.NC}\n")

        for app in apps_to_change:
            old = self.app_data[app]['current']
            new = self.app_data[app]['new']
            print(f"{Colors.WHITE}{app}{Colors.NC}: {old} → {Colors.CYAN}{new}{Colors.NC}")

        confirm = input("\nConfirmer écriture dans le YAML (Ansible Vault) ? (y/n): ").lower()
        if confirm != 'y':
            return

        print(f"\n{Colors.BLUE}Enregistrement dans le YAML...{Colors.NC}")
        successful_changes = []

        for app in apps_to_change:
            print(f"Traitement de {app}...", end="\r")
            if manage_account_yml(f"sub.{app}.auth", self.app_data[app]['new']):
                print(f"{Colors.GREEN}✓ {app} sauvegardé       {Colors.NC}")
                successful_changes.append(app)
            else:
                print(f"{Colors.RED}❌ {app} erreur           {Colors.NC}")

        if not successful_changes:
            input("ENTER pour continuer")
            return

        print("")
        restart = input("Relancer les apps modifiées (launch_service) ? (y/n): ").lower()
        if restart == 'y':
            print("")
            for app in successful_changes:
                choice = input(f"Recréer {app}? (y/n): ").lower()
                if choice == 'y':
                    print(f"{Colors.WHITE}Lancement du playbook pour {app}...{Colors.NC}")
                    if launch_service(app):
                        print(f"{Colors.GREEN}✓ Service {app} OK{Colors.NC}")
                    else:
                        print(f"{Colors.RED}❌ Service {app} FAIL{Colors.NC}")
            print(f"{Colors.GREEN}✓ Terminé{Colors.NC}")

        input(f"\n{Colors.WHITE}ENTER pour continuer{Colors.NC}")

        for app in successful_changes:
            self.app_data[app]['current'] = self.app_data[app]['new']
            self.app_data[app]['new'] = None
            self.app_data[app]['selected'] = False

    def run(self):
        if not self.check_environment():
            return

        if not self.load_docker_apps():
            print(f"{Colors.RED}❌ Aucune application Docker trouvée (network=traefik_proxy){Colors.NC}")
            input("Appuyer sur ENTER pour quitter")
            return

        while True:
            self.print_menu()
            key = read_key()

            if key == 'UP':
                if self.apps:
                    self.cursor_index = (self.cursor_index - 1) % len(self.apps)

            elif key == 'DOWN':
                if self.apps:
                    self.cursor_index = (self.cursor_index + 1) % len(self.apps)

            elif key == 'SPACE':
                if self.apps:
                    app_name = self.apps[self.cursor_index]
                    self.app_data[app_name]['selected'] = not self.app_data[app_name]['selected']

            elif key in ('a', 'A'):
                for app in self.apps:
                    self.app_data[app]['selected'] = True

            elif key in ('c', 'C'):
                for app in self.apps:
                    self.app_data[app]['selected'] = False

            elif key in ('m', 'M'):
                self.apply_bulk_auth_change()

            elif key in ('s', 'S'):
                self.apply_changes()

            elif key in ('q', 'Q'):
                break

if __name__ == "__main__":
    try:
        manager = AuthManager()
        manager.run()
    except KeyboardInterrupt:
        print("\nArrêt demandé.")
        sys.exit(0)
