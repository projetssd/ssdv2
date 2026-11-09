# Isolation des corrections sur dev

Le lot catalogue, P2/P3, masquage des secrets, QR WireGuard et les modifications
locales préexistantes de SSDV2 Relay sont conservés sur la branche `dev`.

- Référence principale : `/home/kesurof/seedbox-compose`, branche `master`, SHA
  `801f229c372cb8d6a84afabbf5170ecf51674205` conservé.
- Développement et tests : `/home/kesurof/seedbox-compose-dev`, branche `dev`.
- WebUI associée : `/home/kesurof/projets/SSDV2-webui-dev`, branche `dev`.

L'utilisateur autorise les pushes `dev` dans les deux dépôts. Aucun push de
`master`/`main`, fusion, changement de branche par défaut ou déploiement n'est inclus.
Les fichiers ignorés, données, secrets, bases et dépendances ne sont pas commités.

## Contrôles

Depuis le worktree SSDV2 dev : validateurs du catalogue et des facts, tests Bats,
`tests/test_peer_qr.py`, `tests/test_persistent_permissions.py`, contrôles YAML,
ShellCheck et syntaxe/lint Ansible. La CI exécute les nouveaux tests ; le binaire
Ansible est sélectionné via `ANSIBLE_PLAYBOOK` ou le PATH, avec repli vers `venv`.
Les tests de permissions n'agissent que sur des dossiers temporaires.

Les environnements des worktrees sont distincts et la configuration SSDV2 de l'hôte
reste inchangée. La synchronisation du CLI vendored WebUI doit désigner ce worktree :

```bash
SSDV2_REPO=/home/kesurof/seedbox-compose-dev bash scripts/sync-ssdv2ctl.sh
```

Exécuter cette commande depuis le worktree WebUI dev. Son workflow ne publie que
`ghcr.io/projetssd/ssdv2-webui:dev` pour un push/lancement manuel de dev. Les autres
règles de publication sont décrites dans `docs/DEVELOPMENT-BRANCHES.md` du dépôt
WebUI. Les applications installées et le tag `latest` ne sont pas mis à jour.
