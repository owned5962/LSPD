# AEGIS — Sécurité et anti-cheat

## Garanties côté serveur

- Les événements de détection reçus d'un client sont considérés comme des **signaux non vérifiés**. Ils sont journalisés avec `source_type = 'client'`, affichés « À vérifier » et ne déclenchent jamais de sanction automatique.
- Les détections issues d'événements serveur FiveM (`weaponDamageEvent`, `entityCreating`, `explosionEvent`) et de l'export serveur `RecordServerDetection` sont identifiées comme preuves serveur.
- Une sanction automatique n'est exécutée que si le signal est d'origine serveur **et** si les deux écritures de journal ont abouti.
- Les fenêtres anti-spam des signalements client et des événements serveur sont indépendantes : un faux signalement client ne peut pas masquer une détection serveur pendant son délai de refroidissement.
- Les accès à la tablette, les changements de protections, la configuration des sanctions, les bannissements, les débanissements et la surveillance sont validés côté serveur et limités en fréquence.
- Les demandes de politique d'armes sont limitées à une par joueur toutes les trois secondes. La politique et les protections effectives sont resynchronisées aux joueurs qui rejoignent après le démarrage.
- Les sanctions manuelles respectent la hiérarchie : un membre du staff ne peut sanctionner qu'un rang strictement inférieur ; le fondateur peut sanctionner les administrateurs et superadministrateurs, mais pas un autre fondateur.
- Les sanctions manuelles et automatiques, les changements de configuration et les débanissements sont inscrits dans `admin_logs`.
- La prison est persistante et sa zone est contrôlée périodiquement par le serveur ; la libération est décidée par l'heure de fin enregistrée en SQL, pas par l'horloge seule du client.
- Les identifiants SQL sont paramétrés. Les tables de configuration des protections et paramètres AEGIS sont initialisées et rechargées au démarrage.

## Détections actuellement actives

- Armes interdites lors d'un événement de dégâts serveur.
- Création excessive d'entités par joueur.
- Spam d'explosions.
- Signalements client : invincibilité, vitesse à pied, armes interdites et vision thermique/nocturne. Ces derniers sont des indices de surveillance uniquement et doivent être confirmés côté serveur avant toute sanction automatique.

Le catalogue de politique d'armes est persisté dans `anticheat_weapon_rules`. Les protections et leur état sont conservés dans `anticheat_protection_config`. La durée de prison et les paramètres runtime sont conservés dans `anticheat_runtime_config`.

## Base de données

Toutes les évolutions SQL (migrations 001 à 010) sont désormais regroupées dans le fichier unique `database.sql`.

Pour une nouvelle installation comme pour une base existante, effectuer d'abord une sauvegarde complète, sélectionner la base cible, puis exécuter :

```sql
SOURCE database.sql;
```

Le fichier est réexécutable : les tables utilisent `IF NOT EXISTS`, les données de catalogue `INSERT IGNORE`, et les adaptations de colonnes/index vérifient leur présence avant modification. Les anciennes lignes AEGIS reçoivent `source_type = 'legacy'` lorsqu'elles n'ont pas de provenance connue. Le resource AEGIS initialise également ses tables de statistiques au démarrage.

## Contrôles et limites

Le workflow `.github/workflows/anticheat-statistics.yml` exécute les tests de régression AEGIS, vérifie la syntaxe Lua du client/serveur/config et contrôle le JavaScript de la tablette.

Les détections de vitesse, GodMode et vision restent des signaux client : FiveM ne fournit pas ici une preuve suffisamment fiable pour les sanctionner automatiquement sans validation serveur dédiée. La surveillance multi-joueurs, les faux positifs d'entités, le comportement OneSync et les sanctions doivent être testés sur un FXServer de test avec plusieurs clients. Aucun test en direct, déploiement ni redémarrage de production n'est effectué par cette PR.
