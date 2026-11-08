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

## Organisation des ressources

- `resources/[CORE]` : `rp_core` et `rp_characters`.
- `resources/[JOB]` : les 50 ressources métiers (`job_*`).
- `resources/[FUNCTION]` : économie, inventaire, interactions, vêtements, interface, tablette admin, anticheat et autres systèmes transversaux.

Les noms des ressources FiveM (`rp_core`, `job_police`, etc.) restent inchangés ; seuls leurs dossiers de regroupement ont changé. Le `server.cfg` est conservé tel quel.

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
3. Exécutez une seule fois `migrations/001_character_persistence.sql`, `migrations/002_inventory_persistence.sql`, puis `migrations/003_persistent_bans.sql` et `migrations/004_character_metadata.sql` sur la base existante.
4. Redémarrez le serveur avec oxmysql installé et configuré.

La migration adapte le champ de date de naissance. Elle ne supprime aucun personnage. Si vous avez des dates invalides ou un schéma personnalisé, vérifiez la base avant l'exécution.

## État fonctionnel connu

- Les 50 ressources métiers sont présentes, compilent et valident leur métier côté serveur. La majorité ne contient toutefois que la prise de service : les missions propres à chaque métier (tournées, récolte, fabrication, livraison, vente, progression et véhicules adaptés) restent à concevoir et implémenter. Elles ne doivent pas être présentées comme des métiers complets.
- Les actions de menottage, amende, facturation, soins et réanimation sont disponibles avec contrôle de proximité et prise de service.
- Les consommables alimentaires, boissons et soins sont persistés en SQL. Les objets utilitaires sans effet serveur restent volontairement inutilisables.
- Le dépôt au sol et les actions de réparation/nettoyage/fourrière de véhicules restent désactivés tant que leur cycle serveur sécurisé n'est pas implémenté.

## Vérifications à effectuer avec FXServer

Les contrôles statiques et compilations sont automatisés dans GitHub Actions. Le démarrage FXServer reste nécessaire pour confirmer la découverte des ressources dans les dossiers de catégorie, les dépendances réelles, la connexion oxmysql, l'exécution des migrations, OneSync, les entités réseau, les NUI et les interactions entre plusieurs joueurs.

## Persistance et limites
- Le compte est associé à l'identifiant FiveM `license:`.
- Les personnages sont enregistrés dans MySQL et sélectionnés à chaque connexion.
- Les emplacements sont limités à 3 par compte.
- Les inventaires sont persistés par personnage dans `player_inventories` ; sur une base existante, appliquez la migration `002_inventory_persistence.sql`.
- La faim et la soif sont persistées dans `characters.metadata` ; sur une base existante, appliquez aussi `migrations/004_character_metadata.sql`.
- Les aliments, boissons et soins consomment désormais une unité après validation et sauvegarde SQL ; les objets sans effet codé restent non utilisables.
- Le dépôt au sol reste désactivé tant qu'un système serveur de ramassage sécurisé n'est pas installé.
- Les bannissements anticheat sont persistants par identifiant `license:` ; la commande console ou staff `/rp_unban license:...` permet de les lever.
- Les sauvegardes automatiques réduisent la perte de données, mais une sauvegarde régulière de la base reste indispensable.
- Les métadonnées d'apparence sont stockées ; leur application complète au ped doit être raccordée au système de vêtements/skin du serveur.

## Permissions administrateur
La tablette vérifie la permission ACE `rp_admin` ou le groupe serveur `admin` / `superadmin`. Aucun privilège n'est accordé selon le numéro de joueur.
