# Serveur GTA 5 Roleplay FiveM - Los Santos RP

Serveur RP modulaire comprenant un système de personnages, une économie, 50 métiers et une tablette d'administration.

## Fonctionnalités
- Création et sélection de jusqu'à 3 personnages par compte FiveM.
- Identité RP : prénom, nom, date de naissance, sexe et taille.
- Données persistantes : argent liquide, banque, métier, grade, position et métadonnées d'apparence.
- Sauvegarde automatique des joueurs toutes les 5 minutes et à la déconnexion.
- Économie avec dépôts, retraits, virements et salaires.
- 50 métiers RP et grades.
- Tablette admin protégée par ACE.

## Installation neuve
1. Installez les artifacts FXServer.
2. Installez la ressource [oxmysql](https://github.com/overextended/oxmysql) dans votre dossier resources.
3. Créez la base MySQL/MariaDB et importez `database.sql`.
4. Modifiez `mysql_connection_string` dans `server.cfg` avec un compte SQL dédié disposant des droits nécessaires sur la base (évitez root).
5. Remplacez les clés FiveM/Steam d'exemple.
6. Ajoutez les administrateurs via ACE, par exemple :
   ```cfg
   add_principal identifier.license:VOTRE_LICENSE group.admin
   ```
7. Vérifiez que `ensure oxmysql` apparaît avant `ensure rp_core`, puis démarrez le serveur.

## Mise à jour d'une base existante
1. Faites une sauvegarde complète de la base.
2. Arrêtez le serveur.
3. Exécutez une seule fois `migrations/001_character_persistence.sql` sur la base existante.
4. Redémarrez le serveur avec oxmysql installé et configuré.

La migration adapte le champ de date de naissance. Elle ne supprime aucun personnage. Si vous avez des dates invalides ou un schéma personnalisé, vérifiez la base avant l'exécution.

## Persistance et limites
- Le compte est associé à l'identifiant FiveM `license:`.
- Les personnages sont enregistrés dans MySQL et sélectionnés à chaque connexion.
- Les emplacements sont limités à 3 par compte.
- Les sauvegardes automatiques réduisent la perte de données, mais une sauvegarde régulière de la base reste indispensable.
- Les métadonnées d'apparence sont stockées ; leur application complète au ped doit être raccordée au système de vêtements/skin du serveur.

## Permissions administrateur
La tablette vérifie la permission ACE `rp_admin` ou le groupe serveur `admin` / `superadmin`. Aucun privilège n'est accordé selon le numéro de joueur.
