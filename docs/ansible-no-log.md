# `no_log` dans SSDV2 : portée réelle

Ce document décrit ce que `no_log` protège, ce qu'il ne protège pas, et sur
quelles versions la vérification a été faite. Les secrets utilisés sont fictifs.

## Versions testées

| Version exacte | Origine |
|---|---|
| `ansible-core 2.18.20` (`ansible==11.13.0`) | version épinglée du job CI `ansible-syntax` |
| `ansible-core 2.21.0` | environnement de développement local (`venv`) |

Aucune conclusion n'est tirée pour les autres versions, ni pour « ≥ 2.21 » en
général : le comportement du bandeau d'erreur est apparu avec 2.21.0 et peut
encore changer.

## Reproduction

Playbook minimal, exécuté avec un secret fictif :

```json
[{
  "hosts": "localhost",
  "gather_facts": false,
  "tasks": [{
    "name": "Échec avec message",
    "no_log": true,
    "ansible.builtin.fail": { "msg": "échec : fixture-module-error-secret-9913" }
  }]
}]
```

```bash
ansible-playbook -i localhost, -c local play.json -vv
```

## Résultats observés

| Version | Ligne de résultat | Bandeau `[ERROR]` | Secret visible |
|---|---|---|---|
| 2.18.20 | `{"censored": "the output has been hidden due to the fact that 'no_log: true' was specified for this result"}` | absent | non |
| 2.21.0 | ligne `censored` identique | `[ERROR]: Task failed: Action failed: échec : fixture-module-error-secret-9913` | **oui**, dans le bandeau |

Un échec réel de `community.docker.docker_container` a également été provoqué
(image invalide) : ni `env`, ni le secret ne sont repris dans le message
d'erreur, en 2.18 comme en 2.21. Le bandeau de 2.21 reprend le message du
module, pas ses arguments.

## Ce que chaque canal expose

| Canal | Couvert par `no_log` ? |
|---|---|
| Résultat de tâche Ansible (affichage et `log_path`) | oui |
| Bandeau d'erreur `[ERROR]` | non en 2.21.0, sans objet en 2.18.20 |
| Message d'erreur écrit par le module | non : il est affiché tel quel |
| Sortie directe d'un programme (`command`, `shell`) | non, si le programme écrit le secret lui-même |
| `docker logs <conteneur>` | non : hors d'Ansible |
| Fichier écrit par l'application | non : la protection dépend de ses permissions (`0600`) |
| Ligne de commande d'un processus (visible via `ps`) | non : `no_log` ne change pas `argv` |

## Conséquences pour les intégrations SSDV2

- `no_log` sur une tâche qui expose un secret dans ses arguments est
  indispensable, mais ne protège pas du `ps`.
- Un module qui renvoie un jeton dans son résultat (authentification) doit être
  masqué : c'est le cas de `uri` dans `beszel`.
- Les secrets restitués à l'utilisateur passent par un fichier `0600` dont seul
  le chemin est affiché.
- Le test `tests/test_relay_proxy.py::test_no_log_censors_result_and_error_line_depends_on_version`
  lit la version d'Ansible et vérifie le comportement attendu de chacune, pour
  que la CI (2.18) et un poste en 2.21 ne divergent pas silencieusement.
