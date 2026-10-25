# PHP2Shell — CVE-2026-109618 / CVE-2026-109619

Deux vulnérabilités critiques du coeur de PHP, corrigées dans PHP 8.2.35,
8.3.36, 8.4.27 et 8.5.12. Elles permettent une exécution de code à distance
non authentifiée lorsqu'un serveur PHP traite des requêtes HTTP.

## Ce que fait SSDV2

Le menu **Gestion → Sécurisation système → Audit PHP (php2shell)** et les
commandes `ssdv2ctl security php-cve` couvrent trois niveaux :

1. **Hôte** : paquets PHP de la distribution, binaires, SAPI, services
   FPM/Apache/nginx, exposition.
2. **Conteneurs** : runtime PHP détecté par `docker exec`, version upstream ou
   version du paquet de distribution, état des mitigations.
3. **SSDV2** : inventaire des applications PHP installées et du catalogue. La
   WebUI SSDV2 est en Python/FastAPI, elle n'est pas concernée par PHP.

## Pourquoi `php -v` ne suffit pas

Sur Ubuntu 24.04, la version upstream reste `8.3.6` avant et après le
correctif. La version corrigée est un numéro de paquet :

```text
php8.3 8.3.6-0ubuntu0.24.04.12  -> vulnérable
php8.3 8.3.6-0ubuntu0.24.04.13  -> corrigé (USN-8948-1)
```

Le script compare donc la version du paquet (`dpkg`, `rpm`, `apk`) à la version
corrigée connue, et utilise la version upstream uniquement pour les images PHP
officielles ou lorsqu'aucune version distributeur n'est connue.

## Menu

```text
1) Audit complet (hôte + SSDV2 + conteneurs)
2) Corriger le serveur (paquets PHP)
3) Mettre à jour les conteneurs PHP gérés par SSDV2
4) Appliquer les mitigations temporaires (hôte)
5) Isoler/arrêter un conteneur vulnérable
6) Rapport détaillé / export JSON
7) Aide / CVE php2shell
8) Retour
```

L'option 2 lance `apt-get update` puis `apt-get install --only-upgrade` sur les
paquets PHP installés. L'option 3 utilise le mécanisme SSDV2 de mise à jour
d'image (pull + recréation), sans suppression des volumes. Les images épinglées
ou les conteneurs hors SSDV2 sont signalés, pas modifiés automatiquement.

## Menu et cache

Le menu **Gestion → Sécurisation système → Audit PHP (php2shell)** travaille
sur le dernier audit en cache (`${SETTINGS_STORAGE}/conf/phpcve-status.json`).

- **Option 1** : seul scan du menu ; écrit le cache puis affiche le rapport.
- **Options 3, 5 et 6** : utilisent le cache, sans relancer de scan.
- **Options 2, 3, 4 et 5** : suppriment le cache après action ; relancer
  l'option 1 pour actualiser.
- Le menu reste ouvert après chaque action ; seul **8** revient au menu parent.
- Les confirmations affichent explicitement `(o/n)`.
- L'entête et le rapport affichent une **recommandation prioritaire**.

## Commandes

```bash
phpcve.py scan --json
phpcve.py report
phpcve.py fix-host
phpcve.py fix-app nextcloud
phpcve.py fix-container nextcloud --force
phpcve.py stop nextcloud
phpcve.py harden-host
phpcve.py selftest
```

Via `ssdv2ctl` :

```bash
ssdv2ctl security php-cve scan --json
ssdv2ctl security php-cve report
ssdv2ctl security php-cve fix-host
ssdv2ctl security php-cve fix-app <app>
ssdv2ctl security php-cve fix-container <conteneur>
ssdv2ctl security php-cve stop <conteneur>
ssdv2ctl security php-cve harden-host
```

`scan` / `report` retournent le code `1` si au moins un élément reste
vulnérable. Le rapport JSON est écrit dans
`${SETTINGS_STORAGE}/conf/phpcve-status.json` depuis le menu.

## Mitigations

Les mitigations sont **partielles** et ne remplacent jamais le patch :

- `session.upload_progress.enabled=0` : bloque les chemins confirmés via les
  sessions d'upload ;
- `fatal_error_backtraces=0` : PHP 8.5 uniquement ;
- `pm.max_requests=1` : réduit la réutilisation des workers FPM ;
- limites de taille de requête au niveau du proxy / serveur web.

`harden-host` écrit `99-php2shell.ini` dans les répertoires
`/etc/php/<version>/{fpm,apache2,cli}/conf.d` existants. Pour un conteneur, les
valeurs ini affichées proviennent du binaire `php` (SAPI CLI) : vérifier aussi
la configuration FPM/Apache de l'image.

`memory_limit=-1` n'est pas appliqué automatiquement : cela supprime une
protection contre l'épuisement mémoire du serveur. Le script le signale mais
laisse le choix à l'administrateur.

## Ce que le script ne fait pas

- Il ne corrige pas une image upstream qui n'a pas encore publié de PHP patché.
- Il ne change pas les tags d'image épinglés.
- Il ne modifie pas automatiquement les conteneurs qui ne sont pas gérés par
  SSDV2.
- Il ne supprime aucun volume ni aucune donnée.
- Il ne garantit pas les mitigations pour toutes les applications : chaque
  image PHP a sa propre configuration.

## Fichiers

```text
patches/20261022_php2shell
includes/config/scripts/phpcve.py
includes/menus-phpcve.sh
docs/php2shell.md
tests/bats/phpcve.bats
```

## Références

- PHP 8.5.12 / 8.4.27 / 8.3.36 / 8.2.35
- USN-8948-1 (Ubuntu)
- CVE-2026-109618 / GHSA-w8hw-w9fx-j79w
- CVE-2026-109619 / GHSA-6wmf-4rv5-p3rp
