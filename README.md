# Los Santos Roleplay - FiveM

## Installation
1. Installez les artifacts FXServer.
2. Installez la ressource [oxmysql](https://github.com/overextended/oxmysql) dans votre dossier resources.
3. Créez la base MySQL/MariaDB et importez `database.sql`.
4. Modifiez `mysql_connection_string` dans `server.cfg` avec un compte SQL dédié (pas root).
5. Remplacez les clés FiveM/Steam d'exemple.
6. Ajoutez les administrateurs via ACE, par exemple `add_principal identifier.license:VOTRE_LICENSE group.admin`.
7. Démarrez le serveur.

## Personnages et persistance
- Identité du compte basée sur l'identifiant FiveM `license:`.
- Jusqu'à 3 personnages par compte, avec sélection à la connexion.
- Les données sont stockées dans MySQL : identité, argent, banque, métier, grade, position et données d'apparence.
- Sauvegarde automatique toutes les 5 minutes et sauvegarde à la déconnexion.
- `oxmysql` doit être démarré avant `rp_core` et `rp_characters`.

## Permissions administrateur
La tablette vérifie la permission ACE `rp_admin` ou le groupe serveur `admin` / `superadmin`. Aucun privilège n'est accordé selon le numéro de joueur.
