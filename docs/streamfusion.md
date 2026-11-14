# StreamFusion Reborn : installation et utilisation avec SSDV2

StreamFusion Reborn est un addon pour Stremio, orienté contenus francophones.
Il recherche des sources à partir des indexeurs et services de débridage
configurés, puis propose les résultats dans Stremio avec vos préférences de
langue et de qualité. Son administration Web permet de gérer les réglages de
l'instance et les clés utilisateur.

Ce guide décrit l'installation depuis le catalogue SSDV2. SSDV2 prépare
l'application, PostgreSQL, Redis, le worker Taskiq, le planificateur et les
secrets internes. Aucun fichier `.env` ou Docker Compose n'est à créer pour
cette installation. L'image utilisée est `laster13/stream-fusion-reborn:latest`.

## Prérequis

- Une installation SSDV2 à jour avec un sous-domaine accessible en HTTPS.
- Stremio sur l'appareil de lecture.
- Une clé API TMDB, disponible dans les
  [paramètres API du compte TMDB](https://www.themoviedb.org/settings/api).
- Une clé d'administration personnelle d'au moins **32 caractères**, à
  conserver dans un gestionnaire de mots de passe.
- Les accès aux débrideurs et indexeurs que vous souhaitez utiliser. Ils
  peuvent être configurés après l'installation.

Dans les exemples, remplacez `streamfusion.votre-domaine.fr` et
`proxy.votre-domaine.fr` par les sous-domaines choisis dans SSDV2.

## Choisir sa sortie réseau

Le proxy est **facultatif**. Choisissez le mode correspondant à votre serveur
et au trajet souhaité pour la vidéo.

| Configuration | `PROXY_URL` dans StreamFusion | Comportement |
| --- | --- | --- |
| Serveur atHome, sans proxy | Vide | Les appels sortants de StreamFusion utilisent la sortie Internet du serveur. Sans VPN ni autre routage, il s'agit de son IP résidentielle. |
| Proxy directement utilisé par StreamFusion | URL du proxy | StreamFusion et son worker reçoivent le même réglage proxy. |
| Vidéo gérée par SSDV2 Proxy Manager | Peut rester vide | Proxy Manager relaie la vidéo selon sa sortie média ; StreamFusion conserve sa propre sortie pour ses appels aux débrideurs. |

### Distinguer les appels API et la lecture vidéo

Il existe plusieurs connexions indépendantes :

1. **StreamFusion vers les débrideurs** : la sortie dépend du serveur
   StreamFusion, de `PROXY_URL` et, pour AllDebrid, de `AD_BASE_URL`.
2. **Stremio ou Proxy Manager vers l'addon** : récupération du manifeste et
   des résultats de recherche.
3. **Téléchargement de la vidéo** : effectué par l'appareil de lecture,
   StreamFusion ou Proxy Manager, selon la proxification des flux choisie.

Le réglage **Proxy API** de Proxy Manager concerne sa connexion à l'addon.
Il ne redirige pas automatiquement les appels internes de StreamFusion aux
API des débrideurs.

Héberger StreamFusion à domicile ne suffit donc pas à faire passer toutes les
vidéos par l'IP résidentielle du serveur : sans relais vidéo, c'est le lecteur
qui télécharge le média avec sa propre sortie réseau.

Si StreamFusion et Proxy Manager sont hébergés sur des machines différentes,
leurs sorties **Direct** peuvent correspondre à deux IP publiques différentes.

## Installer depuis le menu ou la WebUI SSDV2

Sélectionnez **streamfusion** dans le catalogue. Choisissez le sous-domaine et
le type d'authentification proposés par SSDV2 pour l'administration.

L'assistant demande les quatre réglages suivants :

| Question | Valeur attendue | Comportement |
| --- | --- | --- |
| `TMDB_API_KEY` | Votre clé API TMDB | Obligatoire. |
| `ADMIN_SECRET_KEY` | Votre clé d'administration | Au moins 32 caractères. |
| `AD_BASE_URL` | Adresse de l'API AllDebrid | Sur une nouvelle installation, Entrée utilise `https://api.alldebrid.com`. |
| `PROXY_URL` | URL de votre proxy, si nécessaire | Sur une nouvelle installation, Entrée laisse le proxy désactivé. La saisie est masquée. |

Pour une installation standard, l'adresse AllDebrid recommandée est :

```text
https://api.alldebrid.com
```

Cette adresse ne remplace pas votre clé ou votre compte AllDebrid. Les accès au
service de débridage se configurent ensuite dans StreamFusion.

Sur un serveur atHome en sortie résidentielle, laissez `PROXY_URL` vide. Vous
pouvez également laisser ce champ vide si Proxy Manager gère ensuite la vidéo.
Pour un proxy directement utilisé par StreamFusion, renseignez une URL joignable
depuis les conteneurs, avec ses identifiants si nécessaires.

**SSDV2 Relay reste facultatif.** Si vous l'utilisez pour l'API AllDebrid,
renseignez son adresse dans `AD_BASE_URL`. Un éventuel proxy StreamFusion doit
pouvoir joindre cette adresse, notamment si le relais utilise un nom Docker
privé. Le relais AllDebrid ne transporte pas la vidéo.

Laissez SSDV2 terminer le déploiement. Les secrets internes sont générés
et conservés automatiquement ; les réinstallations les réutilisent.

## Premier accès et clés utilisateur

Ouvrez l'administration :

```text
https://streamfusion.votre-domaine.fr/admin/
```

Si une protection SSDV2 est activée, connectez-vous à celle-ci, puis utilisez
votre `ADMIN_SECRET_KEY` pour l'administration StreamFusion.

Configurez les sources de votre instance et créez une **clé API utilisateur**
dans la gestion des clés de l'administration. Utilisez une clé distincte pour
chaque utilisateur.

Les clés ont des rôles différents :

- `ADMIN_SECRET_KEY` sert à l'administration de StreamFusion.
- La clé API utilisateur sert à configurer et utiliser l'addon dans Stremio.
- `SECRET_API_KEY` est un secret interne généré par SSDV2, distinct de la clé
  d'administration et des clés utilisateur.

Les routes consommées par Stremio restent accessibles sans connexion à la
protection Web de l'administration ; l'authentification de l'addon repose sur
ses propres clés. N'ajoutez pas de connexion SSO interactive sur ces routes.

## Configurer l'addon et l'ajouter dans Stremio

Ouvrez la page de configuration :

```text
https://streamfusion.votre-domaine.fr/
```

1. Renseignez votre clé API utilisateur.
2. Connectez votre service de débridage.
3. Sélectionnez les indexeurs disponibles et renseignez leurs accès si demandés.
4. Choisissez vos préférences de langue, de qualité et de codec.
5. Utilisez le bouton **Installer** pour obtenir le lien du manifeste.

Utilisez le lien complet fourni par le configurateur. La page d'accueil et
l'adresse `/admin/` ne sont pas des manifestes.

Sans Proxy Manager, ouvrez le lien avec Stremio ou ajoutez-le comme addon par
URL. Testez ensuite un film et une série connus de vos sources.

Avec Proxy Manager, copiez le manifeste généré et poursuivez avec la section
suivante. Pour laisser le manager assurer le relais vidéo, désactivez la
proxification des flux dans la configuration StreamFusion utilisée pour ce
manifeste, afin que le manager reçoive les liens média d'origine.

## Utiliser SSDV2 Proxy Manager avec StreamFusion

Cette intégration est facultative. Elle permet de centraliser les manifestes
et de choisir qui télécharge la vidéo et avec quelle sortie réseau.

### Installer et ouvrir Proxy Manager

1. Installez **ssdv2proxy** depuis le catalogue SSDV2.
2. Choisissez son sous-domaine, par exemple `proxy.votre-domaine.fr`.
3. Définissez le mot de passe d'administration demandé : **12 caractères minimum**.
4. Ouvrez son adresse HTTPS et connectez-vous avec votre identifiant SSDV2
   et le **mot de passe dédié à Proxy Manager** choisi à l'installation.

Ce mot de passe est distinct de celui de StreamFusion. Les liens générés pour
Stremio restent accessibles sans connexion interactive à l'administration du
manager.

### Préparer une sortie réseau et importer le manifeste

Dans **Proxies**, utilisez une sortie existante ou ajoutez un proxy adapté.
Le bouton **Tester** permet de vérifier son IP de sortie.

La sortie **Direct** utilise l'IP du serveur hébergeant Proxy Manager. Si ce
serveur est à domicile sans VPN système ni autre routage, il utilise son IP
résidentielle.

Dans **Bibliothèque**, importez le manifeste complet généré par StreamFusion.
Réglez ensuite les connexions :

| Réglage | Choix et effet |
| --- | --- |
| **Proxy API** | Normalement Direct pour joindre votre instance StreamFusion. |
| **Lecture : Via le serveur** | Proxy Manager télécharge et relaie la vidéo. |
| **Proxy média** | Direct utilise l'IP du serveur du manager ; une autre sortie utilise le proxy ou VPN sélectionné. |
| **Lecture : Chez le lecteur** | Le lecteur télécharge lui-même le média avec sa propre sortie réseau. |

Vous pouvez conserver `PROXY_URL` vide dans StreamFusion. La gestion du média
par Proxy Manager ne modifie pas pour autant les appels internes de
StreamFusion aux débrideurs.

### Créer un profil et installer son lien

Dans **Profils**, créez un profil puis ajoutez le manifeste StreamFusion depuis
la bibliothèque. Vérifiez les réglages effectifs de ce manifeste dans le profil :
connexion API, mode de lecture et sortie média. Les réglages personnalisés du
profil peuvent remplacer ceux de la bibliothèque.

Enregistrez, puis récupérez le lien de collection ou le lien individuel généré
par Proxy Manager. **Installez ce lien dans Stremio** pour utiliser le routage
du manager. Installer uniquement le manifeste StreamFusion d'origine ne fait
pas passer la lecture par Proxy Manager.

Pour un premier essai, utilisez uniquement la version de l'addon installée par
le manager afin de reconnaître les résultats qui suivent ce trajet.

### Utiliser une passerelle VPN native

Dans la gestion des proxies/VPN natifs du manager, ajoutez votre configuration
WireGuard ou OpenVPN et les identifiants requis. Attendez que la passerelle
soit active, testez son IP, puis choisissez-la comme sortie média.

Vérifiez également une lecture réelle : un tunnel actif ne garantit pas que
sa sortie soit acceptée par le débrideur.

SSDV2 Relay et Proxy Manager ont des rôles distincts : le relais traite l'API
AllDebrid et ne remplace pas une sortie média du manager.

## Réinstallation et réglages mémorisés

Les quatre réglages sont conservés dans :

```text
$SETTINGS_STORAGE/docker/$USER/streamfusion-secrets/
```

Avec le stockage SSDV2 par défaut, cela correspond à
`~/seedbox/docker/<utilisateur>/streamfusion-secrets/`. Le dossier est en
**0700** et les fichiers en **0600**. Ces paramètres ne sont pas enregistrés
dans `seedbox/conf` ; les registres Docker génériques restent inchangés.

Les fichiers mémorisés ont la priorité sur les valeurs récupérées depuis
l'ancien conteneur. Lors du premier passage d'une ancienne installation,
les valeurs absentes sont reprises depuis `stream-fusion` s'il existe encore,
sans lire le YAML personnalisé. Un proxy vide enregistré est une valeur valide.

Relancez l'installation depuis SSDV2 pour modifier les réglages. Si des valeurs
sont déjà disponibles, l'assistant demande :

> Modifier les réglages mémorisés ?

- **Entrée / non** : conserver les valeurs ; seules les informations manquantes
  sont demandées.
- **Oui** : reposer les quatre questions.
- Pendant la saisie, **Entrée** conserve une valeur existante.
- Pour `PROXY_URL`, **`-`** désactive le proxy.

Les secrets internes et les données PostgreSQL sont conservés lors d'une
réinstallation avec conservation des données. Une simple mise à jour des images
sans rejouer le playbook ne repose pas les questions.

## Changer uniquement le proxy StreamFusion

Dans un terminal SSH SSDV2, utilisez la saisie masquée, notamment si le proxy
contient des identifiants :

```bash
streamfusion_proxy
```

Pour désactiver le proxy et revenir à la sortie réseau directe du serveur :

```bash
streamfusion_proxy --disable
```

Vous pouvez aussi fournir une URL directement lorsque cela convient à votre
usage :

```bash
streamfusion_proxy 'http://proxy:1080'
```

Sans argument, Entrée seule ne modifie rien ; `-` désactive le proxy.

La commande mémorise le changement et recrée uniquement **stream-fusion** et
**taskiq-worker**, avec leurs images actuelles, volumes, labels et autres
paramètres. Elle ne rejoue pas le playbook et peut provoquer une brève
interruption. Les deux conteneurs doivent être présents avant toute modification.

Elle conserve `AD_BASE_URL` : le proxy choisi doit pouvoir joindre cette
adresse, en particulier si elle désigne un relais privé.

Si une recréation échoue, la commande renvoie une erreur et indique les
conteneurs concernés, sans afficher le proxy. La valeur reste mémorisée ;
relancez la commande avec le même réglage pour terminer son application.

La commande ne modifie pas un éventuel YAML personnalisé. Celui-ci garde la
priorité habituelle SSDV2 lors des prochains déploiements ; il doit réutiliser
les variables de l'intégration publique pour reprendre les réglages mémorisés.

## Automatiser l'installation

Fournissez les variables Ansible suivantes :

| Variable | Rôle |
| --- | --- |
| `streamfusion_tmdb_api_key` | Clé TMDB. |
| `streamfusion_admin_secret_key` | Clé d'administration, 32 caractères minimum. |
| `streamfusion_ad_base_url` | URL de l'API AllDebrid. |
| `streamfusion_proxy_url` | URL du proxy ; chaîne vide pour aucun proxy. |
| `streamfusion_reconfigure` | `false` conserve les valeurs mémorisées sans question de confirmation. |

Une valeur explicitement fournie remplace la valeur mémorisée. Sans saisie
interactive, les valeurs existantes sont réutilisées ; une clé obligatoire
manquante ou une configuration invalide arrête l'installation avant le
déploiement. Ne placez pas vos secrets dans un dépôt partagé.

## Vérifier et dépanner

### Valider une installation

1. Ouvrez l'administration et le configurateur.
2. Générez un manifeste et vérifiez sa présence dans Stremio.
3. Testez un film et une série connus de vos sources.
4. Lancez une vidéo avec le mode réseau choisi.
5. Avec Proxy Manager, testez la sortie et le média pour vérifier le trajet réel.

Une recherche réussie ne valide pas le téléchargement vidéo : les connexions
peuvent suivre des chemins différents.

### Aucun résultat

Vérifiez la clé TMDB, les accès au débrideur, les indexeurs activés et les
filtres de langue ou de qualité. L'installation des conteneurs ne configure
pas automatiquement vos comptes de débridage et vos sources personnelles.

### Des résultats, mais aucune lecture

Vérifiez le lien installé dans Stremio, le mode **Via le serveur** ou **Chez le
lecteur** et la sortie média choisie. Si vous utilisez Proxy Manager, vérifiez
que le lien installé provient bien de ce manager.

Avec AllDebrid, vérifiez aussi que les sorties utilisées pour générer et lire
le lien conviennent au service. Une IP résidentielle ou un VPN ne garantit
pas à elle seule une lecture réussie.

### État et journaux

```bash
ssdv2ctl app status streamfusion
docker logs --tail 100 stream-fusion
docker logs --tail 100 taskiq-worker
```

Si `streamfusion_proxy` n'est pas reconnue, mettez SSDV2 à jour puis ouvrez une
nouvelle session SSH. En cas d'échec partiel de la commande, relancez-la avec
le même réglage pour terminer l'application du proxy.

## Sauvegardes et mises à jour

Avant une mise à jour, sauvegardez les données persistantes, la base PostgreSQL
et le dossier `streamfusion-secrets`. Celui-ci contient aussi les secrets
internes nécessaires pour retrouver votre configuration.

Si vous utilisez Proxy Manager, conservez également ses données, profils et
configurations de sorties réseau. Une réinstallation avec conservation des
données ne remplace pas une sauvegarde.

## Références techniques

- [Configuration StreamFusion SSDV2](https://github.com/projetssd/ssdv2/blob/master/includes/dockerapps/vars/streamfusion.yml).
- [Préparation et questions d'installation](https://github.com/projetssd/ssdv2/blob/master/includes/dockerapps/pretasks/streamfusion.yml).
- [Intégration SSDV2 Proxy Manager](https://github.com/projetssd/ssdv2/blob/master/includes/dockerapps/vars/ssdv2proxy.yml).

Les fichiers techniques liés ci-dessus ciblent la branche stable `master`.
Pour examiner une installation sur `dev`, sélectionnez cette branche dans le
dépôt source.
