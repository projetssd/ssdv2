#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[install.sh] ERROR ligne ${LINENO}: ${BASH_COMMAND}" >&2' ERR

export PATH="$HOME/.local/bin:$PATH"
export IFSORIGIN="${IFS}"
export TERM=dumb
export NO_COLOR=1
export CLICOLOR=0
export FORCE_COLOR=0
export PY_COLORS=0
export ANSIBLE_FORCE_COLOR=false
export ANSIBLE_NOCOWS=1
export PYTHONUNBUFFERED=1
export DEBIAN_FRONTEND=noninteractive

CURRENT_USER="${SUDO_USER:-$(id -un)}"
CURRENT_HOME="$(getent passwd "$CURRENT_USER" | cut -d: -f6)"
if [ -z "${CURRENT_HOME}" ]; then
	CURRENT_HOME="$HOME"
fi

SETTINGS_SOURCE="${CURRENT_HOME}/seedbox-compose"
SETTINGS_STORAGE="${CURRENT_HOME}/seedbox"
ENV_FILE="${CURRENT_HOME}/.config/ssd/env"

STATE_DIR="${SETTINGS_SOURCE}/.agent-state"
SYSTEM_PREREQS_STAMP="${STATE_DIR}/system-prereqs.ok"
PYTHON_DEPS_STAMP="${STATE_DIR}/python-deps.ok"
ANSIBLE_DEPS_STAMP="${STATE_DIR}/ansible-deps.ok"

export SETTINGS_SOURCE
export SETTINGS_STORAGE

log() {
	echo "[install.sh] $*"
}

fail() {
	echo "[install.sh] ERROR: $*" >&2
	exit 1
}

run_root() {
	if [ "$(id -u)" -eq 0 ]; then
		"$@"
	else
		sudo -n "$@"
	fi
}

require_sudo() {
	if [ "$(id -u)" -ne 0 ]; then
		sudo -n true >/dev/null 2>&1 || fail "sudo sans mot de passe est requis pour l'agent"
	fi
}

ensure_runtime_context() {
	if [ ! -d "${SETTINGS_SOURCE}/venv" ]; then
		fail "virtualenv introuvable: ${SETTINGS_SOURCE}/venv"
	fi

	source "${SETTINGS_SOURCE}/venv/bin/activate"

	local temppath
	temppath="$(ls "${SETTINGS_SOURCE}/venv/lib")"
	export PYTHONPATH="${SETTINGS_SOURCE}/venv/lib/${temppath}/site-packages"
}

silent_source_profile() {
	if [ -f "${SETTINGS_SOURCE}/profile.sh" ]; then
		set +e
		source "${SETTINGS_SOURCE}/profile.sh" >/dev/null 2>&1
		local rc=$?
		set -e
		log "profile.sh rc=${rc}"
	else
		log "profile.sh introuvable"
	fi
}

is_seedbox_initialized() {
	if [ ! -f "${SETTINGS_SOURCE}/ssddb" ]; then
		return 1
	fi

	local installed_value
	installed_value="$(
		sqlite3 "${SETTINGS_SOURCE}/ssddb" "select value from seedbox_params where param='installed' limit 1;" 2>/dev/null || true
	)"

	[ "${installed_value}" = "1" ]
}

[ -d "${SETTINGS_SOURCE}" ] || fail "Répertoire introuvable: ${SETTINGS_SOURCE}"
cd "${SETTINGS_SOURCE}"

mkdir -p "${STATE_DIR}"

source "${SETTINGS_SOURCE}/includes/functions.sh"
source "${SETTINGS_SOURCE}/includes/variables.sh"

mkdir -p "${CURRENT_HOME}/.config/ssd" 2>/dev/null || true

if touch "${ENV_FILE}" 2>/dev/null; then
	cat >"${ENV_FILE}" <<EOF
SETTINGS_SOURCE=${CURRENT_HOME}/seedbox-compose
SETTINGS_STORAGE=${CURRENT_HOME}/seedbox
EOF
	source "${ENV_FILE}"
else
	log "Impossible d'écrire ${ENV_FILE}, on continue avec les variables d'environnement"
	export SETTINGS_SOURCE="${CURRENT_HOME}/seedbox-compose"
	export SETTINGS_STORAGE="${CURRENT_HOME}/seedbox"
fi

require_sudo
check_docker_group

if ! is_seedbox_initialized; then
	log "Initialisation complète SSDv2"

	run_root chown -R "${CURRENT_USER}:" "${SETTINGS_SOURCE}"

	if [ ! -f "${SYSTEM_PREREQS_STAMP}" ]; then
		log "Installation des prérequis système"
		run_root "${SETTINGS_SOURCE}/includes/config/scripts/prerequis_root.sh" "${CURRENT_USER}"
		touch "${SYSTEM_PREREQS_STAMP}"
	else
		log "Prérequis système déjà validés, étape ignorée"
	fi

	if [ ! -f "${CURRENT_HOME}/.vault_pass" ]; then
		log "Création de ~/.vault_pass"
		mypass="$(
			tr -dc 'A-Za-z0-9' </dev/urandom | head -c 25
			echo ''
		)"
		echo "${mypass}" >"${CURRENT_HOME}/.vault_pass"
		chmod 600 "${CURRENT_HOME}/.vault_pass"
	fi

	if [ ! -d "${SETTINGS_SOURCE}/venv" ]; then
		log "Création du virtualenv Python"
		python3 -m venv "${SETTINGS_SOURCE}/venv"
	else
		log "Virtualenv déjà présent, étape ignorée"
	fi

	ensure_runtime_context

	if [ ! -f "${PYTHON_DEPS_STAMP}" ]; then
		log "Installation des paquets Python"
		python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall pip
		pip install wheel
		pip install ansible docker shyaml netaddr dnspython configparser inquirer jsons colorama
		touch "${PYTHON_DEPS_STAMP}"
	else
		log "Paquets Python déjà validés, étape ignorée"
	fi

	log "Préparation d'Ansible"
	mkdir -p "${CURRENT_HOME}/.ansible/inventories"
	mkdir -p "${CURRENT_HOME}/.ansible/inventories/group_vars"

	cat >"${CURRENT_HOME}/.ansible/inventories/local" <<EOF
[local]
127.0.0.1 ansible_connection=local
EOF

	mkdir -p "${SETTINGS_SOURCE}/logs"
	chown -R "${CURRENT_USER}:" "${SETTINGS_SOURCE}/logs" 2>/dev/null || true
	chmod 755 "${SETTINGS_SOURCE}/logs" 2>/dev/null || true

	cat >"${CURRENT_HOME}/.ansible.cfg" <<EOF
[defaults]
command_warnings = False
deprecation_warnings = False
inventory = ${CURRENT_HOME}/.ansible/inventories/local
interpreter_python = ${SETTINGS_SOURCE}/venv/bin/python
vault_password_file = ${CURRENT_HOME}/.vault_pass
log_path = ${SETTINGS_SOURCE}/logs/ansible.log
stdout_callback = default
bin_ansible_callbacks = True
nocows = 1
EOF

	if [ ! -f "${SETTINGS_SOURCE}/ssddb" ]; then
		log "Création de la base SSD"
		sqlite3 "${SETTINGS_SOURCE}/ssddb" <<EOF
create table seedbox_params(param varchar(50) PRIMARY KEY, value varchar(50));
replace into seedbox_params (param,value) values ('installed',0);
create table applications(name varchar(50) PRIMARY KEY,
  status integer,
  subdomain varchar(50),
  port integer);
create table applications_params (appname varchar(50),
  param varchar(50),
  value varchar(50),
  FOREIGN KEY(appname) REFERENCES applications(name));
EOF
	else
		log "Base SSD déjà présente, étape ignorée"
	fi

	log "Préparation des répertoires"
	create_dir "${SETTINGS_STORAGE}"
	create_dir "${SETTINGS_STORAGE}/variables"
	create_dir "${SETTINGS_STORAGE}/conf"
	create_dir "${SETTINGS_STORAGE}/vars"

	if [ ! -f "${ANSIBLE_VARS}" ]; then
		log "Création initiale de all.yml"
		cp "${SETTINGS_SOURCE}/includes/config/account.yml" "${ANSIBLE_VARS}"
	else
		log "all.yml déjà présent, étape ignorée"
	fi

	if [ -d "${CURRENT_HOME}/.cache" ]; then
		run_root chown -R "${CURRENT_USER}:" "${CURRENT_HOME}/.cache" || true
	fi
	if [ -d "${CURRENT_HOME}/.local" ]; then
		run_root chown -R "${CURRENT_USER}:" "${CURRENT_HOME}/.local" || true
	fi
	if [ -d "${CURRENT_HOME}/.ansible" ]; then
		run_root chown -R "${CURRENT_USER}:" "${CURRENT_HOME}/.ansible" || true
	fi

	touch "${SETTINGS_SOURCE}/.prerequis.lock"

	ensure_runtime_context

	if [ ! -f "${ANSIBLE_DEPS_STAMP}" ]; then
		log "Installation des dépendances Ansible"
		ansible-galaxy collection install community.general
		ansible-galaxy install kwoodson.yedit
		ansible-galaxy role install geerlingguy.docker
		touch "${ANSIBLE_DEPS_STAMP}"
	else
		log "Dépendances Ansible déjà validées, étape ignorée"
	fi

	log "Enregistrement des chemins dans all.yml"
	manage_account_yml settings.storage "${SETTINGS_STORAGE}"
	manage_account_yml settings.source "${SETTINGS_SOURCE}"

	log "Vérifications de permissions"
	make_dir_writable "${SETTINGS_SOURCE}"
	change_file_owner "${SETTINGS_SOURCE}/ssddb"

	log "Préparation de l'environnement SSD"
	conf_dir

	log "Avant stocke_public_ip"
	stocke_public_ip
	log "Après stocke_public_ip"

	log "Avant install_environnement"
	echo "[install_environnement] démarrage"
	echo "[install_environnement] chargement silencieux de profile.sh"
	silent_source_profile

	echo "[install_environnement] lancement ansible-playbook"
	set +e
	ansible-playbook "${SETTINGS_SOURCE}/includes/config/roles/user_environment/tasks/main.yml"
	playbook_rc=$?
	set -e
	echo "[install_environnement] ansible-playbook rc=${playbook_rc}"

	if [ "${playbook_rc}" -ne 0 ]; then
		echo "[install_environnement] échec ansible-playbook"
		exit "${playbook_rc}"
	fi

	echo "Pour bénéficier des changements, vous devez vous déconnecter/reconnecter"
	log "Après install_environnement"

	log "Avant update_seedbox_param installed=1"
	update_seedbox_param "installed" 1
	log "Après update_seedbox_param installed=1"

	log "Les composants sont maintenant tous installés/réglés, poursuite de l'installation"
	log "Initialisation SSDv2 terminée"
else
	log "SSDv2 déjà initialisé, prérequis lourds ignorés"
fi

log "Chargement de l'environnement Python"
ensure_runtime_context

emplacement_stockage="$(get_from_account_yml settings.storage || true)"
if [ -z "${emplacement_stockage}" ] || [ "${emplacement_stockage}" = "notfound" ]; then
	log "settings.storage absent de all.yml, correction"
	manage_account_yml settings.storage "${SETTINGS_STORAGE}"
fi

log "Rechargement silencieux de profile.sh"
silent_source_profile

# install traefik
manage_account_yml sub.traefik.traefik traefik
manage_account_yml sub.traefik.auth basique
ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/vars/traefik.yml

log "Installation SSDv2 terminée avec succès."
exit 0