# Serveur GTA 5 Roleplay FiveM - Los Santos RP

Serveur RP modulaire comprenant un système de personnages, une économie, 50 métiers et une tablette d'administration.

## Fonctionnalités
- Création et sélection de jusqu'à 3 personnages par compte FiveM.
- Identité RP : prénom, nom, date de naissance, sexe et taille.
- Données persistantes : argent liquide, banque, métier, grade, position et métadonnées d'apparence.
- Sauvegarde automatique des joueurs toutes les 5 minutes et à la déconnexion.
- Économie avec dépôts, retraits, virements et salaires.
- 50 métiers RP et grades.
- Garages personnels avec véhicules persistants, rangement/sortie sécurisés et sauvegarde des améliorations.
- Ateliers mécaniques avec prévisualisation des upgrades et paiement bancaire contrôlé côté serveur.
- Tablette admin protégée par ACE.

## Contrat central des joueurs

`rp_core` est l'unique registre serveur des personnages actifs. Un personnage est publié via l'export `RegisterPlayer` uniquement après validation de sa session et de son identifiant. Les ressources peuvent utiliser `GetPlayerFromId`, `IsPlayerLoaded` et `WaitForPlayerLoaded` ; les événements `rp_core:server:playerLoaded` et `rp_core:server:playerUnloaded` signalent les changements de session.

Le client reçoit un instantané autoritaire `PlayerData` comprenant l'identité, le personnage, les soldes, le métier/grade, le groupe, l'état de service, les besoins, les métadonnées, la position, l'apparence, le téléphone et l'état de décès. Les ressources métiers partagent l'état de service avec `rp_core` au lieu d'avoir des copies indépendantes.

Les 50 ressources `job_*` n'utilisent pas directement MySQL : elles passent par les exports de `rp_core` et `rp_jobs`. Le pilote oxmysql reste chargé uniquement par les ressources qui effectuent réellement des opérations persistantes ou des requêtes SQL.

## Organisation des ressources

- `resources/[CORE]` : `rp_core` et `rp_characters`.
- `resources/[JOB]` : les 50 ressources métiers (`job_*`).
- `resources/[FUNCTION]` : économie, inventaire, interactions, vêtements, interface, tablette admin, anticheat et autres systèmes transversaux.

Les noms des ressources FiveM (`rp_core`, `job_police`, etc.) restent inchangés ; seuls leurs dossiers de regroupement ont changé. Le `server.cfg` doit être adapté au dossier `resources` réel de l'installation.

## Installation neuve
1. Installez les artifacts FXServer.
2. Installez les ressources standard depuis le dépôt officiel [cfx-server-data](https://github.com/citizenfx/cfx-server-data) dans le dossier `resources` du serveur. Sous Windows, depuis la racine du projet, exécutez `powershell -ExecutionPolicy Bypass -File .\\install-cfx-defaults.ps1` (ajoutez `-ResourceRoot "D:\\chemin\\vers\\resources"` si nécessaire). Sous Linux, exécutez `bash install-cfx-defaults.sh` (ou définissez `FXSERVER_RESOURCES_DIR` si le dossier resources est ailleurs). Ces scripts installent uniquement les ressources manquantes `spawnmanager`, `sessionmanager`, `hardcap` et `baseevents` dans `[cfx-default]`, sans écraser celles déjà présentes. Le `server.cfg` les démarre explicitement : ne laissez pas ces ressources absentes.
3. Installez la ressource [oxmysql](https://github.com/overextended/oxmysql) dans votre dossier resources.
4. Créez la base MySQL/MariaDB puis importez une seule fois `database.sql` : le schéma, les inventaires, les bannissements, les métiers et les adaptations de structure prises en charge sont regroupés dans ce fichier.
5. Modifiez `mysql_connection_string` dans `server.cfg` avec un compte SQL dédié disposant des droits nécessaires sur la base (évitez root).
6. Remplacez les clés FiveM/Steam d'exemple.
7. Ajoutez les administrateurs via ACE, par exemple :
   ```cfg
   add_principal identifier.license:VOTRE_LICENSE group.admin
   ```
8. Vérifiez l'ordre de démarrage : ressources CFX standard, `oxmysql`, `rp_core`, `rp_jobs`, `rp_economy`, puis les autres ressources. `rp_jobs` doit être disponible avant les systèmes qui utilisent ses exports.

## Mise à jour d'une base existante
1. Faites une sauvegarde complète de la base.
2. Arrêtez le serveur.
3. Importez `database.sql` sur la base existante : les tables sont déclarées avec `IF NOT EXISTS`, les métiers sont ajoutés avec `INSERT IGNORE` et les adaptations `dateofbirth` / `metadata` sont conditionnelles. Les données et salaires déjà présents ne sont pas remplacés par le catalogue initial.
4. Redémarrez le serveur avec oxmysql installé et configuré.

Le passage de `dateofbirth` de `VARCHAR` à `DATE` suppose que les valeurs existantes sont des dates valides au format `YYYY-MM-DD`. Vérifiez les valeurs atypiques avant l'import. Les anciens fichiers du dossier `migrations/` sont conservés comme historique ; ils ne sont plus nécessaires pour une installation neuve ni pour la mise à jour standard décrite ici.

## État fonctionnel connu

- Les 50 ressources métiers sont présentes et compilées. La prise de service vérifie côté serveur le métier, le type de statut et la proximité du point de service ; l'état de service est nettoyé à la déconnexion. La majorité ne contient toutefois que la prise de service : les missions propres à chaque métier (tournées, récolte, fabrication, livraison, vente, progression et véhicules adaptés) restent à concevoir et implémenter. Elles ne doivent pas être présentées comme des métiers complets.
- Les actions de menottage, amende, facturation, soins et réanimation sont disponibles avec contrôle de proximité et prise de service.
- Les actions véhicule de mécanicien (réparation/nettoyage) et de police/dépanneur (fourrière) sont traitées côté serveur avec vérification du métier, du service, de l'entité réseau et de la proximité. La fourrière refuse un véhicule occupé.
- Les tenues sauvegardées peuvent être consultées et réappliquées depuis la boutique ; leur enregistrement met à jour la tenue du personnage et l'historique en transaction SQL.
- Les consommables alimentaires, boissons et soins sont persistés en SQL. Les objets utilitaires sans effet serveur restent volontairement inutilisables.
- Le dépôt au sol et les actions de réparation/nettoyage/fourrière de véhicules restent désactivés tant que leur cycle serveur sécurisé n'est pas implémenté.

## Vérifications à effectuer avec FXServer

Les contrôles statiques et compilations sont automatisés dans GitHub Actions. Les métadonnées de la liste publique (nom, description, tags, langue et bannières) doivent désormais être configurées dans le portail Cfx.re. Le démarrage FXServer reste nécessaire pour confirmer la découverte des ressources dans les dossiers de catégorie, les dépendances réelles, la connexion oxmysql, l'exécution des migrations, OneSync, les entités réseau, les NUI et les interactions entre plusieurs joueurs.

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
- Les métadonnées d'apparence et les tenues sauvegardées sont stockées en SQL ; les variations de vêtements et accessoires peuvent être appliquées depuis le système de personnages et la boutique.


## Garages et ateliers mécaniques

La ressource `rp_garages` réutilise le registre `rp_owned_vehicles` créé par `rp_vehicle_dealership`. Elle permet de ranger et ressortir un véhicule uniquement si la plaque, le personnage et l'identifiant propriétaire correspondent. L'état du moteur, de la carrosserie, le carburant, les couleurs et les modifications sont sauvegardés en JSON dans `vehicle_props`. Les ateliers configurés dans `resources/[FUNCTION]/rp_garages/config.lua` proposent les améliorations moteur, freins, transmission, suspension, blindage, turbo et phares xénon. Les prix sont recalculés côté serveur, débités sur le compte bancaire, puis la sauvegarde SQL est confirmée avant validation définitive ; en cas d'échec, un remboursement est tenté.

## Console créateur F11

La tablette créateur est réservée aux comptes autorisés (ACE `rp_creator`, groupe `fondateur` ou `superadmin`). Elle permet :
- de modifier le nom du serveur et d'enregistrer le nombre de slots (un redémarrage peut être nécessaire pour appliquer la capacité) ;
- de démarrer/arrêter les modules facultatifs et les ressources `job_*` ; les ressources essentielles, l'inventaire, l'économie, les tablettes staff et l'anticheat restent protégés ;
- de changer la météo et l'heure, déjà disponibles dans la console ;
- de gérer les joueurs connectés : prénom, nom, âge, rôle, métier/grade, soldes bancaires et argent liquide ;
- d'ajouter ou retirer un objet de l'inventaire depuis le catalogue du serveur ;
- d'appliquer un skin freemode par défaut homme/femme ou de conserver le skin actuel ;
- d'activer/désactiver individuellement les tablettes Admin (F10), Anticheat (F9) et Créateur (F11) pour chaque compte.

Les tables de configuration `rp_creator_settings`, `rp_creator_module_state` et `rp_creator_player_access` sont créées automatiquement par la ressource. La gestion de joueurs depuis cette interface concerne les personnages actuellement connectés. Le rôle modérateur est enregistrable, mais ne donne pas automatiquement tous les droits administrateur.

Le fichier `server-icon.png` (96 × 96) est déclaré dans `server.cfg` via `load_server_icon server-icon.png` pour afficher le logo dans la liste FiveM.

## Permissions administrateur
La tablette vérifie la permission ACE `rp_admin` ou le groupe serveur `admin`, `superadmin` ou `fondateur`. Les accès aux tablettes Admin, Anticheat et Créateur peuvent aussi être désactivés individuellement depuis la console créateur. Aucun privilège n'est accordé selon le numéro de joueur.


## Auto-école et permis

La ressource `rp_drivingschool` propose cinq catégories : moto, voiture, avion, bateau et hélicoptère. Chaque permis possède un tarif configurable, un examen théorique de cinq questions (validation à 4/5) puis une épreuve pratique avec véhicule et checkpoints dédiés. Les réponses correctes restent côté serveur ; la progression pratique vérifie le personnage, le véhicule réseau, son modèle, le siège conducteur et la proximité des checkpoints. Les permis obtenus sont enregistrés dans `rp_driving_licenses`, par personnage et catégorie. Les tarifs, véhicules, lieux de départ et parcours sont configurés dans `resources/[FUNCTION]/rp_drivingschool/config.lua`. Importez `database.sql` pour créer la table de persistance.
