
CREATE DATABASE IF NOT EXISTS estipendija
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE estipendija;

CREATE TABLE IF NOT EXISTS roles (
                                     id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                     naziv VARCHAR(50) NOT NULL,
    opis VARCHAR(255),
    CONSTRAINT uq_roles_name UNIQUE (naziv),
    CONSTRAINT chk_roles_name CHECK (CHAR_LENGTH(TRIM(naziv)) > 0)
    ) ENGINE=InnoDB;

CREATE TABLE users (
                       id BIGINT AUTO_INCREMENT PRIMARY KEY,
                       ime VARCHAR(100) NOT NULL,
                       prezime VARCHAR(100) NOT NULL,
                       username VARCHAR(100) NOT NULL,
                       email VARCHAR(255) NOT NULL,
                       password_hash VARCHAR(255) NOT NULL,
                       role_id BIGINT NOT NULL,
                       aktivan BOOLEAN NOT NULL DEFAULT TRUE,
                       failed_login_attempts INT NOT NULL DEFAULT 0,
                       locked_until DATETIME NULL,
                       last_login_at DATETIME NULL,
                       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                       updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                       CONSTRAINT uq_users_username UNIQUE (username),
                       CONSTRAINT uq_users_email UNIQUE (email),
                       CONSTRAINT fk_users_roles FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT,
                       CONSTRAINT chk_users_attempts CHECK (failed_login_attempts >= 0),
                       CONSTRAINT chk_users_username CHECK (CHAR_LENGTH(TRIM(username)) > 0),
                       CONSTRAINT chk_users_password_hash CHECK (CHAR_LENGTH(TRIM(password_hash)) >= 40)
) ENGINE=InnoDB;

CREATE TABLE competitions (
                              id BIGINT AUTO_INCREMENT PRIMARY KEY,
                              naziv VARCHAR(255) NOT NULL,
                              opis TEXT,
                              akademska_godina VARCHAR(9) NOT NULL,
                              datum_objave DATE NULL,
                              datum_pocetka DATE NOT NULL,
                              datum_zavrsetka DATE NOT NULL,
                              budzet DECIMAL(12,2) NOT NULL,
                              broj_stipendija INT NOT NULL,
                              status ENUM('NACRT','OTVOREN','ZATVOREN','OBJAVLJEN','ARHIVIRAN') NOT NULL DEFAULT 'NACRT',
                              created_by BIGINT NOT NULL,
                              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                              updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                              CONSTRAINT fk_competitions_users FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
                              CONSTRAINT chk_competition_name CHECK (CHAR_LENGTH(TRIM(naziv)) > 0),
                              CONSTRAINT chk_competition_year CHECK (akademska_godina REGEXP '^[0-9]{4}/[0-9]{4}$'),
    CONSTRAINT chk_competition_dates CHECK (datum_zavrsetka >= datum_pocetka),
    CONSTRAINT chk_competition_publication CHECK (datum_objave IS NULL OR datum_objave <= datum_zavrsetka),
    CONSTRAINT chk_competition_budget CHECK (budzet > 0),
    CONSTRAINT chk_competition_scholarships CHECK (broj_stipendija > 0),
    INDEX idx_competitions_status_dates (status, datum_zavrsetka)
) ENGINE=InnoDB;

CREATE TABLE categories (
                            id BIGINT AUTO_INCREMENT PRIMARY KEY,
                            competition_id BIGINT NOT NULL,
                            naziv VARCHAR(150) NOT NULL,
                            opis TEXT,
                            maksimalan_broj_stipendija INT NULL,
                            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                            CONSTRAINT fk_categories_competitions FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE RESTRICT,
                            CONSTRAINT uq_category_name_per_competition UNIQUE (competition_id, naziv),
                            CONSTRAINT uq_categories_id_competition UNIQUE (id, competition_id),
                            CONSTRAINT chk_category_name CHECK (CHAR_LENGTH(TRIM(naziv)) > 0),
                            CONSTRAINT chk_category_scholarships CHECK (maksimalan_broj_stipendija IS NULL OR maksimalan_broj_stipendija > 0)
) ENGINE=InnoDB;

CREATE TABLE criteria (
                          id BIGINT AUTO_INCREMENT PRIMARY KEY,
                          competition_id BIGINT NOT NULL,
                          category_id BIGINT NULL,
                          naziv VARCHAR(150) NOT NULL,
                          opis TEXT,
                          tip_bodovanja ENUM('FORMULA','SKALA','DA_NE') NOT NULL,
                          pravilo_json JSON NOT NULL,
                          maksimalni_bodovi DECIMAL(8,2) NOT NULL,
                          aktivan BOOLEAN NOT NULL DEFAULT TRUE,
                          scope_category_id BIGINT GENERATED ALWAYS AS (COALESCE(category_id, 0)) STORED,
                          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                          CONSTRAINT fk_criteria_competitions FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE RESTRICT,
                          CONSTRAINT fk_criteria_category_competition FOREIGN KEY (category_id, competition_id)
                              REFERENCES categories(id, competition_id) ON DELETE RESTRICT,
                          CONSTRAINT uq_criteria_name_scope UNIQUE (competition_id, scope_category_id, naziv),
                          CONSTRAINT uq_criteria_id_competition UNIQUE (id, competition_id),
                          CONSTRAINT chk_criteria_name CHECK (CHAR_LENGTH(TRIM(naziv)) > 0),
                          CONSTRAINT chk_criteria_max_points CHECK (maksimalni_bodovi >= 0)
) ENGINE=InnoDB;

CREATE TABLE required_documents (
                                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                    competition_id BIGINT NOT NULL,
                                    category_id BIGINT NULL,
                                    naziv VARCHAR(150) NOT NULL,
                                    opis TEXT,
                                    obavezan BOOLEAN NOT NULL DEFAULT TRUE,
                                    dozvoljeni_formati VARCHAR(100) NULL,
                                    maksimalna_velicina_mb INT NULL,
                                    aktivan BOOLEAN NOT NULL DEFAULT TRUE,
                                    scope_category_id BIGINT GENERATED ALWAYS AS (COALESCE(category_id, 0)) STORED,
                                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                                    CONSTRAINT fk_required_documents_competitions FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE RESTRICT,
                                    CONSTRAINT fk_required_document_category_competition FOREIGN KEY (category_id, competition_id)
                                        REFERENCES categories(id, competition_id) ON DELETE RESTRICT,
                                    CONSTRAINT uq_required_document_name_scope UNIQUE (competition_id, scope_category_id, naziv),
                                    CONSTRAINT uq_required_document_id_competition UNIQUE (id, competition_id),
                                    CONSTRAINT chk_required_document_name CHECK (CHAR_LENGTH(TRIM(naziv)) > 0),
                                    CONSTRAINT chk_required_document_size CHECK (maksimalna_velicina_mb IS NULL OR maksimalna_velicina_mb > 0)
) ENGINE=InnoDB;

CREATE TABLE candidates (
                            id BIGINT AUTO_INCREMENT PRIMARY KEY,
                            ime VARCHAR(100) NOT NULL,
                            prezime VARCHAR(100) NOT NULL,
                            datum_rodjenja DATE NULL,
                            email VARCHAR(255) NULL,
                            telefon VARCHAR(30) NULL,
                            adresa VARCHAR(255) NULL,
                            grad VARCHAR(100) NULL,
                            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                            CONSTRAINT chk_candidate_name CHECK (CHAR_LENGTH(TRIM(ime)) > 0 AND CHAR_LENGTH(TRIM(prezime)) > 0),
                            INDEX idx_candidates_name (prezime, ime)
) ENGINE=InnoDB;

CREATE TABLE applications (
                              id BIGINT AUTO_INCREMENT PRIMARY KEY,
                              candidate_id BIGINT NOT NULL,
                              competition_id BIGINT NOT NULL,
                              category_id BIGINT NOT NULL,
                              submitted_by BIGINT NOT NULL,
                              fakultet VARCHAR(255) NOT NULL,
                              univerzitet VARCHAR(255) NULL,
                              godina_studija INT NOT NULL,
                              prosjek_ocjena DECIMAL(4,2) NULL,
                              datum_podnosenja DATETIME NULL,
                              status ENUM('DRAFT','PODNESENA','U_PROVJERI','DOPUNA_TRAZENA','PROVJERENA',
        'BODOVANA','NA_RANG_LISTI','ODOBRENA','ODBIJENA','ZALBA','KONACNA','POVUCENA')
        NOT NULL DEFAULT 'DRAFT',
                              napomena TEXT,
                              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                              updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                              CONSTRAINT fk_applications_candidates FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE RESTRICT,
                              CONSTRAINT fk_applications_competitions FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE RESTRICT,
                              CONSTRAINT fk_applications_category_competition FOREIGN KEY (category_id, competition_id)
                                  REFERENCES categories(id, competition_id) ON DELETE RESTRICT,
                              CONSTRAINT fk_applications_users FOREIGN KEY (submitted_by) REFERENCES users(id) ON DELETE RESTRICT,
                              CONSTRAINT uq_candidate_competition UNIQUE (candidate_id, competition_id),
                              CONSTRAINT uq_applications_id_competition UNIQUE (id, competition_id),
                              CONSTRAINT chk_application_faculty CHECK (CHAR_LENGTH(TRIM(fakultet)) > 0),
                              CONSTRAINT chk_application_study_year CHECK (godina_studija BETWEEN 1 AND 8),
                              CONSTRAINT chk_application_average CHECK (prosjek_ocjena IS NULL OR prosjek_ocjena BETWEEN 6.00 AND 10.00),
                              CONSTRAINT chk_application_submission CHECK (status = 'DRAFT' OR datum_podnosenja IS NOT NULL),
                              INDEX idx_applications_competition_status (competition_id, status),
                              INDEX idx_applications_faculty (fakultet),
                              INDEX idx_applications_study_year (godina_studija)
) ENGINE=InnoDB;

CREATE TABLE application_documents (
                                       id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                       application_id BIGINT NOT NULL,
                                       competition_id BIGINT NOT NULL,
                                       required_document_id BIGINT NOT NULL,
                                       verzija INT NOT NULL DEFAULT 1,
                                       naziv_fajla VARCHAR(255) NOT NULL,
                                       putanja_fajla VARCHAR(500) NOT NULL,
                                       mime_type VARCHAR(100) NOT NULL,
                                       velicina_bajtova BIGINT NOT NULL,
                                       sha256_hash CHAR(64) NOT NULL,
                                       status ENUM('NA_CEKANJU','PRIHVACEN','ODBIJEN','POTREBNA_DOPUNA') NOT NULL DEFAULT 'NA_CEKANJU',
                                       napomena TEXT,
                                       uploaded_by BIGINT NOT NULL,
                                       verified_by BIGINT NULL,
                                       uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       verified_at TIMESTAMP NULL,
                                       CONSTRAINT fk_appdoc_application_comp FOREIGN KEY (application_id, competition_id)
                                           REFERENCES applications(id, competition_id) ON DELETE RESTRICT,
                                       CONSTRAINT fk_appdoc_required_comp FOREIGN KEY (required_document_id, competition_id)
                                           REFERENCES required_documents(id, competition_id) ON DELETE RESTRICT,
                                       CONSTRAINT fk_appdoc_uploaded_by FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE RESTRICT,
                                       CONSTRAINT fk_appdoc_verified_by FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE RESTRICT,
                                       CONSTRAINT uq_appdoc_version UNIQUE (application_id, required_document_id, verzija),
                                       CONSTRAINT chk_appdoc_version CHECK (verzija > 0),
                                       CONSTRAINT chk_appdoc_size CHECK (velicina_bajtova > 0),
                                       CONSTRAINT chk_appdoc_hash CHECK (sha256_hash REGEXP '^[0-9a-fA-F]{64}$'),
    CONSTRAINT chk_appdoc_review CHECK (
        (status = 'NA_CEKANJU' AND verified_by IS NULL AND verified_at IS NULL)
        OR (status <> 'NA_CEKANJU' AND verified_by IS NOT NULL AND verified_at IS NOT NULL)
    ),
    INDEX idx_appdoc_application_status (application_id, status)
) ENGINE=InnoDB;

CREATE TABLE score_items (
                             id BIGINT AUTO_INCREMENT PRIMARY KEY,
                             application_id BIGINT NOT NULL,
                             competition_id BIGINT NOT NULL,
                             criterion_id BIGINT NOT NULL,
                             ulazna_vrijednost VARCHAR(255) NULL,
                             automatski_bodovi DECIMAL(8,2) NOT NULL DEFAULT 0,
                             konacni_bodovi DECIMAL(8,2) NOT NULL DEFAULT 0,
                             rucna_korekcija BOOLEAN NOT NULL DEFAULT FALSE,
                             obrazlozenje_korekcije TEXT NULL,
                             evaluated_by BIGINT NULL,
                             created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                             updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                             CONSTRAINT fk_scores_application_comp FOREIGN KEY (application_id, competition_id)
                                 REFERENCES applications(id, competition_id) ON DELETE RESTRICT,
                             CONSTRAINT fk_scores_criterion_comp FOREIGN KEY (criterion_id, competition_id)
                                 REFERENCES criteria(id, competition_id) ON DELETE RESTRICT,
                             CONSTRAINT fk_scores_user FOREIGN KEY (evaluated_by) REFERENCES users(id) ON DELETE RESTRICT,
                             CONSTRAINT uq_application_criterion UNIQUE (application_id, criterion_id),
                             CONSTRAINT chk_scores_auto CHECK (automatski_bodovi >= 0),
                             CONSTRAINT chk_scores_final CHECK (konacni_bodovi >= 0),
                             CONSTRAINT chk_scores_manual CHECK (
                                 (rucna_korekcija = FALSE AND konacni_bodovi = automatski_bodovi)
                                     OR (rucna_korekcija = TRUE AND obrazlozenje_korekcije IS NOT NULL
                                     AND CHAR_LENGTH(TRIM(obrazlozenje_korekcije)) > 0 AND evaluated_by IS NOT NULL)
                                 )
) ENGINE=InnoDB;

CREATE TABLE application_assignments (
                                         id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                         application_id BIGINT NOT NULL,
                                         commission_member_id BIGINT NOT NULL,
                                         assigned_by BIGINT NOT NULL,
                                         status ENUM('DODIJELJENA','U_OBRADI','ZAVRSENA','OTKAZANA') NOT NULL DEFAULT 'DODIJELJENA',
                                         assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                         completed_at TIMESTAMP NULL,
                                         napomena TEXT NULL,
                                         CONSTRAINT fk_assignments_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
                                         CONSTRAINT fk_assignments_member FOREIGN KEY (commission_member_id) REFERENCES users(id) ON DELETE RESTRICT,
                                         CONSTRAINT fk_assignments_assigner FOREIGN KEY (assigned_by) REFERENCES users(id) ON DELETE RESTRICT,
                                         CONSTRAINT uq_assignment_member UNIQUE (application_id, commission_member_id),
                                         CONSTRAINT chk_assignments_completion CHECK (
                                             (status = 'ZAVRSENA' AND completed_at IS NOT NULL AND completed_at >= assigned_at)
                                                 OR (status <> 'ZAVRSENA' AND completed_at IS NULL)
                                             ),
                                         INDEX idx_assignments_member_status (commission_member_id, status)
) ENGINE=InnoDB;

CREATE TABLE appeals (
                         id BIGINT AUTO_INCREMENT PRIMARY KEY,
                         application_id BIGINT NOT NULL,
                         razlog TEXT NOT NULL,
                         datum_podnosenja DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                         status ENUM('PODNESENA','U_OBRADI','PRIHVACENA','ODBIJENA','ODBACENA') NOT NULL DEFAULT 'PODNESENA',
                         odluka TEXT NULL,
                         datum_odluke DATETIME NULL,
                         processed_by BIGINT NULL,
                         created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                         updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                         CONSTRAINT fk_appeals_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
                         CONSTRAINT fk_appeals_processor FOREIGN KEY (processed_by) REFERENCES users(id) ON DELETE RESTRICT,
                         CONSTRAINT chk_appeals_reason CHECK (CHAR_LENGTH(TRIM(razlog)) > 0),
                         CONSTRAINT chk_appeals_decision CHECK (
                             (status IN ('PODNESENA','U_OBRADI') AND odluka IS NULL AND datum_odluke IS NULL AND processed_by IS NULL)
                                 OR (status IN ('PRIHVACENA','ODBIJENA','ODBACENA') AND odluka IS NOT NULL
                                 AND CHAR_LENGTH(TRIM(odluka)) > 0 AND datum_odluke IS NOT NULL
                                 AND datum_odluke >= datum_podnosenja AND processed_by IS NOT NULL)
                             ),
                         INDEX idx_appeals_application_status (application_id, status)
) ENGINE=InnoDB;

CREATE TABLE contracts (
                           id BIGINT AUTO_INCREMENT PRIMARY KEY,
                           application_id BIGINT NOT NULL,
                           broj_ugovora VARCHAR(100) NOT NULL,
                           datum_kreiranja DATE NOT NULL,
                           datum_potpisivanja DATE NULL,
                           ukupni_iznos DECIMAL(12,2) NOT NULL,
                           mjesecni_iznos DECIMAL(10,2) NOT NULL,
                           broj_rata INT NOT NULL,
                           status ENUM('NACRT','PRIPREMLJEN','POTPISAN','AKTIVAN','ZAVRSEN','RASKINUT') NOT NULL DEFAULT 'NACRT',
                           putanja_pdf VARCHAR(500) NULL,
                           created_by BIGINT NOT NULL,
                           created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                           updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                           CONSTRAINT fk_contracts_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
                           CONSTRAINT fk_contracts_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
                           CONSTRAINT uq_contract_number UNIQUE (broj_ugovora),
                           CONSTRAINT uq_contract_application UNIQUE (application_id),
                           CONSTRAINT chk_contract_number CHECK (CHAR_LENGTH(TRIM(broj_ugovora)) > 0),
                           CONSTRAINT chk_contract_total CHECK (ukupni_iznos > 0),
                           CONSTRAINT chk_contract_monthly CHECK (mjesecni_iznos > 0),
                           CONSTRAINT chk_contract_installments CHECK (broj_rata > 0),
                           CONSTRAINT chk_contract_dates CHECK (datum_potpisivanja IS NULL OR datum_potpisivanja >= datum_kreiranja),
                           CONSTRAINT chk_contract_signed_status CHECK (
                               status NOT IN ('POTPISAN','AKTIVAN','ZAVRSEN') OR datum_potpisivanja IS NOT NULL
                               )
) ENGINE=InnoDB;

CREATE TABLE payments (
                          id BIGINT AUTO_INCREMENT PRIMARY KEY,
                          contract_id BIGINT NOT NULL,
                          broj_rate INT NOT NULL,
                          iznos DECIMAL(12,2) NOT NULL,
                          planirani_datum DATE NOT NULL,
                          datum_isplate DATE NULL,
                          status ENUM('PLANIRANA','DOSPJELA','ISPLACENA','OTKAZANA') NOT NULL DEFAULT 'PLANIRANA',
                          referenca_transakcije VARCHAR(150) NULL,
                          napomena TEXT NULL,
                          created_by BIGINT NOT NULL,
                          updated_by BIGINT NULL,
                          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                          CONSTRAINT fk_payments_contract FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE RESTRICT,
                          CONSTRAINT fk_payments_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
                          CONSTRAINT fk_payments_updater FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE RESTRICT,
                          CONSTRAINT uq_contract_installment UNIQUE (contract_id, broj_rate),
                          CONSTRAINT uq_payment_transaction UNIQUE (referenca_transakcije),
                          CONSTRAINT chk_payment_amount CHECK (iznos > 0),
                          CONSTRAINT chk_payment_installment CHECK (broj_rate > 0),
                          CONSTRAINT chk_payment_date CHECK (
                              (status = 'ISPLACENA' AND datum_isplate IS NOT NULL)
                                  OR (status <> 'ISPLACENA' AND datum_isplate IS NULL)
                              ),
                          INDEX idx_payments_contract_status (contract_id, status),
                          INDEX idx_payments_planned (status, planirani_datum)
) ENGINE=InnoDB;

CREATE TABLE audit_log (
                           id BIGINT AUTO_INCREMENT PRIMARY KEY,
                           user_id BIGINT NULL,
                           akcija ENUM('INSERT','UPDATE','DELETE','LOGIN','LOGIN_FAILED','LOGOUT','OTHER') NOT NULL,
                           naziv_tabele VARCHAR(100) NOT NULL,
                           entity_id BIGINT NULL,
                           stara_vrijednost JSON NULL,
                           nova_vrijednost JSON NULL,
                           opis TEXT NULL,
                           ip_adresa VARCHAR(45) NULL,
                           created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                           CONSTRAINT fk_audit_log_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
                           CONSTRAINT chk_audit_entity_name CHECK (CHAR_LENGTH(TRIM(naziv_tabele)) > 0),
                           INDEX idx_audit_user_date (user_id, created_at),
                           INDEX idx_audit_entity (naziv_tabele, entity_id),
                           INDEX idx_audit_created (created_at)
) ENGINE=InnoDB;


SELECT TABLE_NAME AS tabela
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'estipendija' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT COUNT(*) AS broj_tabela
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'estipendija' AND TABLE_TYPE = 'BASE TABLE';
