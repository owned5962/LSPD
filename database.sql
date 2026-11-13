-- GTA 5 Roleplay schema (MySQL 8 / MariaDB compatible)
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(64) NOT NULL UNIQUE,
    `license` VARCHAR(64) DEFAULT NULL,
    `discord` VARCHAR(64) DEFAULT NULL,
    `name` VARCHAR(64) NOT NULL,
    `group` VARCHAR(32) NOT NULL DEFAULT 'user',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `characters` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(64) NOT NULL,
    `char_id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `firstname` VARCHAR(32) NOT NULL,
    `lastname` VARCHAR(32) NOT NULL,
    `dateofbirth` DATE NOT NULL,
    `sex` CHAR(1) NOT NULL DEFAULT 'm',
    `height` SMALLINT UNSIGNED NOT NULL DEFAULT 175,
    `phone_number` VARCHAR(16) DEFAULT NULL,
    `cash` BIGINT NOT NULL DEFAULT 2500,
    `bank` BIGINT NOT NULL DEFAULT 10000,
    `job` VARCHAR(50) NOT NULL DEFAULT 'unemployed',
    `job_grade` INT NOT NULL DEFAULT 0,
    `position` LONGTEXT DEFAULT NULL,
    `skin` LONGTEXT DEFAULT NULL,
    `metadata` LONGTEXT DEFAULT NULL,
    `is_dead` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_user_char` (`identifier`, `char_id`),
    CONSTRAINT `fk_characters_users` FOREIGN KEY (`identifier`) REFERENCES `users` (`identifier`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Migrations intégrées : ce fichier peut aussi compléter une base existante.
-- 001_character_persistence : convertit les dates valides de VARCHAR vers DATE si nécessaire.
SET @rp_dateofbirth_type = (
    SELECT DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'characters'
      AND COLUMN_NAME = 'dateofbirth'
    LIMIT 1
);
SET @rp_dateofbirth_sql = IF(
    @rp_dateofbirth_type IS NOT NULL AND @rp_dateofbirth_type <> 'date',
    'ALTER TABLE `characters` MODIFY COLUMN `dateofbirth` DATE NOT NULL',
    'SELECT 1'
);
PREPARE rp_dateofbirth_stmt FROM @rp_dateofbirth_sql;
EXECUTE rp_dateofbirth_stmt;
DEALLOCATE PREPARE rp_dateofbirth_stmt;

-- 004_character_metadata : ajoute la colonne uniquement si elle manque.
SET @rp_metadata_exists = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'characters'
      AND COLUMN_NAME = 'metadata'
);
SET @rp_metadata_sql = IF(
    @rp_metadata_exists = 0,
    'ALTER TABLE `characters` ADD COLUMN `metadata` LONGTEXT DEFAULT NULL',
    'SELECT 1'
);
PREPARE rp_metadata_stmt FROM @rp_metadata_sql;
EXECUTE rp_metadata_stmt;
DEALLOCATE PREPARE rp_metadata_stmt;

-- Politique des armes : 1 = autorisée, 0 = interdite.
-- Le catalogue complet est inséré automatiquement par rp_anticheat au premier démarrage.
CREATE TABLE IF NOT EXISTS `anticheat_weapon_rules` (
    `weapon_name` VARCHAR(80) NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`weapon_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Registre central des points d'intérêt de la carte (alimenté au démarrage par rp_businesses).
-- Les coordonnées et réglages peuvent ensuite être modifiés directement en base.
CREATE TABLE IF NOT EXISTS `rp_world_locations` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `location_key` VARCHAR(100) NOT NULL,
    `location_type` ENUM('atm','bank','shop','gas_station') NOT NULL,
    `name` VARCHAR(120) NOT NULL,
    `shop_style` VARCHAR(60) DEFAULT NULL,
    `icon` VARCHAR(60) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `blip_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `blip_sprite` INT NOT NULL DEFAULT 1,
    `blip_display` INT NOT NULL DEFAULT 4,
    `blip_scale` DECIMAL(4,2) NOT NULL DEFAULT 0.70,
    `blip_colour` INT NOT NULL DEFAULT 0,
    `short_range` TINYINT(1) NOT NULL DEFAULT 1,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rp_world_locations_key` (`location_key`),
    KEY `idx_rp_world_locations_type` (`location_type`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bank_transactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `character_id` INT NOT NULL,
    `type` ENUM('deposit', 'withdraw', 'transfer_send', 'transfer_receive', 'salary') NOT NULL,
    `amount` BIGINT NOT NULL,
    `sender_or_receiver` VARCHAR(128) DEFAULT NULL,
    `reason` VARCHAR(255) DEFAULT 'Transaction',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_bank_characters` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jobs` (
    `name` VARCHAR(50) PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) NOT NULL DEFAULT 'civilian',
    `whitelisted` TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `job_grades` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `salary` INT NOT NULL DEFAULT 200,
    UNIQUE KEY `unique_job_grade` (`job_name`, `grade`),
    CONSTRAINT `fk_job_grades_jobs` FOREIGN KEY (`job_name`) REFERENCES `jobs` (`name`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Catalogue initial des métiers et de leurs grades.
-- INSERT IGNORE rend cette initialisation réexécutable sans écraser les salaires personnalisés.
START TRANSACTION;

INSERT IGNORE INTO `jobs` (`name`, `label`, `category`, `whitelisted`) VALUES
('police', 'Policier (LSPD)', 'public_service', 1),
('ambulance', 'Médecin / Secouriste (EMS)', 'public_service', 1),
('firefighter', 'Sapeur-Pompier', 'public_service', 1),
('lawyer', 'Avocat de la Défense', 'justice', 0),
('judge', 'Juge / Magistrat', 'justice', 1),
('mechanic', 'Mécanicien Benny''s / LSC', 'artisanat', 0),
('taxi', 'Chauffeur de Taxi Downtown Cab', 'transport', 0),
('realestate', 'Agent Immobilier Century', 'commerce', 0),
('journalist', 'Journaliste Weazel News', 'media', 0),
('miner', 'Mineur d''Extraction', 'industrie', 0),
('lumberjack', 'Bûcheron Forestier', 'industrie', 0),
('delivery', 'Livreur GoPostal Express', 'transport', 0),
('banker', 'Banquier / Gestionnaire Financier', 'finance', 1),
('garbage', 'Agent de Collecte des Déchets (Éboueur)', 'public_service', 0),
('fisherman', 'Pêcheur Professionnel', 'artisanat', 0),
('farmer', 'Agriculteur / Maraîcher', 'artisanat', 0),
('butcher', 'Artisan Boucher', 'artisanat', 0),
('brewer', 'Brasseur Artisanal', 'artisanat', 0),
('security', 'Agent de Sécurité Privée (Gruppe 6)', 'public_service', 0),
('pilot', 'Pilote de Ligne Commercial', 'transport', 1),
('train_driver', 'Conducteur de Train & Métro', 'transport', 0),
('chef', 'Chef Cuisinier / Restaurateur', 'restauration', 0),
('bartender', 'Barman / Mixologue (Vanilla Unicorn / Tequi-la-la)', 'restauration', 0),
('towtruck', 'Dépanneur / Remorqueur Autoroutier', 'transport', 0),
('cardealer', 'Concessionnaire Automobile PDM', 'commerce', 0),
('electrician', 'Électricien Haute Tension', 'artisanat', 0),
('plumber', 'Plombier / Chauffagiste', 'artisanat', 0),
('it_tech', 'Technicien Informatique & Cyber', 'technologie', 0),
('armorer', 'Armurier Agréé Ammu-Nation', 'commerce', 1),
('tailor', 'Couturier & Designer de Mode', 'artisanat', 0),
('pharmacist', 'Pharmacien / Préparateur Officine', 'sante', 0),
('architect', 'Architecte & Urbaniste', 'services', 0),
('veterinarian', 'Médecin Vétérinaire', 'sante', 0),
('event_planner', 'Organisateur d''Événements & DJ', 'divertissement', 0),
('photographer', 'Photographe de Presse & Studio', 'media', 0),
('cleaner', 'Agent d''Entretien & Nettoyage Urbain', 'public_service', 0),
('postman', 'Facteur Postal (Post OP)', 'transport', 0),
('diver', 'Plongeur Sous-Marin & Scaphandrier', 'industrie', 0),
('bus_driver', 'Chauffeur de Bus Urbain Los Santos Transit', 'transport', 0),
('winemaker', 'Vigneron / Sommelier (Marlowe Vineyards)', 'artisanat', 0),
('bike_courier', 'Coursier Écologique à Vélo', 'transport', 0),
('welder', 'Soudeur Industriel Chantier Naval', 'industrie', 0),
('boat_captain', 'Capitaine de Bateau de Plaisance', 'transport', 0),
('dock_worker', 'Docker Portuaire Los Santos Port', 'industrie', 0),
('casino_dealer', 'Croupier Diamond Casino & Resort', 'divertissement', 0),
('fitness_coach', 'Coach Sportif & Préparateur Physique', 'services', 0),
('cinema_operator', 'Opérateur & Projectionniste Cinéma Vinewood', 'divertissement', 0),
('florist', 'Artisan Fleuriste & Paysagiste', 'artisanat', 0),
('ranger', 'Garde-Chasse & Ranger (Parc National)', 'public_service', 0),
('smuggler', 'Contrebandier / Marché Noir (Underground)', 'illegal', 0),
('unemployed', 'Sans-emploi', 'civilian', 0);

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`) VALUES
('police', 0, 'grade_0', 'Cadet', 250),
('police', 1, 'grade_1', 'Officier', 400),
('police', 2, 'grade_2', 'Sergent', 600),
('police', 3, 'grade_3', 'Lieutenant', 850),
('police', 4, 'grade_4', 'Capitaine', 1100),
('ambulance', 0, 'grade_0', 'Ambulancier stagiaire', 250),
('ambulance', 1, 'grade_1', 'Secouriste qualifié', 400),
('ambulance', 2, 'grade_2', 'Médecin urgentiste', 650),
('ambulance', 3, 'grade_3', 'Chirurgien en chef', 950),
('ambulance', 4, 'grade_4', 'Directeur de service', 1250),
('firefighter', 0, 'grade_0', 'Sapeur 2e classe', 260),
('firefighter', 1, 'grade_1', 'Caporal', 380),
('firefighter', 2, 'grade_2', 'Sergent', 550),
('firefighter', 3, 'grade_3', 'Adjudant-Chef', 800),
('firefighter', 4, 'grade_4', 'Directeur de service', 1100),
('lawyer', 0, 'grade_0', 'Stagiaire au Barreau', 220),
('lawyer', 1, 'grade_1', 'Avocat Associé', 500),
('lawyer', 2, 'grade_2', 'Bâtonnier', 900),
('lawyer', 3, 'grade_3', 'Responsable de service', 1050),
('lawyer', 4, 'grade_4', 'Directeur de service', 1200),
('judge', 0, 'grade_0', 'Juge Assesseur', 600),
('judge', 1, 'grade_1', 'Juge d''Instruction', 850),
('judge', 2, 'grade_2', 'Président du Tribunal', 1200),
('judge', 3, 'grade_3', 'Responsable de service', 1350),
('judge', 4, 'grade_4', 'Directeur de service', 1500),
('mechanic', 0, 'grade_0', 'Apprenti Garage', 220),
('mechanic', 1, 'grade_1', 'Mécanicien Certifié', 420),
('mechanic', 2, 'grade_2', 'Chef d''Atelier', 700),
('mechanic', 3, 'grade_3', 'Responsable de service', 850),
('mechanic', 4, 'grade_4', 'Directeur de service', 1000),
('taxi', 0, 'grade_0', 'Chauffeur Débutant', 200),
('taxi', 1, 'grade_1', 'Chauffeur Expérimenté', 360),
('taxi', 2, 'grade_2', 'Responsable de Flotte', 550),
('taxi', 3, 'grade_3', 'Responsable de service', 700),
('taxi', 4, 'grade_4', 'Directeur de service', 850),
('realestate', 0, 'grade_0', 'Négociateur Junior', 220),
('realestate', 1, 'grade_1', 'Agent Senior', 450),
('realestate', 2, 'grade_2', 'Directeur d''Agence', 800),
('realestate', 3, 'grade_3', 'Responsable de service', 950),
('realestate', 4, 'grade_4', 'Directeur de service', 1100),
('journalist', 0, 'grade_0', 'Pigiste', 200),
('journalist', 1, 'grade_1', 'Grand Reporter', 380),
('journalist', 2, 'grade_2', 'Rédacteur en Chef', 680),
('journalist', 3, 'grade_3', 'Responsable de service', 830),
('journalist', 4, 'grade_4', 'Directeur de service', 980),
('miner', 0, 'grade_0', 'Mineur Débutant', 210),
('miner', 1, 'grade_1', 'Foreur Qualifié', 350),
('miner', 2, 'grade_2', 'Contremaître Mine', 520),
('miner', 3, 'grade_3', 'Responsable de service', 670),
('miner', 4, 'grade_4', 'Directeur de service', 820),
('lumberjack', 0, 'grade_0', 'Bûcheron Élaguer', 210),
('lumberjack', 1, 'grade_1', 'Scieur Industriel', 360),
('lumberjack', 2, 'grade_2', 'Chef d''Exploitation', 540),
('lumberjack', 3, 'grade_3', 'Responsable de service', 690),
('lumberjack', 4, 'grade_4', 'Directeur de service', 840),
('delivery', 0, 'grade_0', 'Coursier Urbain', 200),
('delivery', 1, 'grade_1', 'Livreur Longue Distance', 340),
('delivery', 2, 'grade_2', 'Dispatcheur Logistique', 500),
('delivery', 3, 'grade_3', 'Responsable de service', 650),
('delivery', 4, 'grade_4', 'Directeur de service', 800),
('banker', 0, 'grade_0', 'Conseiller Clientèle', 300),
('banker', 1, 'grade_1', 'Chargé d''Affaires Pro', 550),
('banker', 2, 'grade_2', 'Directeur d''Agence', 950),
('banker', 3, 'grade_3', 'Responsable de service', 1100),
('banker', 4, 'grade_4', 'Directeur de service', 1250),
('garbage', 0, 'grade_0', 'Ripeur Débutant', 220),
('garbage', 1, 'grade_1', 'Conducteur de Benne', 350),
('garbage', 2, 'grade_2', 'Responsable de Secteur', 500),
('garbage', 3, 'grade_3', 'Responsable de service', 650),
('garbage', 4, 'grade_4', 'Directeur de service', 800),
('fisherman', 0, 'grade_0', 'Matelot de Pêche', 210),
('fisherman', 1, 'grade_1', 'Pêcheur Hauturier', 360),
('fisherman', 2, 'grade_2', 'Patron Pêcheur', 550),
('fisherman', 3, 'grade_3', 'Responsable de service', 700),
('fisherman', 4, 'grade_4', 'Directeur de service', 850),
('farmer', 0, 'grade_0', 'Ouvrier Agricole', 210),
('farmer', 1, 'grade_1', 'Exploitant Agricole', 380),
('farmer', 2, 'grade_2', 'Propriétaire de Ranch', 600),
('farmer', 3, 'grade_3', 'Responsable de service', 750),
('farmer', 4, 'grade_4', 'Directeur de service', 900),
('butcher', 0, 'grade_0', 'Apprenti Découpe', 200),
('butcher', 1, 'grade_1', 'Boucher Traiteur', 360),
('butcher', 2, 'grade_2', 'Maître Artisan', 540),
('butcher', 3, 'grade_3', 'Responsable de service', 690),
('butcher', 4, 'grade_4', 'Directeur de service', 840),
('brewer', 0, 'grade_0', 'Aide Cuve', 200),
('brewer', 1, 'grade_1', 'Maître Brasseur', 370),
('brewer', 2, 'grade_2', 'Directeur de Brasserie', 560),
('brewer', 3, 'grade_3', 'Responsable de service', 710),
('brewer', 4, 'grade_4', 'Directeur de service', 860),
('security', 0, 'grade_0', 'Vigile Rondier', 230),
('security', 1, 'grade_1', 'Convoyeur de Fonds', 400),
('security', 2, 'grade_2', 'Chef de Poste', 620),
('security', 3, 'grade_3', 'Responsable de service', 770),
('security', 4, 'grade_4', 'Directeur de service', 920),
('pilot', 0, 'grade_0', 'Copilote', 350),
('pilot', 1, 'grade_1', 'Commandant de Bord', 650),
('pilot', 2, 'grade_2', 'Instructeur Aéronautique', 1000),
('pilot', 3, 'grade_3', 'Responsable de service', 1150),
('pilot', 4, 'grade_4', 'Directeur de service', 1300),
('train_driver', 0, 'grade_0', 'Aspirant Conducteur', 220),
('train_driver', 1, 'grade_1', 'Conducteur Titulaire', 380),
('train_driver', 2, 'grade_2', 'Régulateur de Ligne', 580),
('train_driver', 3, 'grade_3', 'Responsable de service', 730),
('train_driver', 4, 'grade_4', 'Directeur de service', 880),
('chef', 0, 'grade_0', 'Commis de Cuisine', 210),
('chef', 1, 'grade_1', 'Chef de Partie', 380),
('chef', 2, 'grade_2', 'Chef Étoilé', 650),
('chef', 3, 'grade_3', 'Responsable de service', 800),
('chef', 4, 'grade_4', 'Directeur de service', 950),
('bartender', 0, 'grade_0', 'Barman Débutant', 200),
('bartender', 1, 'grade_1', 'Mixologue Confirmé', 350),
('bartender', 2, 'grade_2', 'Gérant de Bar', 550),
('bartender', 3, 'grade_3', 'Responsable de service', 700),
('bartender', 4, 'grade_4', 'Directeur de service', 850),
('towtruck', 0, 'grade_0', 'Opérateur Plateau', 220),
('towtruck', 1, 'grade_1', 'Dépanneur Treuil', 370),
('towtruck', 2, 'grade_2', 'Superviseur Fourrière', 560),
('towtruck', 3, 'grade_3', 'Responsable de service', 710),
('towtruck', 4, 'grade_4', 'Directeur de service', 860),
('cardealer', 0, 'grade_0', 'Commercial Junior', 220),
('cardealer', 1, 'grade_1', 'Conseiller Vente Élite', 420),
('cardealer', 2, 'grade_2', 'Directeur de Concession', 750),
('cardealer', 3, 'grade_3', 'Responsable de service', 900),
('cardealer', 4, 'grade_4', 'Directeur de service', 1050),
('electrician', 0, 'grade_0', 'Monteur Électricien', 220),
('electrician', 1, 'grade_1', 'Technicien Réseau', 380),
('electrician', 2, 'grade_2', 'Expert Réseau Haute Tension', 580),
('electrician', 3, 'grade_3', 'Responsable de service', 730),
('electrician', 4, 'grade_4', 'Directeur de service', 880),
('plumber', 0, 'grade_0', 'Aide Plombier', 210),
('plumber', 1, 'grade_1', 'Plombier Sanitaire', 360),
('plumber', 2, 'grade_2', 'Chef de Chantier Fluides', 540),
('plumber', 3, 'grade_3', 'Responsable de service', 690),
('plumber', 4, 'grade_4', 'Directeur de service', 840),
('it_tech', 0, 'grade_0', 'Support Helpdesk', 230),
('it_tech', 1, 'grade_1', 'Administrateur Système', 420),
('it_tech', 2, 'grade_2', 'Ingénieur Sécurité IT', 720),
('it_tech', 3, 'grade_3', 'Responsable de service', 870),
('it_tech', 4, 'grade_4', 'Directeur de service', 1020),
('armorer', 0, 'grade_0', 'Vendeur Stand de Tir', 240),
('armorer', 1, 'grade_1', 'Armurier Certifié', 450),
('armorer', 2, 'grade_2', 'Maître Canonnier', 780),
('armorer', 3, 'grade_3', 'Responsable de service', 930),
('armorer', 4, 'grade_4', 'Directeur de service', 1080),
('tailor', 0, 'grade_0', 'Apprenti Couturier', 200),
('tailor', 1, 'grade_1', 'Tailleur Styliste', 360),
('tailor', 2, 'grade_2', 'Créateur de Mode', 580),
('tailor', 3, 'grade_3', 'Responsable de service', 730),
('tailor', 4, 'grade_4', 'Directeur de service', 880),
('pharmacist', 0, 'grade_0', 'Préparateur en Pharmacie', 220),
('pharmacist', 1, 'grade_1', 'Docteur en Pharmacie', 440),
('pharmacist', 2, 'grade_2', 'Titulaire d''Officine', 700),
('pharmacist', 3, 'grade_3', 'Responsable de service', 850),
('pharmacist', 4, 'grade_4', 'Directeur de service', 1000),
('architect', 0, 'grade_0', 'Dessinateur Projeteur', 230),
('architect', 1, 'grade_1', 'Architecte DPLG', 460),
('architect', 2, 'grade_2', 'Directeur de Projet', 780),
('architect', 3, 'grade_3', 'Responsable de service', 930),
('architect', 4, 'grade_4', 'Directeur de service', 1080),
('veterinarian', 0, 'grade_0', 'Assistant Vétérinaire', 210),
('veterinarian', 1, 'grade_1', 'Praticien Vétérinaire', 400),
('veterinarian', 2, 'grade_2', 'Directeur Clinique Vétérinaire', 680),
('veterinarian', 3, 'grade_3', 'Responsable de service', 830),
('veterinarian', 4, 'grade_4', 'Directeur de service', 980),
('event_planner', 0, 'grade_0', 'Assistant Logistique Événements', 210),
('event_planner', 1, 'grade_1', 'Coordinateur Fêtes & Galas', 390),
('event_planner', 2, 'grade_2', 'Producteur Événementiel', 650),
('event_planner', 3, 'grade_3', 'Responsable de service', 800),
('event_planner', 4, 'grade_4', 'Directeur de service', 950),
('photographer', 0, 'grade_0', 'Photographe Indépendant', 200),
('photographer', 1, 'grade_1', 'Photographe Senior', 360),
('photographer', 2, 'grade_2', 'Directeur de l''Image', 540),
('photographer', 3, 'grade_3', 'Responsable de service', 690),
('photographer', 4, 'grade_4', 'Directeur de service', 840),
('cleaner', 0, 'grade_0', 'Agent de Nettoyage', 200),
('cleaner', 1, 'grade_1', 'Technicien de Surface', 320),
('cleaner', 2, 'grade_2', 'Chef d''Équipe Propreté', 480),
('cleaner', 3, 'grade_3', 'Responsable de service', 630),
('cleaner', 4, 'grade_4', 'Directeur de service', 780),
('postman', 0, 'grade_0', 'Facteur Remplaçant', 200),
('postman', 1, 'grade_1', 'Facteur Titulaire', 340),
('postman', 2, 'grade_2', 'Chef de Centre Postal', 510),
('postman', 3, 'grade_3', 'Responsable de service', 660),
('postman', 4, 'grade_4', 'Directeur de service', 810),
('diver', 0, 'grade_0', 'Plongeur Niveau 1', 220),
('diver', 1, 'grade_1', 'Scaphandrier Travaux', 400),
('diver', 2, 'grade_2', 'Chef d''Expédition Sous-Marine', 640),
('diver', 3, 'grade_3', 'Responsable de service', 790),
('diver', 4, 'grade_4', 'Directeur de service', 940),
('bus_driver', 0, 'grade_0', 'Conducteur Ligne Standard', 210),
('bus_driver', 1, 'grade_1', 'Conducteur Ligne Express', 350),
('bus_driver', 2, 'grade_2', 'Régulateur de Réseau LST', 530),
('bus_driver', 3, 'grade_3', 'Responsable de service', 680),
('bus_driver', 4, 'grade_4', 'Directeur de service', 830),
('winemaker', 0, 'grade_0', 'Vendangeur Ouvrier', 200),
('winemaker', 1, 'grade_1', 'Maître de Chai', 370),
('winemaker', 2, 'grade_2', 'Propriétaire Récoltant', 600),
('winemaker', 3, 'grade_3', 'Responsable de service', 750),
('winemaker', 4, 'grade_4', 'Directeur de service', 900),
('bike_courier', 0, 'grade_0', 'Coursier Vélo', 190),
('bike_courier', 1, 'grade_1', 'Sprinter Urbain', 320),
('bike_courier', 2, 'grade_2', 'Responsable Dispatch Vélo', 470),
('bike_courier', 3, 'grade_3', 'Responsable de service', 620),
('bike_courier', 4, 'grade_4', 'Directeur de service', 770),
('welder', 0, 'grade_0', 'Apprenti Soudeur', 220),
('welder', 1, 'grade_1', 'Soudeur TIG / MIG', 390),
('welder', 2, 'grade_2', 'Inspecteur Soudage Qualité', 600),
('welder', 3, 'grade_3', 'Responsable de service', 750),
('welder', 4, 'grade_4', 'Directeur de service', 900),
('boat_captain', 0, 'grade_0', 'Skipper Côtier', 230),
('boat_captain', 1, 'grade_1', 'Capitaine 200 Voile/Moteur', 420),
('boat_captain', 2, 'grade_2', 'Commandant Yacht de Luxe', 720),
('boat_captain', 3, 'grade_3', 'Responsable de service', 870),
('boat_captain', 4, 'grade_4', 'Directeur de service', 1020),
('dock_worker', 0, 'grade_0', 'Manutentionnaire Docker', 220),
('dock_worker', 1, 'grade_1', 'Opérateur Portique Grue', 380),
('dock_worker', 2, 'grade_2', 'Chef de Quai Portuaire', 570),
('dock_worker', 3, 'grade_3', 'Responsable de service', 720),
('dock_worker', 4, 'grade_4', 'Directeur de service', 870),
('casino_dealer', 0, 'grade_0', 'Croupier Apprenti', 220),
('casino_dealer', 1, 'grade_1', 'Croupier Hautes Mises', 410),
('casino_dealer', 2, 'grade_2', 'Chef de Table / Pit Boss', 680),
('casino_dealer', 3, 'grade_3', 'Responsable de service', 830),
('casino_dealer', 4, 'grade_4', 'Directeur de service', 980),
('fitness_coach', 0, 'grade_0', 'Moniteur de Gym', 200),
('fitness_coach', 1, 'grade_1', 'Coach Personnel Diplômé', 360),
('fitness_coach', 2, 'grade_2', 'Directeur de Complexe Fitness', 560),
('fitness_coach', 3, 'grade_3', 'Responsable de service', 710),
('fitness_coach', 4, 'grade_4', 'Directeur de service', 860),
('cinema_operator', 0, 'grade_0', 'Opérateur Cabine', 200),
('cinema_operator', 1, 'grade_1', 'Technicien Son & Projection', 340),
('cinema_operator', 2, 'grade_2', 'Directeur du Cinéma Tivoli', 520),
('cinema_operator', 3, 'grade_3', 'Responsable de service', 670),
('cinema_operator', 4, 'grade_4', 'Directeur de service', 820),
('florist', 0, 'grade_0', 'Aide Fleuriste', 200),
('florist', 1, 'grade_1', 'Fleuriste Bouquetier', 340),
('florist', 2, 'grade_2', 'Maître Artisan Paysagiste', 530),
('florist', 3, 'grade_3', 'Responsable de service', 680),
('florist', 4, 'grade_4', 'Directeur de service', 830),
('ranger', 0, 'grade_0', 'Ranger Stagiaire', 230),
('ranger', 1, 'grade_1', 'Ranger Titulaire', 390),
('ranger', 2, 'grade_2', 'Chef Ranger de Réserve', 610),
('ranger', 3, 'grade_3', 'Responsable de service', 760),
('ranger', 4, 'grade_4', 'Directeur de service', 910),
('smuggler', 0, 'grade_0', 'Guetteur des Ruelles', 180),
('smuggler', 1, 'grade_1', 'Passeur Clandestin', 350),
('smuggler', 2, 'grade_2', 'Parrain des Quais', 600),
('smuggler', 3, 'grade_3', 'Responsable de service', 750),
('smuggler', 4, 'grade_4', 'Directeur de service', 900),
('unemployed', 0, 'grade_0', 'Demandeur d''Emploi', 150);

COMMIT;



CREATE TABLE IF NOT EXISTS `admin_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `admin_identifier` VARCHAR(64) NOT NULL,
    `admin_name` VARCHAR(64) NOT NULL,
    `action` VARCHAR(64) NOT NULL,
    `target_identifier` VARCHAR(64) DEFAULT NULL,
    `details` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `items` (
    `name` VARCHAR(50) PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `weight` DECIMAL(10,2) NOT NULL DEFAULT 1.0,
    `rare` TINYINT(1) NOT NULL DEFAULT 0,
    `can_remove` TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
('bread', 'Pain', 0.5, 0, 1), ('water', 'Bouteille d\'eau', 0.5, 0, 1),
('medikit', 'Kit de secours', 1.0, 0, 1), ('bandage', 'Bandage', 0.2, 0, 1),
('repairkit', 'Kit de réparation', 3.0, 0, 1), ('handcuffs', 'Menottes de police', 0.8, 0, 1),
('phone', 'Téléphone portable', 0.2, 0, 1), ('id_card', 'Carte d\'identité', 0.1, 0, 0),
('driver_license', 'Permis de conduire', 0.1, 0, 0), ('radio', 'Talkie-walkie', 0.5, 0, 1);

CREATE TABLE IF NOT EXISTS `billing` (
    `id` INT AUTO_INCREMENT PRIMARY KEY, `identifier` VARCHAR(64) NOT NULL,
    `sender` VARCHAR(64) NOT NULL, `target_type` VARCHAR(50) NOT NULL DEFAULT 'player',
    `target` VARCHAR(64) NOT NULL, `label` VARCHAR(255) NOT NULL, `amount` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `user_outfits` (
    `id` INT AUTO_INCREMENT PRIMARY KEY, `identifier` VARCHAR(64) NOT NULL,
    `character_id` INT NOT NULL, `name` VARCHAR(50) NOT NULL, `skin_data` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX (`identifier`), INDEX (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `player_inventories` (
    `character_id` INT NOT NULL PRIMARY KEY,
    `items` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT `fk_inventory_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_inventory_drops` (
    `id` VARCHAR(64) NOT NULL PRIMARY KEY,
    `item_name` VARCHAR(80) NOT NULL,
    `count` INT UNSIGNED NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0,
    `routing_bucket` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_inventory_drops_bucket` (`routing_bucket`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Coffres partagés et armureries par métier. Les armes sont limitées par configuration et grade.
CREATE TABLE IF NOT EXISTS `rp_creator_job_storage` (
    `job` VARCHAR(64) NOT NULL PRIMARY KEY,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `stash_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `armory_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `armory_items` LONGTEXT NOT NULL,
    `updated_by` VARCHAR(80) NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rp_job_storage_items` (
    `job` VARCHAR(64) NOT NULL,
    `storage_type` ENUM('stash','armory') NOT NULL,
    `item_name` VARCHAR(64) NOT NULL,
    `count` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`job`, `storage_type`, `item_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rp_job_storage_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `job` VARCHAR(64) NOT NULL,
    `storage_type` VARCHAR(16) NOT NULL,
    `character_id` INT NOT NULL,
    `player_name` VARCHAR(128) NOT NULL,
    `direction` VARCHAR(16) NOT NULL,
    `item_name` VARCHAR(64) NOT NULL,
    `item_count` INT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_job_storage_logs_job_created` (`job`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `player_bans` (
    `identifier` VARCHAR(64) NOT NULL PRIMARY KEY,
    `reason` VARCHAR(255) NOT NULL,
    `banned_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- Auto-école : les permis sont attachés au personnage et à son identifiant de compte.
CREATE TABLE IF NOT EXISTS `rp_driving_licenses` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id` INT NOT NULL,
    `identifier` VARCHAR(64) NOT NULL,
    `category` ENUM('moto','voiture','avion','bateau','helicoptere') NOT NULL,
    `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rp_driving_license_character_category` (`character_id`, `category`),
    KEY `idx_rp_driving_license_identifier` (`identifier`),
    CONSTRAINT `fk_rp_driving_license_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- Signalements joueurs consultables depuis la tablette F10.
CREATE TABLE IF NOT EXISTS `player_reports` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_identifier` VARCHAR(80) NOT NULL,
  `player_name` VARCHAR(64) NOT NULL,
  `message` VARCHAR(500) NOT NULL,
  `status` ENUM('open','resolved','rejected') NOT NULL DEFAULT 'open',
  `handled_by` VARCHAR(64) DEFAULT NULL,
  `handled_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_reports_status_created` (`status`, `created_at`),
  KEY `idx_player_reports_identifier` (`player_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- Comptes bancaires partagés par métier et historique des dépôts/retraits.
CREATE TABLE IF NOT EXISTS `rp_job_bank_accounts` (
    `job` VARCHAR(64) NOT NULL PRIMARY KEY,
    `balance` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `allow_deposit` TINYINT(1) NOT NULL DEFAULT 1,
    `allow_withdraw` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rp_job_bank_transactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `job` VARCHAR(64) NOT NULL,
    `character_id` INT NOT NULL,
    `player_name` VARCHAR(128) NOT NULL,
    `transaction_type` ENUM('deposit','withdraw') NOT NULL,
    `amount` BIGINT UNSIGNED NOT NULL,
    `balance_after` BIGINT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_job_bank_history` (`job`, `id`),
    KEY `idx_job_bank_character` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
