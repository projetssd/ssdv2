# Makefile centralisé

# Mode verbeux par défaut (ARGS=--silent pour réduire les logs)
ARGS ?= --verbose

install-system:
	@bash scripts/setup-system.sh $(ARGS)

install-traefik:
	@bash scripts/setup-traefik.sh $(ARGS)

install-aliases:
	@bash scripts/setup-aliases.sh $(ARGS)

deploy:
	@bash scripts/setup-deploy.sh $(ARGS)

start:
	@pm2 start all || true

stop:
	@pm2 stop all || true

restart:
	@pm2 restart all || true

status:
	@pm2 list

clean:
	@rm -rf ${HOME}/seedbox/docker/$(shell id -un)/projet-ssd

# Installe tout : système, traefik, déploiement, alias
setup-all: install-system install-traefik deploy install-aliases
