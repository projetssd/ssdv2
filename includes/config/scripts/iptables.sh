#!/bin/bash

if [[ ! -d "${SETTINGS_STORAGE}/docker/geerlingguy.security" ]]; then

	echo "roles_path = ${SETTINGS_STORAGE}/docker" >> "/etc/ansible/ansible.cfg"
	#configuration ssh
	mkdir -p ${SETTINGS_STORAGE}/docker/geerlingguy.security/defaults
	echo -e "${BLUE}### SSH GEERLINGGUY ###${NC}"
	echo ""
	ansible-galaxy install geerlingguy.security
	cp "${SETTINGS_SOURCE}/includes/dockerapps/templates/ssh/main.yml" "${SETTINGS_STORAGE}/docker/geerlingguy.security" > /dev/null 2>&1
	sed -i '/UseDNS/d' ${SETTINGS_STORAGE}/docker/geerlingguy.security/tasks/ssh.yml
	echo ""
	echo -e "\n${CCYAN} /!\ Par mesure de sécurité il est fortement consseillé de changer le port ssh /!\ ${CEND}"
	echo ""
	cp "${SETTINGS_SOURCE}/includes/dockerapps/templates/ssh/defaults/main.yml.j2" "${SETTINGS_STORAGE}/docker/geerlingguy.security/defaults/main.yml"
	ansible-playbook ${SETTINGS_STORAGE}/docker/geerlingguy.security/main.yml
	echo ""
	checking_errors $?
	echo ""

else

	echo -e "${BLUE}### SSH GEERLINGGUY ###${NC}"
	echo ""
	echo -e "\n${CCYAN} /!\ Par mesure de sécurité il est fortement conseillé de changer le port ssh /!\ ${CEND}"
	echo ""
	mkdir -p ${SETTINGS_STORAGE}/docker/geerlingguy.security/defaults
	cp "${SETTINGS_SOURCE}/includes/dockerapps/templates/ssh/defaults/main.yml.j2" "${SETTINGS_STORAGE}/docker/geerlingguy.security/defaults/main.yml"
	ansible-playbook ${SETTINGS_STORAGE}/docker/geerlingguy.security/main.yml
	echo ""
	checking_errors $?
	echo ""
fi

    	install_fail2ban

if [[ ! -d "${SETTINGS_STORAGE}/docker/geerlingguy.firewall" ]]; then

	#configuration iptables
	echo -e "${BLUE}### IPTABLES GEERLINGGUY ###${NC}"
	echo ""
	ansible-galaxy install geerlingguy.firewall
	cp "${SETTINGS_SOURCE}/includes/dockerapps/templates/iptables/main.yml" "${SETTINGS_STORAGE}/docker/geerlingguy.firewall" > /dev/null 2>&1
	cp "${SETTINGS_SOURCE}/includes/dockerapps/templates/iptables/defaults/main.yml.j2" "${SETTINGS_STORAGE}/docker/geerlingguy.firewall/defaults/main.yml"
	echo ""
	echo -e " ${BWHITE}* Arrêt de docker${NC}"
	service docker stop > /dev/null 2>&1
	checking_errors $?
	echo ""
	ansible-playbook ${SETTINGS_STORAGE}/docker/geerlingguy.firewall/main.yml
	echo ""
	echo -e " ${BWHITE}* Remise en service de Docker${NC}"
	service docker start > /dev/null 2>&1
	checking_errors $?
	echo ""

else

	echo -e "${BLUE}### IPTABLES GEERLINGGUY ###${NC}"
	echo ""
	echo -e " ${BWHITE}* Arrêt de docker${NC}"
	service docker stop > /dev/null 2>&1
	checking_errors $?
	echo ""
	ansible-playbook ${SETTINGS_STORAGE}/docker/geerlingguy.firewall/main.yml
	echo ""
	echo -e " ${BWHITE}* Remise en service de Docker (Environ 2mn d'attente) ${NC}"
	service docker start > /dev/null 2>&1
	checking_errors $?
	echo ""
fi
