#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[autoinstall.sh] ERROR ligne ${LINENO}: ${BASH_COMMAND}" >&2' ERR

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
DOCKER_RUNTIME_STAMP="${STATE_DIR}/docker-runtime.ok"

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

write_env_file() {
	mkdir -p "${CURRENT_HOME}/.config/ssd" 2>/dev/null || true

	if touch "${ENV_FILE}" 2>/dev/null; then
		cat >"${ENV_FILE}" <<EOF
SETTINGS_SOURCE=${CURRENT_HOME}/seedbox-compose
SETTINGS_STORAGE=${CURRENT_HOME}/seedbox
EOF
		# shellcheck disable=SC1090
		source "${ENV_FILE}"
	else
		log "Impossible d'écrire ${ENV_FILE}, on continue avec les variables d'environnement"
		export SETTINGS_SOURCE="${CURRENT_HOME}/seedbox-compose"
		export SETTINGS_STORAGE="${CURRENT_HOME}/seedbox"
	fi
}

ensure_runtime_context() {
	if [ ! -d "${SETTINGS_SOURCE}/venv" ]; then
		fail "virtualenv introuvable: ${SETTINGS_SOURCE}/venv"
	fi

	# shellcheck disable=SC1091
	source "${SETTINGS_SOURCE}/venv/bin/activate"

	local python_lib_dir
	python_lib_dir="$(
		find "${SETTINGS_SOURCE}/venv/lib" -mindepth 1 -maxdepth 1 -type d -name 'python*' 2>/dev/null | head -n 1
	)"

	if [ -n "${python_lib_dir}" ] && [ -d "${python_lib_dir}/site-packages" ]; then
		export PYTHONPATH="${python_lib_dir}/site-packages${PYTHONPATH:+:${PYTHONPATH}}"
	fi
}

silent_source_profile() {
	if [ -f "${SETTINGS_SOURCE}/profile.sh" ]; then
		set +e
		# shellcheck disable=SC1091
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

	if ! command -v sqlite3 >/dev/null 2>&1; then
		return 1
	fi

	local installed_value
	installed_value="$(
		sqlite3 "${SETTINGS_SOURCE}/ssddb" "select value from seedbox_params where param='installed' limit 1;" 2>/dev/null || true
	)"

	[ "${installed_value}" = "1" ]
}

ensure_system_prereqs() {
	run_root chown -R "${CURRENT_USER}:" "${SETTINGS_SOURCE}"

	if [ ! -f "${SYSTEM_PREREQS_STAMP}" ]; then
		log "Installation des prérequis système"
		run_root "${SETTINGS_SOURCE}/includes/config/scripts/prerequis_root.sh" "${CURRENT_USER}"
		touch "${SYSTEM_PREREQS_STAMP}"
	else
		log "Prérequis système déjà validés, étape ignorée"
	fi
}

ensure_python_runtime() {
	if [ ! -f "${CURRENT_HOME}/.vault_pass" ]; then
		log "Création de ~/.vault_pass"
		local mypass
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

	ensure_runtime_context
}

prepare_ansible_layout() {
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
}

ensure_ssd_database() {
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
}

prepare_storage_layout() {
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
}

fix_home_permissions() {
	if [ -d "${CURRENT_HOME}/.cache" ]; then
		run_root chown -R "${CURRENT_USER}:" "${CURRENT_HOME}/.cache" || true
	fi
	if [ -d "${CURRENT_HOME}/.local" ]; then
		run_root chown -R "${CURRENT_USER}:" "${CURRENT_HOME}/.local" || true
	fi
	if [ -d "${CURRENT_HOME}/.ansible" ]; then
		run_root chown -R "${CURRENT_USER}:" "${CURRENT_HOME}/.ansible" || true
	fi
}

ensure_ansible_deps() {
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
}

ensure_all_yml_is_vaulted() {
	if [ ! -f "${ANSIBLE_VARS}" ]; then
		fail "Fichier all.yml introuvable: ${ANSIBLE_VARS}"
	fi

	if grep -q '^\$ANSIBLE_VAULT;' "${ANSIBLE_VARS}" 2>/dev/null; then
		log "all.yml déjà chiffré avec ansible-vault"
		return 0
	fi

	local vault_cfg
	vault_cfg="${STATE_DIR}/ansible-vault-bootstrap.cfg"

	cat >"${vault_cfg}" <<EOF
[defaults]
vault_identity_list = default@${CURRENT_HOME}/.vault_pass
EOF

	log "Chiffrement initial de all.yml avec ansible-vault"
	if ! ANSIBLE_CONFIG="${vault_cfg}" ansible-vault encrypt --encrypt-vault-id default "${ANSIBLE_VARS}"; then
		rm -f "${vault_cfg}"
		return 1
	fi

	rm -f "${vault_cfg}"
}

apply_agent_payload() {
	log "Application des paramètres transmis par l'agent dans all.yml"

	manage_account_yml settings.source "${SETTINGS_SOURCE}"
	manage_account_yml settings.storage "${SETTINGS_STORAGE}"

	if [ -n "${SSD_USERNAME:-}" ]; then
		manage_account_yml user.name "${SSD_USERNAME}"
	fi

	if [ -n "${SSD_EMAIL:-}" ]; then
		manage_account_yml user.mail "${SSD_EMAIL}"
	fi

	if [ -n "${SSD_DOMAIN:-}" ]; then
		manage_account_yml user.domain "${SSD_DOMAIN}"
	fi

	if [ -n "${SSD_PASSWORD:-}" ]; then
		manage_account_yml user.pass "${SSD_PASSWORD}"
	fi

	if [ -n "${SSD_CLOUDFLARE_LOGIN:-}" ]; then
		manage_account_yml cloudflare.login "${SSD_CLOUDFLARE_LOGIN}"
	fi

	if [ -n "${SSD_CLOUDFLARE_API_KEY:-}" ]; then
		manage_account_yml cloudflare.api "${SSD_CLOUDFLARE_API_KEY}"
	fi

	if [ -n "${SSD_OAUTH_CLIENT:-}" ]; then
		manage_account_yml oauth.client "${SSD_OAUTH_CLIENT}"
	fi

	if [ -n "${SSD_OAUTH_SECRET:-}" ]; then
		manage_account_yml oauth.secret "${SSD_OAUTH_SECRET}"
	fi

	if [ -n "${SSD_OAUTH_MAIL:-}" ]; then
		manage_account_yml oauth.account "${SSD_OAUTH_MAIL}"
	fi
}

prepare_traefik_vars() {
	log "Préparation des variables Traefik"

	ensure_runtime_context

	log "Traefik: sub.traefik.traefik=traefik"
	manage_account_yml sub.traefik.traefik traefik

	log "Traefik: sub.traefik.auth=basique"
	manage_account_yml sub.traefik.auth basique
}

ensure_docker_runtime() {
	if ! command -v docker >/dev/null 2>&1; then
		log "Installation de Docker"
		ensure_runtime_context
		ansible-playbook "${SETTINGS_SOURCE}/includes/config/roles/docker/tasks/main.yml"
	else
		log "Docker déjà installé"
	fi

	if ! command -v docker >/dev/null 2>&1; then
		fail "Docker n'est toujours pas installé après le playbook docker"
	fi

	if command -v systemctl >/dev/null 2>&1; then
		if ! run_root systemctl is-enabled docker >/dev/null 2>&1; then
			log "Activation du service docker"
			run_root systemctl enable docker >/dev/null 2>&1 || true
		fi

		if ! run_root systemctl is-active docker >/dev/null 2>&1; then
			log "Démarrage du service docker"
			run_root systemctl start docker
		fi
	fi

	touch "${DOCKER_RUNTIME_STAMP}"
}

initialize_ssdv2() {
	log "Initialisation complète SSDv2"

	touch "${SETTINGS_SOURCE}/.prerequis.lock"

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
}

traefik() {
	log "Installation Traefik"
	ensure_runtime_context
	ansible-playbook "${SETTINGS_SOURCE}/includes/dockerapps/vars/traefik.yml"
}

[ -d "${SETTINGS_SOURCE}" ] || fail "Répertoire introuvable: ${SETTINGS_SOURCE}"
cd "${SETTINGS_SOURCE}"

mkdir -p "${STATE_DIR}"

write_env_file

# shellcheck disable=SC1091
source "${SETTINGS_SOURCE}/includes/functions.sh"
# shellcheck disable=SC1091
source "${SETTINGS_SOURCE}/includes/variables.sh"

require_sudo
ensure_system_prereqs
ensure_python_runtime
prepare_ansible_layout
ensure_ssd_database
prepare_storage_layout
fix_home_permissions
ensure_ansible_deps
ensure_all_yml_is_vaulted
apply_agent_payload

if ! is_seedbox_initialized; then
	initialize_ssdv2
else
	log "SSDv2 déjà initialisé, prérequis lourds ignorés"
fi

ensure_docker_runtime
prepare_traefik_vars
traefik

log "Installation SSDv2 terminée avec succès."
exit 0