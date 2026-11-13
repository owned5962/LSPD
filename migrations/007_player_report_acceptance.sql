-- Ajoute l'état « accepted » pour distinguer la prise en charge de la clôture d'un rapport.
ALTER TABLE `player_reports`
    MODIFY `status` ENUM('open','accepted','resolved','rejected') NOT NULL DEFAULT 'open';
