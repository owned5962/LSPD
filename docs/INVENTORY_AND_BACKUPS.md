# Inventaire et sauvegardes

## Persistance de l'inventaire

- Les inventaires sont isolés par personnage dans `player_inventories` (clé primaire `character_id`).
- Les usages, transferts, dépôts/retraits de coffres et objets au sol sont persistés en SQL, avec transactions pour les opérations multi-écritures.
- Les objets déposés au sol sont conservés dans `player_inventory_drops` et recréés au démarrage de la ressource.
- Les exports serveur `AddItem` et `AdminSetItem` prennent maintenant le verrou du personnage et le verrou de transfert avant d'écrire, pour éviter les mises à jour concurrentes perdues.
- Les données envoyées au client ne donnent jamais au client l'autorité sur le contenu SQL : le serveur revalide objet, quantité, poids, distance et instance.

## Migration

Sur une base existante, faire une sauvegarde complète avant toute migration, puis appliquer dans l'ordre :

1. `migrations/002_inventory_persistence.sql`
2. `migrations/003_inventory_ground_drops.sql`

Le schéma complet neuf contient aussi ces deux tables dans `database.sql`. Les migrations sont idempotentes grâce à `CREATE TABLE IF NOT EXISTS`.

## Sauvegarde MySQL/MariaDB

Les scripts créent un dump cohérent pour InnoDB, incluent routines, triggers et events, compressent le résultat, vérifient l'archive et produisent un SHA-256. La rétention par défaut est de 14 jours. Les identifiants sont lus depuis l'environnement ; le mot de passe doit être fourni via `MYSQL_PWD`, jamais dans la ligne de commande.

### Linux

Définir `DB_NAME`, `DB_USER`, `MYSQL_PWD` et éventuellement `DB_HOST`, `DB_PORT`, `BACKUP_DIR`, `RETENTION_DAYS`, puis exécuter :

```bash
chmod 700 scripts/backup-db.sh
./scripts/backup-db.sh
```

Pour automatiser quotidiennement à 03:00 avec cron, utiliser un fichier d'environnement protégé (droits 600) et une entrée cron qui le charge avant le script. Le dossier de sauvegarde doit être sur un volume distinct du dossier de données MySQL.

### Windows PowerShell

Définir les mêmes variables d'environnement dans le contexte du compte de service, puis exécuter :

```powershell
.\scripts\backup-db.ps1
```

Planifier le script avec le Planificateur de tâches Windows sous un compte dédié ayant accès à `mysqldump.exe` et au dossier de sauvegarde.

## Restauration

1. Arrêter le serveur FiveM ou empêcher les connexions pendant la restauration.
2. Vérifier le SHA-256 du fichier.
3. Décompresser vers un fichier SQL temporaire.
4. Restaurer dans une base cible vide ou préalablement sauvegardée avec le client `mysql`.
5. Vérifier les tables `characters`, `player_inventories` et `player_inventory_drops`, puis démarrer le serveur et contrôler les journaux.

Une sauvegarde n'est réellement validée qu'après un test de restauration périodique sur une base de test. Ne jamais tester une restauration sur la base de production.

## Limites opérationnelles

Les scripts ne créent pas à eux seuls une tâche planifiée sur la machine d'hébergement. La planification doit être configurée sur le serveur Linux/Windows. Conserver au moins une copie hors machine (NAS ou stockage distant chiffré) pour se protéger d'une panne ou compromission de l'hôte.
