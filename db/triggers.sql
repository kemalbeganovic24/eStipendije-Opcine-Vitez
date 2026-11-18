
USE estipendija;
DELIMITER $$

CREATE TRIGGER trg_score_items_before_insert
    BEFORE INSERT ON score_items FOR EACH ROW
BEGIN
    DECLARE valid_count INT DEFAULT 0;
    SELECT COUNT(*) INTO valid_count
    FROM applications a JOIN criteria c ON c.id = NEW.criterion_id
    WHERE a.id = NEW.application_id
      AND a.competition_id = NEW.competition_id
      AND c.competition_id = a.competition_id
      AND (c.category_id IS NULL OR c.category_id = a.category_id)
      AND c.aktivan = TRUE
      AND NEW.automatski_bodovi BETWEEN 0 AND c.maksimalni_bodovi
      AND NEW.konacni_bodovi BETWEEN 0 AND c.maksimalni_bodovi;
    IF valid_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Neispravan kriterij, kategorija ili bodovi';
END IF;
END$$

CREATE TRIGGER trg_score_items_before_update
    BEFORE UPDATE ON score_items FOR EACH ROW
BEGIN
    DECLARE valid_count INT DEFAULT 0;
    SELECT COUNT(*) INTO valid_count
    FROM applications a JOIN criteria c ON c.id = NEW.criterion_id
    WHERE a.id = NEW.application_id
      AND a.competition_id = NEW.competition_id
      AND c.competition_id = a.competition_id
      AND (c.category_id IS NULL OR c.category_id = a.category_id)
      AND c.aktivan = TRUE
      AND NEW.automatski_bodovi BETWEEN 0 AND c.maksimalni_bodovi
      AND NEW.konacni_bodovi BETWEEN 0 AND c.maksimalni_bodovi;
    IF valid_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Neispravan kriterij, kategorija ili bodovi';
END IF;
END$$

CREATE TRIGGER trg_app_documents_before_insert
    BEFORE INSERT ON application_documents FOR EACH ROW
BEGIN
    DECLARE valid_count INT DEFAULT 0;
    SELECT COUNT(*) INTO valid_count
    FROM applications a JOIN required_documents rd ON rd.id = NEW.required_document_id
    WHERE a.id = NEW.application_id
      AND a.competition_id = NEW.competition_id
      AND rd.competition_id = a.competition_id
      AND (rd.category_id IS NULL OR rd.category_id = a.category_id)
      AND rd.aktivan = TRUE;
    IF valid_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Dokument nije dozvoljen za prijavu';
END IF;
END$$

CREATE TRIGGER trg_app_documents_before_update
    BEFORE UPDATE ON application_documents FOR EACH ROW
BEGIN
    DECLARE valid_count INT DEFAULT 0;
    SELECT COUNT(*) INTO valid_count
    FROM applications a JOIN required_documents rd ON rd.id = NEW.required_document_id
    WHERE a.id = NEW.application_id
      AND a.competition_id = NEW.competition_id
      AND rd.competition_id = a.competition_id
      AND (rd.category_id IS NULL OR rd.category_id = a.category_id);
    IF valid_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Dokument nije dozvoljen za prijavu';
END IF;
END$$

CREATE TRIGGER trg_payments_before_insert
    BEFORE INSERT ON payments FOR EACH ROW
BEGIN
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_broj_rata INT;
    DECLARE v_status VARCHAR(20);
    DECLARE v_suma DECIMAL(14,2) DEFAULT 0;
    SELECT ukupni_iznos, broj_rata, status
    INTO v_total, v_broj_rata, v_status
    FROM contracts WHERE id = NEW.contract_id FOR UPDATE;
    IF NEW.broj_rate > v_broj_rata THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Broj rate prelazi broj rata ugovora';
END IF;
IF NEW.status = 'ISPLACENA'
       AND v_status NOT IN ('POTPISAN', 'AKTIVAN') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ugovor nije spreman za isplatu';
END IF;
SELECT COALESCE(SUM(iznos),0) INTO v_suma
FROM payments WHERE contract_id = NEW.contract_id AND status <> 'OTKAZANA';
IF NEW.status <> 'OTKAZANA' AND v_suma + NEW.iznos > v_total THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ukupan iznos rata prelazi ugovor';
END IF;
END$$

CREATE TRIGGER trg_payments_before_update
    BEFORE UPDATE ON payments FOR EACH ROW
BEGIN
    DECLARE v_ukupni_iznos DECIMAL(12,2);
    DECLARE v_broj_rata INT;
    DECLARE v_status_ugovora VARCHAR(20);
    DECLARE v_suma DECIMAL(14,2) DEFAULT 0;
    IF OLD.status = 'ISPLACENA' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Izvrsena isplata se ne moze mijenjati';
END IF;
IF NEW.contract_id <> OLD.contract_id
       OR NEW.broj_rate <> OLD.broj_rate OR NEW.id <> OLD.id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Nije dozvoljena promjena identiteta rate';
END IF;
SELECT ukupni_iznos, broj_rata, status
INTO v_ukupni_iznos, v_broj_rata, v_status_ugovora
FROM contracts WHERE id = NEW.contract_id FOR UPDATE;
IF NEW.broj_rate > v_broj_rata THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Broj rate prelazi broj rata ugovora';
END IF;
    IF NEW.status = 'ISPLACENA'
       AND v_status_ugovora NOT IN ('POTPISAN','AKTIVAN') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ugovor nije spreman za isplatu';
END IF;
SELECT COALESCE(SUM(iznos),0) INTO v_suma
FROM payments
WHERE contract_id = NEW.contract_id AND id <> OLD.id AND status <> 'OTKAZANA';
IF NEW.status <> 'OTKAZANA'
       AND v_suma + NEW.iznos > v_ukupni_iznos THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ukupan iznos rata prelazi ugovor';
END IF;
END$$

CREATE TRIGGER trg_payments_before_delete
    BEFORE DELETE ON payments FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Brisanje isplata nije dozvoljeno';
END$$

    CREATE TRIGGER trg_contracts_before_update
        BEFORE UPDATE ON contracts FOR EACH ROW
    BEGIN
        DECLARE v_suma DECIMAL(14,2) DEFAULT 0;
    DECLARE v_najveca_rata INT DEFAULT 0;
    DECLARE v_broj_isplacenih INT DEFAULT 0;
    DECLARE v_broj_evidentiranih INT DEFAULT 0;
    IF NEW.id <> OLD.id OR NEW.application_id <> OLD.application_id
       OR NEW.created_by <> OLD.created_by THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Promjena identiteta ugovora nije dozvoljena';
    END IF;
    SELECT COUNT(*),
           COALESCE(SUM(CASE WHEN status <> 'OTKAZANA' THEN iznos ELSE 0 END),0),
           COALESCE(MAX(broj_rate),0),
           COALESCE(SUM(CASE WHEN status = 'ISPLACENA' THEN 1 ELSE 0 END),0)
    INTO v_broj_evidentiranih,v_suma,v_najveca_rata,v_broj_isplacenih
    FROM payments WHERE contract_id = OLD.id;
    IF NEW.ukupni_iznos < v_suma THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Iznos ugovora je manji od evidentiranih rata';
END IF;
IF NEW.broj_rata < v_najveca_rata THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Broj rata manji je od postojece rate';
END IF;
    IF v_broj_isplacenih > 0 THEN
        IF NEW.ukupni_iznos <> OLD.ukupni_iznos
           OR NEW.mjesecni_iznos <> OLD.mjesecni_iznos
           OR NEW.broj_rata <> OLD.broj_rata THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Finansijski uslovi isplacivanog ugovora su zakljucani';
END IF;
        IF NEW.status IN ('NACRT','PRIPREMLJEN') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ugovor sa isplatama ne moze biti nacrt';
END IF;
END IF;
    IF v_broj_evidentiranih > 0
       AND NOT (NEW.datum_potpisivanja <=> OLD.datum_potpisivanja) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Datum potpisivanja nije moguce promijeniti';
END IF;
END$$

CREATE TRIGGER trg_contracts_before_delete
    BEFORE DELETE ON contracts FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Direktno brisanje ugovora nije dozvoljeno';
END$$

    CREATE TRIGGER trg_audit_log_before_update
        BEFORE UPDATE ON audit_log FOR EACH ROW
    BEGIN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Izmjena audit zapisa nije dozvoljena';
END$$

        CREATE TRIGGER trg_audit_log_before_delete
            BEFORE DELETE ON audit_log FOR EACH ROW
        BEGIN
            SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Brisanje audit zapisa nije dozvoljeno';
END$$

            CREATE TRIGGER trg_criteria_before_update
                BEFORE UPDATE ON criteria FOR EACH ROW
            BEGIN
                DECLARE v_broj_bodovanja BIGINT DEFAULT 0;
                SELECT COUNT(*) INTO v_broj_bodovanja
                FROM score_items WHERE criterion_id = OLD.id;
                IF v_broj_bodovanja > 0 THEN
        IF NOT (NEW.competition_id <=> OLD.competition_id)
           OR NOT (NEW.category_id <=> OLD.category_id)
           OR NOT (NEW.naziv <=> OLD.naziv)
           OR NOT (NEW.tip_bodovanja <=> OLD.tip_bodovanja)
           OR NOT (NEW.pravilo_json <=> OLD.pravilo_json)
           OR NOT (NEW.maksimalni_bodovi <=> OLD.maksimalni_bodovi) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Kriterij je vec koristen za bodovanje';
            END IF;
        END IF;
        END$$

        CREATE TRIGGER trg_criteria_before_delete
            BEFORE DELETE ON criteria FOR EACH ROW
        BEGIN
            SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Brisanje kriterija nije dozvoljeno';
END$$

            DELIMITER ;

            SELECT EVENT_OBJECT_TABLE AS tabela, TRIGGER_NAME AS trigger_naziv,
                   EVENT_MANIPULATION AS operacija
            FROM information_schema.TRIGGERS
            WHERE TRIGGER_SCHEMA = 'estipendija'
            ORDER BY EVENT_OBJECT_TABLE, TRIGGER_NAME;
