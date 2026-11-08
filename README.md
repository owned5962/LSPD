# Serveur GTA 5 Roleplay FiveM - 50 Métiers & Tablette Admin

Serveur GTA 5 RP complet et modulaire pour FiveM, prêt à être déployé.

## 🌟 Fonctionnalités Incluses

1. **Système de Personnage & Enregistrement (`rp_characters`)**
   - Écran d'enregistrement / login avec carte d'identité RP (Nom, Prénom, Date de Naissance, Sexe, Taille).
   - Menu de personnalisation de personnage / skin (visage, cheveux, vêtements, couleurs) avec interface NUI moderne.
   - Sélecteur de point d'apparition (Aéroport, Gare centrale, Hôpital, etc.).
   - Support multi-personnages par compte joueur.

2. **Économie Complète (`rp_economy`)**
   - Gestion de l'argent liquide (Cash) et compte bancaire (Bank).
   - Salaires automatisés selon le grade et la prise de service.
   - Interface NUI de Distributeur Automatique (ATM) et Banque (Dépôt, Retrait, Virement avec IBAN RP, Historique des transactions).

3. **50 Métiers RP Configurés (`rp_jobs`)**
   - Exactement 50 métiers réalistes et variés avec grades progressifs, salaires et prise de service.
   - Pôle Emploi (Job Center) interactif en NUI pour postuler ou choisir son métier civil.
   - Liste des 50 métiers :
     1. Policier (LSPD)
     2. Médecin / Secouriste (EMS)
     3. Sapeur-Pompier
     4. Avocat
     5. Juge
     6. Mécanicien
     7. Chauffeur de Taxi
     8. Agent Immobilier
     9. Journaliste / Reporter
     10. Mineur
     11. Bûcheron
     12. Livreur Express
     13. Banquier / Gestionnaire financier
     14. Éboueur
     15. Pêcheur en Mer
     16. Agriculteur / Fermier
     17. Boucher
     18. Brasseur Artisanal
     19. Agent de Sécurité Privée
     20. Pilote de Ligne Commercial
     21. Conducteur de Train / Métro
     22. Chef Cuisinier / Restaurateur
     23. Barman / Mixologue
     24. Dépanneur / Remorqueur
     25. Concessionnaire Automobile
     26. Électricien de Réseau
     27. Plombier / Chauffagiste
     28. Technicien Informatique & Cybersécurité
     29. Armurier Agréé
     30. Couturier / Designer de Mode
     31. Pharmacien
     32. Architecte & Urbaniste
     33. Vétérinaire
     34. Organisateur d'Événements
     35. Photographe de Presse
     36. Agent d'Entretien & Propreté
     37. Facteur / Agent Postal
     38. Plongeur Sous-Marin / Récupérateur
     39. Chauffeur de Bus Urbain
     40. Vigneron / Sommelier
     41. Coursier à Vélo
     42. Soudeur Industriel
     43. Capitaine de Bateau de Plaisance
     44. Docker Portuaire
     45. Croupier de Casino
     46. Coach Sportif
     47. Projectionniste de Cinéma
     48. Fleuriste
     49. Garde-Chasse / Ranger
     50. Contrebandier / Marché Noir (Underground)

4. **Écran de Chargement Moderne (`rp_loadscreen`)**
   - Design épuré cyberpunk / modern roleplay.
   - Lecteur de musique avec contrôle du volume et mute.
   - Présentation du règlement serveur, touches clés et équipe.
   - Barre de chargement FiveM dynamique.

5. **Menu Admin Style Tablette (`rp_tablet_admin`)**
   - Design fidèle de tablette numérique (iPad / Android OS) avec écran d'accueil, dock, batterie, heure en direct.
   - Applications de gestion intégrées :
     - **Joueurs** : Voir joueurs connectés, téléportation, freeze, kick, ban, revive.
     - **Économie** : Donner / Retirer Cash et Banque en un clic.
     - **Métiers** : Assigner instantanément l'un des 50 métiers et choisir le grade.
     - **Véhicules** : Faire apparaître n'importe quel véhicule par modèle, réparer, supprimer.
     - **Monde** : Contrôler la météo (Ensoleillé, Pluie, Brume, etc.) et l'heure en temps réel.
     - **Annonces** : Diffuser un flash info ou annonce serveur à tous les joueurs.
   - Accessible via la commande `/admin` ou la touche F10 (configurable ACE permission).

## 🚀 Installation & Démarrage

1. Importer `database.sql` dans votre serveur MySQL ou MariaDB.
2. Éditer `server.cfg` :
   - Indiquer votre clé FiveM Keymaster (`sv_licenseKey`).
   - Ajuster la chaîne de connexion MySQL (`mysql_connection_string`).
3. Lancer le serveur avec `./run.sh` ou votre gestionnaire FiveM.
