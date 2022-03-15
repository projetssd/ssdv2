#!/bin/bash

source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

if [[ ! -d "/opt/seedbox/docker/geerlingguy.security" ]]; then

	echo "roles_path = /opt/seedbox/docker" >> "/etc/ansible/ansible.cfg"
	#configuration ssh
	mkdir -p /opt/seedbox/docker/geerlingguy.security/defaults
	echo -e "${BLUE}### SSH GEERLINGGUY ###${NC}"
	echo ""
	ansible-galaxy install geerlingguy.security
	cp "$BASEDIR/includes/dockerapps/templates/ssh/main.yml" "/opt/seedbox/docker/geerlingguy.security" > /dev/null 2>&1
	sed -i '/UseDNS/d' /opt/seedbox/docker/geerlingguy.security/tasks/ssh.yml
	echo ""
	echo -e "\n${CCYAN} /!\ Par mesure de sécurité il est fortement consseillé de changer le port ssh /!\ ${CEND}"
	echo ""
	cp "/opt/seedbox-compose/includes/dockerapps/templates/ssh/defaults/main.yml.j2" "/opt/seedbox/docker/geerlingguy.security/defaults/main.yml"
	ansible-playbook /opt/seedbox/docker/geerlingguy.security/main.yml
	echo ""
	checking_errors $?
	echo ""

else

	echo -e "${BLUE}### SSH GEERLINGGUY ###${NC}"
	echo ""
	echo -e "\n${CCYAN} /!\ Par mesure de sécurité il est fortement conseillé de changer le port ssh /!\ ${CEND}"
	echo ""
	mkdir -p /opt/seedbox/docker/geerlingguy.security/defaults
	cp "/opt/seedbox-compose/includes/dockerapps/templates/ssh/defaults/main.yml.j2" "/opt/seedbox/docker/geerlingguy.security/defaults/main.yml"
	ansible-playbook /opt/seedbox/docker/geerlingguy.security/main.yml
	echo ""
	checking_errors $?
	echo ""
fi

    	install_fail2ban

if [[ ! -d "/opt/seedbox/docker/geerlingguy.firewall" ]]; then

	#configuration iptables
	echo -e "${BLUE}### IPTABLES GEERLINGGUY ###${NC}"
	echo ""
	ansible-galaxy install geerlingguy.firewall
	cp "$BASEDIR/includes/dockerapps/templates/iptables/main.yml" "/opt/seedbox/docker/geerlingguy.firewall" > /dev/null 2>&1
	cp "$BASEDIR/includes/dockerapps/templates/iptables/defaults/main.yml.j2" "/opt/seedbox/docker/geerlingguy.firewall/defaults/main.yml"
	echo ""
	echo -e " ${BWHITE}* Arrêt de docker${NC}"
	service docker stop > /dev/null 2>&1
	checking_errors $?
	echo ""
	ansible-playbook /opt/seedbox/docker/geerlingguy.firewall/main.yml
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
	ansible-playbook /opt/seedbox/docker/geerlingguy.firewall/main.yml
	echo ""
	echo -e " ${BWHITE}* Remise en service de Docker (Environ 2mn d'attente) ${NC}"
	service docker start > /dev/null 2>&1
	checking_errors $?
	echo ""
fi
