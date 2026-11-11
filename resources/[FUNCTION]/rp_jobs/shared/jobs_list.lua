JobsList = {
    -- 1. Police (LSPD)
    {
        name = "police",
        label = "Policier (LSPD)",
        category = "public_service",
        icon = "fas fa-shield-alt",
        description = "Maintien de l'ordre, patrouille et sécurité des citoyens de San Andreas.",
        whitelisted = true,
        grades = {
            [0] = { label = "Cadet", salary = 250 },
            [1] = { label = "Officier", salary = 400 },
            [2] = { label = "Sergent", salary = 600 },
            [3] = { label = "Lieutenant", salary = 850 },
            [4] = { label = "Capitaine", salary = 1100 }
        }
    },
    -- 2. EMS / Secouriste
    {
        name = "ambulance",
        label = "Médecin / Secouriste (EMS)",
        category = "public_service",
        icon = "fas fa-heartbeat",
        description = "Soins d'urgence médicale, interventions sur le terrain et réanimations.",
        whitelisted = true,
        grades = {
            [0] = { label = "Ambulancier stagiaire", salary = 250 },
            [1] = { label = "Secouriste qualifié", salary = 400 },
            [2] = { label = "Médecin urgentiste", salary = 650 },
            [3] = { label = "Chirurgien en chef", salary = 950 }
            [4] = { label = "Directeur de service", salary = 1250 }
        }
    },
    -- 3. Sapeur-Pompier
    {
        name = "firefighter",
        label = "Sapeur-Pompier",
        category = "public_service",
        icon = "fas fa-fire-extinguisher",
        description = "Lutte contre les incendies, sauvetage en milieu périlleux et accidents de la route.",
        whitelisted = true,
        grades = {
            [0] = { label = "Sapeur 2e classe", salary = 260 },
            [1] = { label = "Caporal", salary = 380 },
            [2] = { label = "Sergent", salary = 550 },
            [3] = { label = "Adjudant-Chef", salary = 800 }
            [4] = { label = "Directeur de service", salary = 1100 }
        }
    },
    -- 4. Avocat
    {
        name = "lawyer",
        label = "Avocat de la Défense",
        category = "justice",
        icon = "fas fa-balance-scale",
        description = "Conseil juridique, défense des droits des justiciables et plaidoiries.",
        whitelisted = false,
        grades = {
            [0] = { label = "Stagiaire au Barreau", salary = 220 },
            [1] = { label = "Avocat Associé", salary = 500 },
            [2] = { label = "Bâtonnier", salary = 900 }
            [3] = { label = "Responsable de service", salary = 1050 }
            [4] = { label = "Directeur de service", salary = 1200 }
        }
    },
    -- 5. Juge
    {
        name = "judge",
        label = "Juge / Magistrat",
        category = "justice",
        icon = "fas fa-gavel",
        description = "Application des lois, présidence des audiences de tribunal et prononcé des jugements.",
        whitelisted = true,
        grades = {
            [0] = { label = "Juge Assesseur", salary = 600 },
            [1] = { label = "Juge d'Instruction", salary = 850 },
            [2] = { label = "Président du Tribunal", salary = 1200 }
            [3] = { label = "Responsable de service", salary = 1350 }
            [4] = { label = "Directeur de service", salary = 1500 }
        }
    },
    -- 6. Mécanicien
    {
        name = "mechanic",
        label = "Mécanicien Benny's / LSC",
        category = "artisanat",
        icon = "fas fa-wrench",
        description = "Réparation, carrosserie, reprogrammation et customisation de véhicules.",
        whitelisted = false,
        grades = {
            [0] = { label = "Apprenti Garage", salary = 220 },
            [1] = { label = "Mécanicien Certifié", salary = 420 },
            [2] = { label = "Chef d'Atelier", salary = 700 }
            [3] = { label = "Responsable de service", salary = 850 }
            [4] = { label = "Directeur de service", salary = 1000 }
        }
    },
    -- 7. Chauffeur de Taxi
    {
        name = "taxi",
        label = "Chauffeur de Taxi Downtown Cab",
        category = "transport",
        icon = "fas fa-taxi",
        description = "Transport rapide de passagers à travers la métropole et le comté de Blaine.",
        whitelisted = false,
        grades = {
            [0] = { label = "Chauffeur Débutant", salary = 200 },
            [1] = { label = "Chauffeur Expérimenté", salary = 360 },
            [2] = { label = "Responsable de Flotte", salary = 550 }
            [3] = { label = "Responsable de service", salary = 700 }
            [4] = { label = "Directeur de service", salary = 850 }
        }
    },
    -- 8. Agent Immobilier
    {
        name = "realestate",
        label = "Agent Immobilier Century",
        category = "commerce",
        icon = "fas fa-home",
        description = "Estimation, visite et vente de propriétés résidentielles et commerciales.",
        whitelisted = false,
        grades = {
            [0] = { label = "Négociateur Junior", salary = 220 },
            [1] = { label = "Agent Senior", salary = 450 },
            [2] = { label = "Directeur d'Agence", salary = 800 }
            [3] = { label = "Responsable de service", salary = 950 }
            [4] = { label = "Directeur de service", salary = 1100 }
        }
    },
    -- 9. Journaliste / Reporter
    {
        name = "journalist",
        label = "Journaliste Weazel News",
        category = "media",
        icon = "fas fa-newspaper",
        description = "Couverture des actualités chaudes, interviews et investigation d'investigation.",
        whitelisted = false,
        grades = {
            [0] = { label = "Pigiste", salary = 200 },
            [1] = { label = "Grand Reporter", salary = 380 },
            [2] = { label = "Rédacteur en Chef", salary = 680 }
            [3] = { label = "Responsable de service", salary = 830 }
            [4] = { label = "Directeur de service", salary = 980 }
        }
    },
    -- 10. Mineur
    {
        name = "miner",
        label = "Mineur d'Extraction",
        category = "industrie",
        icon = "fas fa-gem",
        description = "Extraction de métaux précieux, minerais de fer et charbon dans la carrière.",
        whitelisted = false,
        grades = {
            [0] = { label = "Mineur Débutant", salary = 210 },
            [1] = { label = "Foreur Qualifié", salary = 350 },
            [2] = { label = "Contremaître Mine", salary = 520 }
            [3] = { label = "Responsable de service", salary = 670 }
            [4] = { label = "Directeur de service", salary = 820 }
        }
    },
    -- 11. Bûcheron
    {
        name = "lumberjack",
        label = "Bûcheron Forestier",
        category = "industrie",
        icon = "fas fa-tree",
        description = "Abattage, débitage et transport de bois dans les forêts de Paleto Bay.",
        whitelisted = false,
        grades = {
            [0] = { label = "Bûcheron Élaguer", salary = 210 },
            [1] = { label = "Scieur Industriel", salary = 360 },
            [2] = { label = "Chef d'Exploitation", salary = 540 }
            [3] = { label = "Responsable de service", salary = 690 }
            [4] = { label = "Directeur de service", salary = 840 }
        }
    },
    -- 12. Livreur Express
    {
        name = "delivery",
        label = "Livreur GoPostal Express",
        category = "transport",
        icon = "fas fa-box",
        description = "Livraison de colis, plis confidentiels et paquets aux commerces locaux.",
        whitelisted = false,
        grades = {
            [0] = { label = "Coursier Urbain", salary = 200 },
            [1] = { label = "Livreur Longue Distance", salary = 340 },
            [2] = { label = "Dispatcheur Logistique", salary = 500 }
            [3] = { label = "Responsable de service", salary = 650 }
            [4] = { label = "Directeur de service", salary = 800 }
        }
    },
    -- 13. Banquier / Gestionnaire Financier
    {
        name = "banker",
        label = "Banquier / Gestionnaire Financier",
        category = "finance",
        icon = "fas fa-piggy-bank",
        description = "Gestion des comptes d'entreprise, crédits et investissements de capitaux.",
        whitelisted = true,
        grades = {
            [0] = { label = "Conseiller Clientèle", salary = 300 },
            [1] = { label = "Chargé d'Affaires Pro", salary = 550 },
            [2] = { label = "Directeur d'Agence", salary = 950 }
            [3] = { label = "Responsable de service", salary = 1100 }
            [4] = { label = "Directeur de service", salary = 1250 }
        }
    },
    -- 14. Éboueur
    {
        name = "garbage",
        label = "Agent de Collecte des Déchets (Éboueur)",
        category = "public_service",
        icon = "fas fa-recycle",
        description = "Tournée matinale de collecte des ordures et nettoyage des bennes urbaines.",
        whitelisted = false,
        grades = {
            [0] = { label = "Ripeur Débutant", salary = 220 },
            [1] = { label = "Conducteur de Benne", salary = 350 },
            [2] = { label = "Responsable de Secteur", salary = 500 }
            [3] = { label = "Responsable de service", salary = 650 }
            [4] = { label = "Directeur de service", salary = 800 }
        }
    },
    -- 15. Pêcheur en Mer
    {
        name = "fisherman",
        label = "Pêcheur Professionnel",
        category = "artisanat",
        icon = "fas fa-fish",
        description = "Pêche côtière et hauturière, criée du poisson et livraison des restaurants.",
        whitelisted = false,
        grades = {
            [0] = { label = "Matelot de Pêche", salary = 210 },
            [1] = { label = "Pêcheur Hauturier", salary = 360 },
            [2] = { label = "Patron Pêcheur", salary = 550 }
            [3] = { label = "Responsable de service", salary = 700 }
            [4] = { label = "Directeur de service", salary = 850 }
        }
    },
    -- 16. Agriculteur / Fermier
    {
        name = "farmer",
        label = "Agriculteur / Maraîcher",
        category = "artisanat",
        icon = "fas fa-tractor",
        description = "Culture de céréales, légumes de saison et élevage de bétail à Grapeseed.",
        whitelisted = false,
        grades = {
            [0] = { label = "Ouvrier Agricole", salary = 210 },
            [1] = { label = "Exploitant Agricole", salary = 380 },
            [2] = { label = "Propriétaire de Ranch", salary = 600 }
            [3] = { label = "Responsable de service", salary = 750 }
            [4] = { label = "Directeur de service", salary = 900 }
        }
    },
    -- 17. Boucher
    {
        name = "butcher",
        label = "Artisan Boucher",
        category = "artisanat",
        icon = "fas fa-drumstick-bite",
        description = "Découpe, préparation de viandes et approvisionnement des charcuteries locales.",
        whitelisted = false,
        grades = {
            [0] = { label = "Apprenti Découpe", salary = 200 },
            [1] = { label = "Boucher Traiteur", salary = 360 },
            [2] = { label = "Maître Artisan", salary = 540 }
            [3] = { label = "Responsable de service", salary = 690 }
            [4] = { label = "Directeur de service", salary = 840 }
        }
    },
    -- 18. Brasseur Artisanal
    {
        name = "brewer",
        label = "Brasseur Artisanal",
        category = "artisanat",
        icon = "fas fa-beer",
        description = "Brassage de bières ambrées, blondes et houblonnées pour les pubs.",
        whitelisted = false,
        grades = {
            [0] = { label = "Aide Cuve", salary = 200 },
            [1] = { label = "Maître Brasseur", salary = 370 },
            [2] = { label = "Directeur de Brasserie", salary = 560 }
            [3] = { label = "Responsable de service", salary = 710 }
            [4] = { label = "Directeur de service", salary = 860 }
        }
    },
    -- 19. Agent de Sécurité Privée
    {
        name = "security",
        label = "Agent de Sécurité Privée (Gruppe 6)",
        category = "public_service",
        icon = "fas fa-user-shield",
        description = "Surveillance de sites sensibles, transport de fonds et filtrage d'événements.",
        whitelisted = false,
        grades = {
            [0] = { label = "Vigile Rondier", salary = 230 },
            [1] = { label = "Convoyeur de Fonds", salary = 400 },
            [2] = { label = "Chef de Poste", salary = 620 }
            [3] = { label = "Responsable de service", salary = 770 }
            [4] = { label = "Directeur de service", salary = 920 }
        }
    },
    -- 20. Pilote de Ligne Commercial
    {
        name = "pilot",
        label = "Pilote de Ligne Commercial",
        category = "transport",
        icon = "fas fa-plane",
        description = "Transport aérien civil, liaisons régulières Los Santos - Cayo Perico - Sandy Shores.",
        whitelisted = true,
        grades = {
            [0] = { label = "Copilote", salary = 350 },
            [1] = { label = "Commandant de Bord", salary = 650 },
            [2] = { label = "Instructeur Aéronautique", salary = 1000 }
            [3] = { label = "Responsable de service", salary = 1150 }
            [4] = { label = "Directeur de service", salary = 1300 }
        }
    },
    -- 21. Conducteur de Train / Métro
    {
        name = "train_driver",
        label = "Conducteur de Train & Métro",
        category = "transport",
        icon = "fas fa-subway",
        description = "Pilotage des rames ferroviaires de fret et de passagers à travers tout l'État.",
        whitelisted = false,
        grades = {
            [0] = { label = "Aspirant Conducteur", salary = 220 },
            [1] = { label = "Conducteur Titulaire", salary = 380 },
            [2] = { label = "Régulateur de Ligne", salary = 580 }
            [3] = { label = "Responsable de service", salary = 730 }
            [4] = { label = "Directeur de service", salary = 880 }
        }
    },
    -- 22. Chef Cuisinier / Restaurateur
    {
        name = "chef",
        label = "Chef Cuisinier / Restaurateur",
        category = "restauration",
        icon = "fas fa-utensils",
        description = "Élaboration de menus gastronomiques, gestion de brigade et service en salle.",
        whitelisted = false,
        grades = {
            [0] = { label = "Commis de Cuisine", salary = 210 },
            [1] = { label = "Chef de Partie", salary = 380 },
            [2] = { label = "Chef Étoilé", salary = 650 }
            [3] = { label = "Responsable de service", salary = 800 }
            [4] = { label = "Directeur de service", salary = 950 }
        }
    },
    -- 23. Barman / Mixologue
    {
        name = "bartender",
        label = "Barman / Mixologue (Vanilla Unicorn / Tequi-la-la)",
        category = "restauration",
        icon = "fas fa-cocktail",
        description = "Création de cocktails exclusifs, ambiance musicale et tenue du comptoir.",
        whitelisted = false,
        grades = {
            [0] = { label = "Barman Débutant", salary = 200 },
            [1] = { label = "Mixologue Confirmé", salary = 350 },
            [2] = { label = "Gérant de Bar", salary = 550 }
            [3] = { label = "Responsable de service", salary = 700 }
            [4] = { label = "Directeur de service", salary = 850 }
        }
    },
    -- 24. Dépanneur / Remorqueur
    {
        name = "towtruck",
        label = "Dépanneur / Remorqueur Autoroutier",
        category = "transport",
        icon = "fas fa-truck-pickup",
        description = "Intervention sur pannes d'urgence, remorquage de véhicules accidentés ou fourrière.",
        whitelisted = false,
        grades = {
            [0] = { label = "Opérateur Plateau", salary = 220 },
            [1] = { label = "Dépanneur Treuil", salary = 370 },
            [2] = { label = "Superviseur Fourrière", salary = 560 }
            [3] = { label = "Responsable de service", salary = 710 }
            [4] = { label = "Directeur de service", salary = 860 }
        }
    },
    -- 25. Concessionnaire Automobile
    {
        name = "cardealer",
        label = "Concessionnaire Automobile PDM",
        category = "commerce",
        icon = "fas fa-car",
        description = "Vente de véhicules neufs et d'occasion, essais routiers et financements.",
        whitelisted = false,
        grades = {
            [0] = { label = "Commercial Junior", salary = 220 },
            [1] = { label = "Conseiller Vente Élite", salary = 420 },
            [2] = { label = "Directeur de Concession", salary = 750 }
            [3] = { label = "Responsable de service", salary = 900 }
            [4] = { label = "Directeur de service", salary = 1050 }
        }
    },
    -- 26. Électricien de Réseau
    {
        name = "electrician",
        label = "Électricien Haute Tension",
        category = "artisanat",
        icon = "fas fa-bolt",
        description = "Maintenance du réseau électrique, réparation de transformateurs et câblage urbain.",
        whitelisted = false,
        grades = {
            [0] = { label = "Monteur Électricien", salary = 220 },
            [1] = { label = "Technicien Réseau", salary = 380 },
            [2] = { label = "Expert Réseau Haute Tension", salary = 580 }
            [3] = { label = "Responsable de service", salary = 730 }
            [4] = { label = "Directeur de service", salary = 880 }
        }
    },
    -- 27. Plombier / Chauffagiste
    {
        name = "plumber",
        label = "Plombier / Chauffagiste",
        category = "artisanat",
        icon = "fas fa-faucet",
        description = "Installation sanitaire, dépannage de fuites d'eau et réseau de canalisations.",
        whitelisted = false,
        grades = {
            [0] = { label = "Aide Plombier", salary = 210 },
            [1] = { label = "Plombier Sanitaire", salary = 360 },
            [2] = { label = "Chef de Chantier Fluides", salary = 540 }
            [3] = { label = "Responsable de service", salary = 690 }
            [4] = { label = "Directeur de service", salary = 840 }
        }
    },
    -- 28. Technicien Informatique & Cybersécurité
    {
        name = "it_tech",
        label = "Technicien Informatique & Cyber",
        category = "technologie",
        icon = "fas fa-laptop-code",
        description = "Maintenance des serveurs municipaux, cybersécurité et dépannage matériel.",
        whitelisted = false,
        grades = {
            [0] = { label = "Support Helpdesk", salary = 230 },
            [1] = { label = "Administrateur Système", salary = 420 },
            [2] = { label = "Ingénieur Sécurité IT", salary = 720 }
            [3] = { label = "Responsable de service", salary = 870 }
            [4] = { label = "Directeur de service", salary = 1020 }
        }
    },
    -- 29. Armurier Agréé
    {
        name = "armorer",
        label = "Armurier Agréé Ammu-Nation",
        category = "commerce",
        icon = "fas fa-crosshairs",
        description = "Vente d'armes réglementées de catégorie civile, munitions et accessoires balistiques.",
        whitelisted = true,
        grades = {
            [0] = { label = "Vendeur Stand de Tir", salary = 240 },
            [1] = { label = "Armurier Certifié", salary = 450 },
            [2] = { label = "Maître Canonnier", salary = 780 }
            [3] = { label = "Responsable de service", salary = 930 }
            [4] = { label = "Directeur de service", salary = 1080 }
        }
    },
    -- 30. Couturier / Designer de Mode
    {
        name = "tailor",
        label = "Couturier & Designer de Mode",
        category = "artisanat",
        icon = "fas fa-tshirt",
        description = "Création sur-mesure de smokings, robes haute couture et tenues d'entreprise.",
        whitelisted = false,
        grades = {
            [0] = { label = "Apprenti Couturier", salary = 200 },
            [1] = { label = "Tailleur Styliste", salary = 360 },
            [2] = { label = "Créateur de Mode", salary = 580 }
            [3] = { label = "Responsable de service", salary = 730 }
            [4] = { label = "Directeur de service", salary = 880 }
        }
    },
    -- 31. Pharmacien
    {
        name = "pharmacist",
        label = "Pharmacien / Préparateur Officine",
        category = "sante",
        icon = "fas fa-pills",
        description = "Délivrance de médicaments sur ordonnance, bandages et premiers soins d'appoint.",
        whitelisted = false,
        grades = {
            [0] = { label = "Préparateur en Pharmacie", salary = 220 },
            [1] = { label = "Docteur en Pharmacie", salary = 440 },
            [2] = { label = "Titulaire d'Officine", salary = 700 }
            [3] = { label = "Responsable de service", salary = 850 }
            [4] = { label = "Directeur de service", salary = 1000 }
        }
    },
    -- 32. Architecte & Urbaniste
    {
        name = "architect",
        label = "Architecte & Urbaniste",
        category = "services",
        icon = "fas fa-drafting-compass",
        description = "Conception de plans de bâtiments, rénovations d'intérieurs et aménagement foncier.",
        whitelisted = false,
        grades = {
            [0] = { label = "Dessinateur Projeteur", salary = 230 },
            [1] = { label = "Architecte DPLG", salary = 460 },
            [2] = { label = "Directeur de Projet", salary = 780 }
            [3] = { label = "Responsable de service", salary = 930 }
            [4] = { label = "Directeur de service", salary = 1080 }
        }
    },
    -- 33. Vétérinaire
    {
        name = "veterinarian",
        label = "Médecin Vétérinaire",
        category = "sante",
        icon = "fas fa-paw",
        description = "Soins aux animaux de compagnie et de ferme, vaccinations et chirurgies animalières.",
        whitelisted = false,
        grades = {
            [0] = { label = "Assistant Vétérinaire", salary = 210 },
            [1] = { label = "Praticien Vétérinaire", salary = 400 },
            [2] = { label = "Directeur Clinique Vétérinaire", salary = 680 }
            [3] = { label = "Responsable de service", salary = 830 }
            [4] = { label = "Directeur de service", salary = 980 }
        }
    },
    -- 34. Organisateur d'Événements
    {
        name = "event_planner",
        label = "Organisateur d'Événements & DJ",
        category = "divertissement",
        icon = "fas fa-calendar-check",
        description = "Organisation de soirées, festivals musicaux, salons automobiles et mariages.",
        whitelisted = false,
        grades = {
            [0] = { label = "Assistant Logistique Événements", salary = 210 },
            [1] = { label = "Coordinateur Fêtes & Galas", salary = 390 },
            [2] = { label = "Producteur Événementiel", salary = 650 }
            [3] = { label = "Responsable de service", salary = 800 }
            [4] = { label = "Directeur de service", salary = 950 }
        }
    },
    -- 35. Photographe de Presse
    {
        name = "photographer",
        label = "Photographe de Presse & Studio",
        category = "media",
        icon = "fas fa-camera",
        description = "Reportages photographiques sur le terrain, portraits artistiques et clichés judiciaires.",
        whitelisted = false,
        grades = {
            [0] = { label = "Photographe Indépendant", salary = 200 },
            [1] = { label = "Photographe Senior", salary = 360 },
            [2] = { label = "Directeur de l'Image", salary = 540 }
            [3] = { label = "Responsable de service", salary = 690 }
            [4] = { label = "Directeur de service", salary = 840 }
        }
    },
    -- 36. Agent d'Entretien & Propreté
    {
        name = "cleaner",
        label = "Agent d'Entretien & Nettoyage Urbain",
        category = "public_service",
        icon = "fas fa-broom",
        description = "Désinfection, nettoyage des locaux publics et maintenance des zones urbaines.",
        whitelisted = false,
        grades = {
            [0] = { label = "Agent de Nettoyage", salary = 200 },
            [1] = { label = "Technicien de Surface", salary = 320 },
            [2] = { label = "Chef d'Équipe Propreté", salary = 480 }
            [3] = { label = "Responsable de service", salary = 630 }
            [4] = { label = "Directeur de service", salary = 780 }
        }
    },
    -- 37. Facteur / Agent Postal
    {
        name = "postman",
        label = "Facteur Postal (Post OP)",
        category = "transport",
        icon = "fas fa-envelope-open-text",
        description = "Distribution quotidienne des courriers recommandés et correspondances postales.",
        whitelisted = false,
        grades = {
            [0] = { label = "Facteur Remplaçant", salary = 200 },
            [1] = { label = "Facteur Titulaire", salary = 340 },
            [2] = { label = "Chef de Centre Postal", salary = 510 }
            [3] = { label = "Responsable de service", salary = 660 }
            [4] = { label = "Directeur de service", salary = 810 }
        }
    },
    -- 38. Plongeur Sous-Marin / Récupérateur
    {
        name = "diver",
        label = "Plongeur Sous-Marin & Scaphandrier",
        category = "industrie",
        icon = "fas fa-water",
        description = "Exploration sous-marine, récupération de cargaisons immergées et travaux portuaires.",
        whitelisted = false,
        grades = {
            [0] = { label = "Plongeur Niveau 1", salary = 220 },
            [1] = { label = "Scaphandrier Travaux", salary = 400 },
            [2] = { label = "Chef d'Expédition Sous-Marine", salary = 640 }
            [3] = { label = "Responsable de service", salary = 790 }
            [4] = { label = "Directeur de service", salary = 940 }
        }
    },
    -- 39. Chauffeur de Bus Urbain
    {
        name = "bus_driver",
        label = "Chauffeur de Bus Urbain Los Santos Transit",
        category = "transport",
        icon = "fas fa-bus",
        description = "Dessertes régulières des arrêts de bus de toute la conurbation de San Andreas.",
        whitelisted = false,
        grades = {
            [0] = { label = "Conducteur Ligne Standard", salary = 210 },
            [1] = { label = "Conducteur Ligne Express", salary = 350 },
            [2] = { label = "Régulateur de Réseau LST", salary = 530 }
            [3] = { label = "Responsable de service", salary = 680 }
            [4] = { label = "Directeur de service", salary = 830 }
        }
    },
    -- 40. Vigneron / Sommelier
    {
        name = "winemaker",
        label = "Vigneron / Sommelier (Marlowe Vineyards)",
        category = "artisanat",
        icon = "fas fa-wine-bottle",
        description = "Vendanges, vinification, élevage en fûts de chêne et dégustation de grands crus.",
        whitelisted = false,
        grades = {
            [0] = { label = "Vendangeur Ouvrier", salary = 200 },
            [1] = { label = "Maître de Chai", salary = 370 },
            [2] = { label = "Propriétaire Récoltant", salary = 600 }
            [3] = { label = "Responsable de service", salary = 750 }
            [4] = { label = "Directeur de service", salary = 900 }
        }
    },
    -- 41. Coursier à Vélo
    {
        name = "bike_courier",
        label = "Coursier Écologique à Vélo",
        category = "transport",
        icon = "fas fa-bicycle",
        description = "Courses urgentes express à travers les embouteillages du centre-ville de LS.",
        whitelisted = false,
        grades = {
            [0] = { label = "Coursier Vélo", salary = 190 },
            [1] = { label = "Sprinter Urbain", salary = 320 },
            [2] = { label = "Responsable Dispatch Vélo", salary = 470 }
            [3] = { label = "Responsable de service", salary = 620 }
            [4] = { label = "Directeur de service", salary = 770 }
        }
    },
    -- 42. Soudeur Industriel
    {
        name = "welder",
        label = "Soudeur Industriel Chantier Naval",
        category = "industrie",
        icon = "fas fa-fire",
        description = "Assemblage métallique de structures lourdes, coques navales et tuyauteries de raffinerie.",
        whitelisted = false,
        grades = {
            [0] = { label = "Apprenti Soudeur", salary = 220 },
            [1] = { label = "Soudeur TIG / MIG", salary = 390 },
            [2] = { label = "Inspecteur Soudage Qualité", salary = 600 }
            [3] = { label = "Responsable de service", salary = 750 }
            [4] = { label = "Directeur de service", salary = 900 }
        }
    },
    -- 43. Capitaine de Bateau de Plaisance
    {
        name = "boat_captain",
        label = "Capitaine de Bateau de Plaisance",
        category = "transport",
        icon = "fas fa-ship",
        description = "Excursions maritimes côtières, location de yachts et traversées touristiques.",
        whitelisted = false,
        grades = {
            [0] = { label = "Skipper Côtier", salary = 230 },
            [1] = { label = "Capitaine 200 Voile/Moteur", salary = 420 },
            [2] = { label = "Commandant Yacht de Luxe", salary = 720 }
            [3] = { label = "Responsable de service", salary = 870 }
            [4] = { label = "Directeur de service", salary = 1020 }
        }
    },
    -- 44. Docker Portuaire
    {
        name = "dock_worker",
        label = "Docker Portuaire Los Santos Port",
        category = "industrie",
        icon = "fas fa-anchor",
        description = "Déchargement des porte-conteneurs, manutention lourde et grutier portuaire.",
        whitelisted = false,
        grades = {
            [0] = { label = "Manutentionnaire Docker", salary = 220 },
            [1] = { label = "Opérateur Portique Grue", salary = 380 },
            [2] = { label = "Chef de Quai Portuaire", salary = 570 }
            [3] = { label = "Responsable de service", salary = 720 }
            [4] = { label = "Directeur de service", salary = 870 }
        }
    },
    -- 45. Croupier de Casino
    {
        name = "casino_dealer",
        label = "Croupier Diamond Casino & Resort",
        category = "divertissement",
        icon = "fas fa-dice",
        description = "Animation des tables de roulette, blackjack, poker et échange de jetons.",
        whitelisted = false,
        grades = {
            [0] = { label = "Croupier Apprenti", salary = 220 },
            [1] = { label = "Croupier Hautes Mises", salary = 410 },
            [2] = { label = "Chef de Table / Pit Boss", salary = 680 }
            [3] = { label = "Responsable de service", salary = 830 }
            [4] = { label = "Directeur de service", salary = 980 }
        }
    },
    -- 46. Coach Sportif
    {
        name = "fitness_coach",
        label = "Coach Sportif & Préparateur Physique",
        category = "services",
        icon = "fas fa-dumbbell",
        description = "Entraînements personnalisés à Muscle Sands Beach, nutrition et remises en forme.",
        whitelisted = false,
        grades = {
            [0] = { label = "Moniteur de Gym", salary = 200 },
            [1] = { label = "Coach Personnel Diplômé", salary = 360 },
            [2] = { label = "Directeur de Complexe Fitness", salary = 560 }
            [3] = { label = "Responsable de service", salary = 710 }
            [4] = { label = "Directeur de service", salary = 860 }
        }
    },
    -- 47. Projectionniste de Cinéma
    {
        name = "cinema_operator",
        label = "Opérateur & Projectionniste Cinéma Vinewood",
        category = "divertissement",
        icon = "fas fa-film",
        description = "Diffusion des avant-premières de Vinewood, gestion des salles et billetterie.",
        whitelisted = false,
        grades = {
            [0] = { label = "Opérateur Cabine", salary = 200 },
            [1] = { label = "Technicien Son & Projection", salary = 340 },
            [2] = { label = "Directeur du Cinéma Tivoli", salary = 520 }
            [3] = { label = "Responsable de service", salary = 670 }
            [4] = { label = "Directeur de service", salary = 820 }
        }
    },
    -- 48. Fleuriste
    {
        name = "florist",
        label = "Artisan Fleuriste & Paysagiste",
        category = "artisanat",
        icon = "fas fa-spa",
        description = "Compositions florales d'exception, entretien des jardins et décorations végétales.",
        whitelisted = false,
        grades = {
            [0] = { label = "Aide Fleuriste", salary = 200 },
            [1] = { label = "Fleuriste Bouquetier", salary = 340 },
            [2] = { label = "Maître Artisan Paysagiste", salary = 530 }
            [3] = { label = "Responsable de service", salary = 680 }
            [4] = { label = "Directeur de service", salary = 830 }
        }
    },
    -- 49. Garde-Chasse / Ranger
    {
        name = "ranger",
        label = "Garde-Chasse & Ranger (Parc National)",
        category = "public_service",
        icon = "fas fa-binoculars",
        description = "Protection de la faune et de la flore au Mont Chiliad, lutte contre le braconnage.",
        whitelisted = false,
        grades = {
            [0] = { label = "Ranger Stagiaire", salary = 230 },
            [1] = { label = "Ranger Titulaire", salary = 390 },
            [2] = { label = "Chef Ranger de Réserve", salary = 610 }
            [3] = { label = "Responsable de service", salary = 760 }
            [4] = { label = "Directeur de service", salary = 910 }
        }
    },
    -- 50. Contrebandier / Marché Noir
    {
        name = "smuggler",
        label = "Contrebandier / Marché Noir (Underground)",
        category = "illegal",
        icon = "fas fa-mask",
        description = "Réseaux d'importations occultes, approvisionnement clandestin et receleur.",
        whitelisted = false,
        grades = {
            [0] = { label = "Guetteur des Ruelles", salary = 180 },
            [1] = { label = "Passeur Clandestin", salary = 350 },
            [2] = { label = "Parrain des Quais", salary = 600 }
            [3] = { label = "Responsable de service", salary = 750 }
            [4] = { label = "Directeur de service", salary = 900 }
        }
    }
}

-- Sans-emploi (Job de secours par défaut)
DefaultJob = {
    name = "unemployed",
    label = "Sans-emploi",
    category = "civilian",
    whitelisted = false,
    grades = {
        [0] = { label = "Demandeur d'Emploi", salary = 150 }
    }
}
