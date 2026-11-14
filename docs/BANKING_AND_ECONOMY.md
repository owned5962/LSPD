# Banque et économie

## Composants

- `rp_economy` : comptes personnels, dépôts, retraits, virements, sessions bancaires, salaires et journal des opérations.
- `rp_jobbank` (dans `rp_economy/server/jobbank.lua`) : comptes partagés par métier, dépôts/retraits et historique.
- `rp_tablet_job` : statistiques de versements de salaire et accès au compte du métier depuis le menu F4.
- `rp_tablet_creator` : consultation des comptes métiers et activation indépendante des dépôts/retraits pour chaque métier.
- `rp_fuel` : écrit les remboursements de carburant dans le journal bancaire.

## Règles fonctionnelles et protections

- Les banques et distributeurs doivent être déclarés dans `rp_businesses`. Le serveur vérifie la proximité réelle du joueur avant l'authentification et chaque opération.
- Une session biométrique est liée au personnage connecté et expire après 5 minutes. Elle est invalidée en cas de changement de personnage, de sortie de portée ou de déconnexion.
- Les opérations personnelles et les opérations des comptes métiers sont plafonnées à 1 000 000 $ par demande.
- Les dépôts/retraits personnels et virements utilisent les verrous de personnage du cœur RP. Les soldes SQL sont vérifiés au moment de l'écriture.
- Les virements sont réservés aux agences bancaires, pas aux distributeurs.
- Les comptes métiers sont créés depuis le catalogue `rp_jobs`. Les autorisations de dépôt et de retrait sont vérifiées à la fois côté serveur et dans la requête SQL.
- Le compte métier est accessible depuis la banque après authentification et depuis le menu métier F4. Le menu F4 reste soumis au métier courant, aux limites d'action et aux autorisations du compte.
- Si l'écriture de l'historique d'un compte métier échoue, le système tente d'annuler l'opération avant de libérer le verrou du personnage. Si l'annulation échoue également, une alerte critique est inscrite dans la console.
- Les 20 dernières opérations personnelles sont affichées dans le terminal bancaire. L'historique du compte métier affiche les 12 dernières opérations dans F4 et jusqu'à 250 dans Creator.
- Les salaires sont versés toutes les 10 minutes aux personnages connectés, au montant défini par le grade du métier. Aucun salaire de secours arbitraire n'est payé si le catalogue ou le montant du grade est indisponible. La persistance, le journal et la notification du salaire sont gérés par `rp_core:addBank`.

## Base de données

Les schémas bancaires et les évolutions historiques (migrations 006, 008 et 009) sont regroupés dans `database.sql`. Pour une nouvelle installation ou une base existante sauvegardée, exécuter ce fichier sur la base cible :

```sql
SOURCE database.sql;
```

Le catalogue métier et les comptes partagés sont créés sans écraser les paramètres déjà personnalisés. Les types `fuel_refund` et `fuel` ainsi que l'index des statistiques salariales sont vérifiés et ajoutés uniquement s'ils manquent.

## Vérifications

Le workflow `.github/workflows/bank-transactions.yml` exécute les tests de régression des banques personnelles, du compte métier, des salaires, de l'historique, ainsi que la compilation Lua et la vérification JavaScript.

Les tests GitHub ne remplacent pas un test d'intégration sur un FXServer et une base MySQL de test. Aucun redémarrage, déploiement ou test sur le serveur de production n'est effectué par ces changements.
