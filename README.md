# Los Santos Roleplay — serveur FiveM

## Installation

1. Installer FXServer et configurer la clé de licence FiveM.
2. Installer les dépendances, notamment oxmysql, puis renseigner `mysql_connection_string` dans `server.cfg`.
3. Importer `database.sql` dans la base dédiée.
4. Placer les ressources du dépôt dans le dossier `resources`.
5. Installer les ressources CFX officielles nécessaires depuis le dépôt **cfx-server-data** :

   - Linux/macOS (bash) : `bash install-cfx-defaults.sh`
   - Windows (PowerShell) : `./install-cfx-defaults.ps1`

Les scripts récupèrent les ressources standard `spawnmanager`, `sessionmanager`, `hardcap` et `baseevents` depuis `citizenfx/cfx-server-data` et les installent dans `resources/[cfx-default]`. Ils conservent les versions déjà présentes.

## Démarrage

Lancer FXServer avec ce `server.cfg`. Les ressources CFX téléchargées ne sont pas démarrées automatiquement : les quatre ressources ci-dessus ne figurent volontairement pas dans les lignes `ensure` de cette configuration, afin d'éviter les conflits avec le système de personnages et de session du serveur RP.

Les ressources personnalisées doivent démarrer dans l'ordre défini dans `server.cfg`. En particulier, `rp_jobs` doit précéder `rp_economy`, et `rp_territories` démarre après les métiers.

## Vérifications

Les tests de régression Python sont dans le dossier `tests`. Les workflows GitHub Actions vérifient les ressources Lua, les interfaces JavaScript et les régressions statiques. Une validation en environnement FiveM réel reste nécessaire pour confirmer les interactions réseau, les natives et les migrations SQL.
