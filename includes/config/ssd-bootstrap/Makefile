# Makefile - gestion centralisée des tâches d'installation et de démarrage

# Par défaut : mode verbeux (change en ARGS=--silent si tu veux du silence)
ARGS ?= --verbose

# Cibles individuelles
install-system:
	@bash scripts/setup-system.sh $(ARGS)

install-traefik:
	@bash scripts/setup-traefik.sh $(ARGS)

install-aliases:
	@bash scripts/setup-aliases.sh $(ARGS)

start:
	@if [ "$(ARGS)" = "--silent" ]; then \
		bash scripts/start-services.sh > /dev/null 2>&1; \
	else \
		bash scripts/start-services.sh $(ARGS); \
	fi

# Cible complète
setup-all: install-system start install-traefik install-aliases

clean:
	sudo rm -rf ${HOME}/projet-ssd

restart:
	pm2 restart backend || true
	pm2 restart frontend || true

stop:
	pm2 stop backend || true
	pm2 stop frontend || true

remove:
	pm2 delete backend || true
	pm2 delete frontend || true
	pm2 save

status:
	pm2 list
