-- ===============================================================
-- VITEZ eSTIPENDIJA: RELACIJSKA SEMA (nova baza, MySQL 8.0.16+)
-- Autorski dizajn prema funkcionalnoj specifikaciji, verzija 1.0
-- Kod u SQL nazivima i ENUM vrijednostima je ASCII bez dijakritika.
-- Izvrsiti NA PRAZNOJ TESTNOJ BAZI; NE izvoditi nad starom bazom.
-- Vrijeme: DATETIME(6) predstavlja UTC, JDBC sesije MORAJU imati UTC.
-- Izvrsiti REDOM: 1. schema.sql  2. triggers.sql
-- InnoDB; utf8mb4_unicode_ci; NULL je oznaka "nije poznato".
-- ===============================================================

CREATE DATABASE IF NOT EXISTS e_stipendija
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE e_stipendija;
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET time_zone = '+00:00';

-- 01. Osnovne uloge. Svaki nalog ima jednu ulogu.
CREATE TABLE uloge (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sifra VARCHAR(20) NOT NULL,
  naziv VARCHAR(80) NOT NULL,
  opis VARCHAR(255),
  CONSTRAINT uq_uloge_sifra UNIQUE (sifra),
  CONSTRAINT chk_uloge_sifra CHECK (sifra IN ('ADMIN','KOMISIJA','STUDENT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 02. Autentifikacija i sigurnost.
CREATE TABLE korisnici (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  uloga_id SMALLINT UNSIGNED NOT NULL,
  ime VARCHAR(100) NOT NULL,
  prezime VARCHAR(100) NOT NULL,
  korisnicko_ime VARCHAR(100) NOT NULL,
  email VARCHAR(254) NOT NULL,
  lozinka_hash VARCHAR(255) NOT NULL,
  aktivan BOOLEAN NOT NULL DEFAULT TRUE,
  neuspjeli_pokusaji SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  zakljucan_do DATETIME(6) NULL,
  zadnja_prijava_at DATETIME(6) NULL,
  kreiran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  azuriran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_korisnici_username UNIQUE (korisnicko_ime),
  CONSTRAINT uq_korisnici_email UNIQUE (email),
  CONSTRAINT fk_korisnici_uloga FOREIGN KEY (uloga_id) REFERENCES uloge(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_korisnici_ime CHECK (CHAR_LENGTH(TRIM(ime)) > 0 AND CHAR_LENGTH(TRIM(prezime)) > 0),
  CONSTRAINT chk_korisnici_username CHECK (CHAR_LENGTH(TRIM(korisnicko_ime)) >= 3),
  CONSTRAINT chk_korisnici_hash CHECK (CHAR_LENGTH(lozinka_hash) >= 40),
  INDEX idx_korisnici_uloga_aktivan (uloga_id, aktivan)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 03. Profil kandidata (jedan studentski nalog -> najvise jedan profil).
CREATE TABLE studenti (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  korisnik_id BIGINT UNSIGNED NOT NULL,
  ime_roditelja VARCHAR(100),
  jmbg CHAR(13) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  datum_rodjenja DATE NOT NULL,
  adresa VARCHAR(255) NOT NULL,
  mjesto VARCHAR(120) NOT NULL,
  opcina VARCHAR(120) NOT NULL,
  telefon VARCHAR(30),
  naziv_fakulteta VARCHAR(255),
  naziv_univerziteta VARCHAR(255),
  smjer VARCHAR(255),
  ciklus_studija ENUM('I','II','III'),
  godina_studija TINYINT UNSIGNED,
  broj_indeksa VARCHAR(50),
  prosjek_ocjena DECIMAL(4,2),
  broj_racuna VARCHAR(34),
  vrsta_racuna ENUM('IBAN','DOMACI') NULL,
  naziv_banke VARCHAR(150),
  kreiran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  azuriran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_studenti_korisnik UNIQUE (korisnik_id),
  CONSTRAINT uq_studenti_jmbg UNIQUE (jmbg),
  CONSTRAINT fk_studenti_korisnik FOREIGN KEY (korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_studenti_jmbg CHECK (jmbg REGEXP '^[0-9]{13}$'),
  CONSTRAINT chk_studenti_godina CHECK (godina_studija IS NULL OR godina_studija BETWEEN 1 AND 8),
  CONSTRAINT chk_studenti_prosjek CHECK (prosjek_ocjena IS NULL OR prosjek_ocjena BETWEEN 1.00 AND 10.00),
  CONSTRAINT chk_studenti_racun CHECK (
    (broj_racuna IS NULL AND vrsta_racuna IS NULL)
    OR (broj_racuna IS NOT NULL AND vrsta_racuna IS NOT NULL
        AND CHAR_LENGTH(TRIM(broj_racuna)) >= 10)
  ),
  INDEX idx_studenti_fakultet (naziv_fakulteta)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 04. Konkurs i rokovi, sa tacnim satom (UTC).
CREATE TABLE konkursi (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  naziv VARCHAR(255) NOT NULL,
  akademska_godina CHAR(9) NOT NULL,
  opis TEXT,
  ukupan_budzet DECIMAL(14,2) NOT NULL,
  broj_stipendija INT UNSIGNED NOT NULL,
  datum_od DATETIME(6) NOT NULL,
  datum_do DATETIME(6) NOT NULL,
  rok_dopune DATETIME(6),
  rok_zalbi DATETIME(6),
  status ENUM('NACRT','OTVOREN','ZATVOREN','OBJAVLJEN','ARHIVIRAN') NOT NULL DEFAULT 'NACRT',
  kreirao_korisnik_id BIGINT UNSIGNED NOT NULL,
  izmijenio_korisnik_id BIGINT UNSIGNED,
  kreiran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  azuriran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_konkurs_kreirao FOREIGN KEY (kreirao_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_konkurs_izmijenio FOREIGN KEY (izmijenio_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_konkurs_naziv CHECK (CHAR_LENGTH(TRIM(naziv)) > 0),
  CONSTRAINT chk_konkurs_godina CHECK (akademska_godina REGEXP '^[0-9]{4}/[0-9]{4}$'),
  CONSTRAINT chk_konkurs_budzet CHECK (ukupan_budzet > 0 AND broj_stipendija > 0),
  CONSTRAINT chk_konkurs_rok CHECK (datum_do > datum_od),
  CONSTRAINT chk_konkurs_dopuna CHECK (rok_dopune IS NULL OR rok_dopune >= datum_do),
  CONSTRAINT chk_konkurs_zalbe CHECK (rok_zalbi IS NULL OR rok_zalbi >= datum_do),
  INDEX idx_konkurs_status_rok (status, datum_od, datum_do),
  INDEX idx_konkurs_akademska (akademska_godina)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 05. Kvota i minimalni uslovi po kategoriji konkursa.
CREATE TABLE kategorije_stipendija (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  konkurs_id BIGINT UNSIGNED NOT NULL,
  naziv VARCHAR(150) NOT NULL,
  opis TEXT,
  kvota_stipendija INT UNSIGNED NOT NULL,
  min_prosjek DECIMAL(4,2),
  aktivna BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_kategorije_naziv UNIQUE (konkurs_id, naziv),
  CONSTRAINT uq_kategorije_id_konkurs UNIQUE (id, konkurs_id),
  CONSTRAINT fk_kategorije_konkurs FOREIGN KEY (konkurs_id) REFERENCES konkursi(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_kategorije_kvota CHECK (kvota_stipendija > 0),
  CONSTRAINT chk_kategorije_prosjek CHECK (min_prosjek IS NULL OR min_prosjek BETWEEN 1.00 AND 10.00),
  CONSTRAINT chk_kategorije_naziv CHECK (CHAR_LENGTH(TRIM(naziv)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 06. M:N: koji su clanovi komisije imenovani za koji konkurs.
CREATE TABLE clanovi_komisije_konkursa (
  konkurs_id BIGINT UNSIGNED NOT NULL,
  korisnik_id BIGINT UNSIGNED NOT NULL,
  aktivan BOOLEAN NOT NULL DEFAULT TRUE,
  imenovan_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (konkurs_id, korisnik_id),
  CONSTRAINT fk_ckk_konkurs FOREIGN KEY (konkurs_id) REFERENCES konkursi(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_ckk_korisnik FOREIGN KEY (korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  INDEX idx_ckk_korisnik (korisnik_id, aktivan)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 07. Sifrarnik izvora podatka za konfigurabilno bodovanje.
CREATE TABLE izvori_bodovanja (
  sifra VARCHAR(45) PRIMARY KEY,
  naziv VARCHAR(120) NOT NULL,
  tip_vrijednosti ENUM('BROJ','BOOL','TEKST') NOT NULL,
  nacin_dobavljanja ENUM('SISTEM','UNOS') NOT NULL,
  opis VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 07a. Minimalni uslovi kategorije kao pravila umjesto neprozirnog JSON-a.
CREATE TABLE uslovi_kategorija (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  kategorija_id BIGINT UNSIGNED NOT NULL,
  izvor_sifra VARCHAR(45) NOT NULL,
  operator_poredjenja ENUM('EQ','NE','GT','GTE','LT','LTE') NOT NULL,
  vrijednost_broj DECIMAL(14,4) NULL,
  vrijednost_bool BOOLEAN NULL,
  vrijednost_tekst VARCHAR(255) NULL,
  CONSTRAINT uq_uslov_kat_izvor UNIQUE (kategorija_id, izvor_sifra),
  CONSTRAINT fk_uslov_kategorija FOREIGN KEY (kategorija_id) REFERENCES kategorije_stipendija(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_uslov_izvor FOREIGN KEY (izvor_sifra) REFERENCES izvori_bodovanja(sifra)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_uslov_vrijednost CHECK (
    ((vrijednost_broj IS NOT NULL) + (vrijednost_bool IS NOT NULL)
     + (vrijednost_tekst IS NOT NULL)) = 1
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 08. Kriterij vrijedi za cijeli konkurs (kategorija_id NULL) ili jednu kategoriju.
CREATE TABLE kriteriji_bodovanja (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  konkurs_id BIGINT UNSIGNED NOT NULL,
  kategorija_id BIGINT UNSIGNED NULL,
  kategorija_kljuc BIGINT UNSIGNED GENERATED ALWAYS AS (IFNULL(kategorija_id, 0)) STORED,
  naziv VARCHAR(150) NOT NULL,
  opis TEXT,
  tip_kriterija ENUM('FORMULA','SKALA','DA_NE') NOT NULL,
  izvor_sifra VARCHAR(45) NOT NULL,
  koeficijent DECIMAL(12,4) NULL,
  fiksni_bodovi DECIMAL(8,2) NULL,
  max_bodova DECIMAL(8,2) NOT NULL,
  aktivan BOOLEAN NOT NULL DEFAULT TRUE,
  kreiran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  azuriran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_kriteriji_opseg_naziv UNIQUE (konkurs_id, kategorija_kljuc, naziv),
  CONSTRAINT fk_kriteriji_konkurs FOREIGN KEY (konkurs_id) REFERENCES konkursi(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_kriteriji_kategorija FOREIGN KEY (kategorija_id, konkurs_id)
    REFERENCES kategorije_stipendija(id, konkurs_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_kriteriji_izvor FOREIGN KEY (izvor_sifra) REFERENCES izvori_bodovanja(sifra)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_kriteriji_max CHECK (max_bodova >= 0),
  CONSTRAINT chk_kriteriji_tip CHECK (
    (tip_kriterija = 'FORMULA' AND koeficijent IS NOT NULL AND koeficijent >= 0 AND fiksni_bodovi IS NULL)
    OR (tip_kriterija = 'SKALA' AND koeficijent IS NULL AND fiksni_bodovi IS NULL)
    OR (tip_kriterija = 'DA_NE' AND koeficijent IS NULL AND fiksni_bodovi IS NOT NULL
        AND fiksni_bodovi BETWEEN 0 AND max_bodova)
  ),
  INDEX idx_kriteriji_konkurs_aktivan (konkurs_id, aktivan, kategorija_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 09. Intervali za SKALA (granice su obostrano ukljucene).
CREATE TABLE skale_kriterija (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  kriterij_id BIGINT UNSIGNED NOT NULL,
  od_vrijednost DECIMAL(14,4) NOT NULL,
  do_vrijednost DECIMAL(14,4) NOT NULL,
  bodovi DECIMAL(8,2) NOT NULL,
  CONSTRAINT fk_skale_kriterij FOREIGN KEY (kriterij_id) REFERENCES kriteriji_bodovanja(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT uq_skale_pocetak UNIQUE (kriterij_id, od_vrijednost),
  CONSTRAINT chk_skale_granice CHECK (do_vrijednost >= od_vrijednost),
  CONSTRAINT chk_skale_bodovi CHECK (bodovi >= 0),
  INDEX idx_skale_kriterij_interval (kriterij_id, od_vrijednost, do_vrijednost)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Konfiguracija tie-breakera po konkursu ili kategoriji.
CREATE TABLE pravila_izjednacenja (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  konkurs_id BIGINT UNSIGNED NOT NULL,
  kategorija_id BIGINT UNSIGNED NULL,
  kategorija_kljuc BIGINT UNSIGNED GENERATED ALWAYS AS (IFNULL(kategorija_id, 0)) STORED,
  prioritet SMALLINT UNSIGNED NOT NULL,
  pravilo ENUM('VISI_PROSJEK','NIZI_PRIHOD_PO_CLANU','VISA_GODINA_STUDIJA','RANIJE_VRIJEME_PRIJAVE') NOT NULL,
  CONSTRAINT uq_tie_prioritet UNIQUE (konkurs_id, kategorija_kljuc, prioritet),
  CONSTRAINT uq_tie_pravilo UNIQUE (konkurs_id, kategorija_kljuc, pravilo),
  CONSTRAINT fk_tie_konkurs FOREIGN KEY (konkurs_id) REFERENCES konkursi(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_tie_kategorija FOREIGN KEY (kategorija_id, konkurs_id)
    REFERENCES kategorije_stipendija(id, konkurs_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_tie_prioritet CHECK (prioritet >= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. Globalni katalog tipova dokumenata (bez fajlova/BLOB-ova).
CREATE TABLE tipovi_dokumenata (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sifra VARCHAR(50) NOT NULL,
  naziv VARCHAR(255) NOT NULL,
  opis TEXT,
  CONSTRAINT uq_tipovi_sifra UNIQUE (sifra)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. Zahtjevi za dokumente po konkursu i kategoriji; 0=opci opseg.
CREATE TABLE zahtjevi_dokumenata (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  konkurs_id BIGINT UNSIGNED NOT NULL,
  kategorija_id BIGINT UNSIGNED NULL,
  kategorija_kljuc BIGINT UNSIGNED GENERATED ALWAYS AS (IFNULL(kategorija_id, 0)) STORED,
  tip_dokumenta_id SMALLINT UNSIGNED NOT NULL,
  obavezan BOOLEAN NOT NULL DEFAULT TRUE,
  godina_od TINYINT UNSIGNED NULL,
  godina_do TINYINT UNSIGNED NULL,
  ciklus_studija ENUM('I','II','III') NULL,
  maksimalno_bajta BIGINT UNSIGNED NULL,
  godina_od_kljuc TINYINT UNSIGNED GENERATED ALWAYS AS (IFNULL(godina_od, 0)) STORED,
  godina_do_kljuc TINYINT UNSIGNED GENERATED ALWAYS AS (IFNULL(godina_do, 0)) STORED,
  ciklus_kljuc CHAR(3) GENERATED ALWAYS AS (IFNULL(ciklus_studija, 'SVE')) STORED,
  odnosi_se_na ENUM('STUDENT','CLAN_DOMACINSTVA','SVI_PUNOLJETNI') NOT NULL DEFAULT 'STUDENT',
  napomena VARCHAR(255),
  aktivan BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_zahtjev_opseg UNIQUE (konkurs_id, kategorija_kljuc, tip_dokumenta_id,
                                   odnosi_se_na, godina_od_kljuc, godina_do_kljuc, ciklus_kljuc),
  CONSTRAINT fk_zahtjev_konkurs FOREIGN KEY (konkurs_id) REFERENCES konkursi(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_zahtjev_kategorija FOREIGN KEY (kategorija_id, konkurs_id)
    REFERENCES kategorije_stipendija(id, konkurs_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_zahtjev_tip FOREIGN KEY (tip_dokumenta_id) REFERENCES tipovi_dokumenata(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_zahtjev_velicina CHECK (maksimalno_bajta IS NULL OR maksimalno_bajta > 0),
  CONSTRAINT chk_zahtjev_godina CHECK (
    (godina_od IS NULL OR godina_od BETWEEN 1 AND 8) AND
    (godina_do IS NULL OR godina_do BETWEEN 1 AND 8) AND
    (godina_od IS NULL OR godina_do IS NULL OR godina_do >= godina_od)
  ),
  INDEX idx_zahtjev_konkurs_kategorija (konkurs_id, kategorija_id, aktivan)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 13. Jedna prijava studenta po konkursu; obrazovni podaci su HISTORIJSKI SNAPSHOT.
-- Status i protokol postavlja trigger tek pri slanju (DRAFT -> PODNESENA).
CREATE TABLE prijave (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id BIGINT UNSIGNED NOT NULL,
  konkurs_id BIGINT UNSIGNED NOT NULL,
  kategorija_id BIGINT UNSIGNED NOT NULL,
  fakultet_snapshot VARCHAR(255),
  univerzitet_snapshot VARCHAR(255),
  smjer_snapshot VARCHAR(255),
  ciklus_studija_snapshot ENUM('I','II','III'),
  godina_studija_snapshot TINYINT UNSIGNED,
  prosjek_ocjena_snapshot DECIMAL(4,2),
  broj_protokola VARCHAR(50) NULL,
  vrijeme_zaprimanja DATETIME(6) NULL,
  status ENUM('DRAFT','PODNESENA','U_PROVJERI','DOPUNA_TRAZENA','PROVJERENA',
              'BODOVANA','NA_RANG_LISTI','ODOBRENA','ODBIJENA','ZALBA',
              'KONACNA','POVUCENA') NOT NULL DEFAULT 'DRAFT',
  napomena TEXT,
  kreiran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  azuriran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_prijava_student_konkurs UNIQUE (student_id, konkurs_id),
  CONSTRAINT uq_prijava_broj_protokola UNIQUE (broj_protokola),
  CONSTRAINT fk_prijava_student FOREIGN KEY (student_id) REFERENCES studenti(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_prijava_konkurs FOREIGN KEY (konkurs_id) REFERENCES konkursi(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_prijava_kategorija_konkurs FOREIGN KEY (kategorija_id, konkurs_id)
    REFERENCES kategorije_stipendija(id, konkurs_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_prijava_snap_god CHECK (godina_studija_snapshot IS NULL OR godina_studija_snapshot BETWEEN 1 AND 8),
  CONSTRAINT chk_prijava_snap_prosjek CHECK (
    prosjek_ocjena_snapshot IS NULL OR prosjek_ocjena_snapshot BETWEEN 1.00 AND 10.00
  ),
  CONSTRAINT chk_prijava_protokol CHECK (
    (status = 'DRAFT' AND broj_protokola IS NULL AND vrijeme_zaprimanja IS NULL)
    OR (status <> 'DRAFT' AND broj_protokola IS NOT NULL AND vrijeme_zaprimanja IS NOT NULL)
  ),
  INDEX idx_prijave_konkurs_status (konkurs_id, status),
  INDEX idx_prijave_kategorija_status (kategorija_id, status),
  INDEX idx_prijave_fakultet (fakultet_snapshot),
  INDEX idx_prijave_prosjek (prosjek_ocjena_snapshot),
  INDEX idx_prijave_vrijeme (konkurs_id, vrijeme_zaprimanja)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 14. Transakcijski, konkurentno siguran brojac djelovodnih brojeva.
CREATE TABLE brojaci_protokola (
  konkurs_id BIGINT UNSIGNED PRIMARY KEY,
  posljednji_broj BIGINT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_brojac_konkurs FOREIGN KEY (konkurs_id) REFERENCES konkursi(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 15. Kucna lista iskljucivo po prijavi (istorijski podaci).
CREATE TABLE clanovi_domacinstva (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  prijava_id BIGINT UNSIGNED NOT NULL,
  ime_prezime VARCHAR(200) NOT NULL,
  srodstvo ENUM('STUDENT','OTAC','MAJKA','BRAT','SESTRA','SUPRUZNIK',
                'DIJETE','DJED_NANA','DRUGO') NOT NULL,
  godina_rodjenja SMALLINT UNSIGNED NOT NULL,
  status_clana ENUM('ZAPOSLEN','PENZIONER','NEZAPOSLEN','STUDENT_UCENIK','DIJETE','OSTALO') NOT NULL,
  je_podnosilac BOOLEAN NOT NULL DEFAULT FALSE,
  podnosilac_kljuc BIGINT UNSIGNED GENERATED ALWAYS AS (
    CASE WHEN je_podnosilac = TRUE THEN prijava_id ELSE NULL END
  ) STORED,
  CONSTRAINT uq_clan_student_jednom UNIQUE (podnosilac_kljuc),
  CONSTRAINT fk_clan_dom_prijava FOREIGN KEY (prijava_id) REFERENCES prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_clan_dom_ime CHECK (CHAR_LENGTH(TRIM(ime_prezime)) > 0),
  CONSTRAINT chk_clan_dom_god CHECK (godina_rodjenja BETWEEN 1900 AND 2100),
  CONSTRAINT chk_clan_dom_podnosilac CHECK (NOT je_podnosilac OR srodstvo = 'STUDENT'),
  INDEX idx_clan_dom_prijava (prijava_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 16. Jedan clan moze imati vise izvora prihoda (3NF, ne ponavljati kolone).
CREATE TABLE primanja_clanova (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  clan_domacinstva_id BIGINT UNSIGNED NOT NULL,
  vrsta_primanja ENUM('PLATA','PENZIJA','SOCIJALNA_POMOC','HONORAR','OSTALO') NOT NULL,
  opis VARCHAR(255),
  mjesecni_iznos DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_primanja_clan FOREIGN KEY (clan_domacinstva_id) REFERENCES clanovi_domacinstva(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_primanja_iznos CHECK (mjesecni_iznos >= 0),
  INDEX idx_primanja_clan (clan_domacinstva_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 17. Dokazive posebne cinjenice (invaliditet, boracki status, nagrade...).
CREATE TABLE cinjenice_prijave (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  prijava_id BIGINT UNSIGNED NOT NULL,
  izvor_sifra VARCHAR(45) NOT NULL,
  vrijednost_broj DECIMAL(14,4) NULL,
  vrijednost_bool BOOLEAN NULL,
  vrijednost_tekst VARCHAR(255) NULL,
  verifikovano BOOLEAN NOT NULL DEFAULT FALSE,
  verifikovao_korisnik_id BIGINT UNSIGNED NULL,
  verifikovano_at DATETIME(6) NULL,
  CONSTRAINT uq_cinjenica_prijava_izvor UNIQUE (prijava_id, izvor_sifra),
  CONSTRAINT fk_cinjenica_prijava FOREIGN KEY (prijava_id) REFERENCES prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_cinjenica_izvor FOREIGN KEY (izvor_sifra) REFERENCES izvori_bodovanja(sifra)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_cinjenica_verifikovao FOREIGN KEY (verifikovao_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_cinjenica_jedna_vrijednost CHECK (
    ((vrijednost_broj IS NOT NULL) + (vrijednost_bool IS NOT NULL) +
     (vrijednost_tekst IS NOT NULL)) = 1
  ),
  CONSTRAINT chk_cinjenica_verifikacija CHECK (
    (verifikovano = FALSE AND verifikovao_korisnik_id IS NULL AND verifikovano_at IS NULL)
    OR (verifikovano = TRUE AND verifikovao_korisnik_id IS NOT NULL AND verifikovano_at IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 18. Jedinstven katalog datoteka, nikad binarni sadrzaj u MySQL-u.
CREATE TABLE pdf_datoteke (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  originalni_naziv VARCHAR(255) NOT NULL,
  sigurni_naziv VARCHAR(255) NOT NULL,
  storage_kljuc VARCHAR(500) NOT NULL,
  velicina_bajta BIGINT UNSIGNED NOT NULL,
  mime_tip VARCHAR(50) NOT NULL DEFAULT 'application/pdf',
  sha256_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  postavio_korisnik_id BIGINT UNSIGNED NOT NULL,
  postavljeno_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_pdf_storage UNIQUE (storage_kljuc),
  CONSTRAINT fk_pdf_postavio FOREIGN KEY (postavio_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_pdf_velicina CHECK (velicina_bajta > 0),
  CONSTRAINT chk_pdf_mime CHECK (mime_tip = 'application/pdf'),
  CONSTRAINT chk_pdf_hash CHECK (sha256_hash REGEXP '^[0-9a-fA-F]{64}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 19. Verzije dokumenata: i null subjekt ima jedinstvenu kombinaciju.
-- redni_broj dopusta vise svjedocanstava istog tipa (1,2,3,4...).
CREATE TABLE dokumenti_prijave (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  prijava_id BIGINT UNSIGNED NOT NULL,
  zahtjev_dokumenta_id BIGINT UNSIGNED NOT NULL,
  clan_domacinstva_id BIGINT UNSIGNED NULL,
  subjekt_kljuc BIGINT UNSIGNED GENERATED ALWAYS AS (IFNULL(clan_domacinstva_id, 0)) STORED,
  redni_broj SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  verzija SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  pdf_datoteka_id BIGINT UNSIGNED NOT NULL,
  status ENUM('NA_CEKANJU','ODOBREN','ODBIJEN','DOPUNA_TRAZENA') NOT NULL DEFAULT 'NA_CEKANJU',
  napomena_komisije TEXT NULL,
  pregledao_korisnik_id BIGINT UNSIGNED NULL,
  pregledano_at DATETIME(6) NULL,
  kreiran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_dok_verzija UNIQUE (prijava_id, zahtjev_dokumenta_id,
                                 subjekt_kljuc, redni_broj, verzija),
  CONSTRAINT uq_dok_pdf UNIQUE (pdf_datoteka_id),
  CONSTRAINT fk_dok_prijava FOREIGN KEY (prijava_id) REFERENCES prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_dok_zahtjev FOREIGN KEY (zahtjev_dokumenta_id) REFERENCES zahtjevi_dokumenata(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_dok_clan FOREIGN KEY (clan_domacinstva_id) REFERENCES clanovi_domacinstva(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_dok_pdf FOREIGN KEY (pdf_datoteka_id) REFERENCES pdf_datoteke(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_dok_pregledao FOREIGN KEY (pregledao_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_dok_verzija CHECK (verzija >= 1 AND redni_broj >= 1),
  CONSTRAINT chk_dok_status CHECK (
    (status = 'NA_CEKANJU' AND napomena_komisije IS NULL
       AND pregledao_korisnik_id IS NULL AND pregledano_at IS NULL)
    OR (status = 'ODOBREN' AND pregledao_korisnik_id IS NOT NULL AND pregledano_at IS NOT NULL)
    OR (status IN ('ODBIJEN','DOPUNA_TRAZENA')
       AND napomena_komisije IS NOT NULL AND CHAR_LENGTH(TRIM(napomena_komisije)) > 0
       AND pregledao_korisnik_id IS NOT NULL AND pregledano_at IS NOT NULL)
  ),
  INDEX idx_dok_prijava_status (prijava_id, status),
  INDEX idx_dok_zahtjev_status (zahtjev_dokumenta_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 20. Jedan trenutno odgovorni clan komisije po prijavi.
-- Kasnije se moze zamijeniti uz audit trag; ne duplirati komisija_user_id u prijave.
CREATE TABLE dodjele_prijava (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  prijava_id BIGINT UNSIGNED NOT NULL,
  komisija_korisnik_id BIGINT UNSIGNED NOT NULL,
  dodijelio_korisnik_id BIGINT UNSIGNED NOT NULL,
  status ENUM('DODIJELJENA','U_OBRADI','ZAVRSENA','OTKAZANA') NOT NULL DEFAULT 'DODIJELJENA',
  dodijeljeno_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  zavrseno_at DATETIME(6) NULL,
  napomena TEXT,
  CONSTRAINT uq_dodjela_prijava UNIQUE (prijava_id),
  CONSTRAINT fk_dodjela_prijava FOREIGN KEY (prijava_id) REFERENCES prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_dodjela_komisija FOREIGN KEY (komisija_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_dodjela_admin FOREIGN KEY (dodijelio_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_dodjela_zavrseno CHECK (
    (status = 'ZAVRSENA' AND zavrseno_at IS NOT NULL AND zavrseno_at >= dodijeljeno_at)
    OR (status <> 'ZAVRSENA' AND zavrseno_at IS NULL)
  ),
  INDEX idx_dodjela_komisija_status (komisija_korisnik_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 21. Bodovna stavka po prijavi i kriteriju.
CREATE TABLE bodovi_prijave (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  prijava_id BIGINT UNSIGNED NOT NULL,
  kriterij_id BIGINT UNSIGNED NOT NULL,
  ulazna_vrijednost DECIMAL(14,4) NULL,
  automatski_bodovi DECIMAL(8,2) NOT NULL DEFAULT 0,
  korigovani_bodovi DECIMAL(8,2) NULL,
  konacni_bodovi DECIMAL(8,2) NOT NULL DEFAULT 0,
  je_rucno_korigovano BOOLEAN NOT NULL DEFAULT FALSE,
  obrazlozenje_korekcije TEXT NULL,
  korigovao_korisnik_id BIGINT UNSIGNED NULL,
  korigovano_at DATETIME(6) NULL,
  kreiran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  azuriran_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_bodovi_prijava_kriterij UNIQUE (prijava_id, kriterij_id),
  CONSTRAINT fk_bod_prijava FOREIGN KEY (prijava_id) REFERENCES prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_bod_kriterij FOREIGN KEY (kriterij_id) REFERENCES kriteriji_bodovanja(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_bod_korigovao FOREIGN KEY (korigovao_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_bod_ne_neg CHECK (automatski_bodovi >= 0 AND konacni_bodovi >= 0
     AND (korigovani_bodovi IS NULL OR korigovani_bodovi >= 0)),
  CONSTRAINT chk_bod_korekcija CHECK (
    (je_rucno_korigovano = FALSE AND korigovani_bodovi IS NULL
       AND konacni_bodovi = automatski_bodovi
       AND obrazlozenje_korekcije IS NULL AND korigovao_korisnik_id IS NULL AND korigovano_at IS NULL)
    OR (je_rucno_korigovano = TRUE AND korigovani_bodovi IS NOT NULL
       AND konacni_bodovi = korigovani_bodovi
       AND obrazlozenje_korekcije IS NOT NULL AND CHAR_LENGTH(TRIM(obrazlozenje_korekcije)) > 0
       AND korigovao_korisnik_id IS NOT NULL AND korigovano_at IS NOT NULL)
  ),
  INDEX idx_bodovi_kriterij (kriterij_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 22. Neizmjenjiva historija SVAKOG rucnog zahvata u bodove.
CREATE TABLE historija_korekcija (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  bodovna_stavka_id BIGINT UNSIGNED NOT NULL,
  stari_bodovi DECIMAL(8,2) NOT NULL,
  novi_bodovi DECIMAL(8,2) NOT NULL,
  obrazlozenje TEXT NOT NULL,
  komisija_korisnik_id BIGINT UNSIGNED NOT NULL,
  promjena_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_hist_bod FOREIGN KEY (bodovna_stavka_id) REFERENCES bodovi_prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_hist_komisija FOREIGN KEY (komisija_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_hist_tekst CHECK (CHAR_LENGTH(TRIM(obrazlozenje)) > 0),
  CONSTRAINT chk_hist_bod CHECK (stari_bodovi >= 0 AND novi_bodovi >= 0),
  INDEX idx_hist_bod_at (bodovna_stavka_id, promjena_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 23. Svaka verzija rang-liste pripada kategoriji; konkurs se dobija preko kategorije (3NF).
CREATE TABLE rang_liste (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  kategorija_id BIGINT UNSIGNED NOT NULL,
  verzija_broj INT UNSIGNED NOT NULL,
  tip_liste ENUM('PRELIMINARNA','KONACNA') NOT NULL,
  status ENUM('NACRT','POTVRDJENA','OBJAVLJENA') NOT NULL DEFAULT 'NACRT',
  kreirao_korisnik_id BIGINT UNSIGNED NOT NULL,
  potvrdio_korisnik_id BIGINT UNSIGNED NULL,
  objavio_korisnik_id BIGINT UNSIGNED NULL,
  kreirano_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  potvrdjeno_at DATETIME(6) NULL,
  datum_objave DATETIME(6) NULL,
  CONSTRAINT uq_rang_verzija UNIQUE (kategorija_id, verzija_broj),
  CONSTRAINT fk_rang_kategorija FOREIGN KEY (kategorija_id)
    REFERENCES kategorije_stipendija(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_rang_kreirao FOREIGN KEY (kreirao_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_rang_potvrdio FOREIGN KEY (potvrdio_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_rang_objavio FOREIGN KEY (objavio_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_rang_verzija CHECK (verzija_broj > 0),
  CONSTRAINT chk_rang_stanja CHECK (
    (status = 'NACRT' AND potvrdio_korisnik_id IS NULL AND potvrdjeno_at IS NULL
       AND objavio_korisnik_id IS NULL AND datum_objave IS NULL)
    OR (status = 'POTVRDJENA' AND potvrdio_korisnik_id IS NOT NULL AND potvrdjeno_at IS NOT NULL
       AND objavio_korisnik_id IS NULL AND datum_objave IS NULL)
    OR (status = 'OBJAVLJENA' AND potvrdio_korisnik_id IS NOT NULL AND potvrdjeno_at IS NOT NULL
       AND objavio_korisnik_id IS NOT NULL AND datum_objave IS NOT NULL
       AND datum_objave >= potvrdjeno_at)
  ),
  INDEX idx_rang_kategorija_tip_status (kategorija_id, tip_liste, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 24. Namjerno denormalizovan SNAPSHOT: ne mijenjati zbog kasnije promjene bodova.
CREATE TABLE rang_lista_stavke (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  rang_lista_id BIGINT UNSIGNED NOT NULL,
  prijava_id BIGINT UNSIGNED NOT NULL,
  pozicija INT UNSIGNED NOT NULL,
  ukupno_bodova DECIMAL(10,2) NOT NULL,
  ime_studenta_snapshot VARCHAR(100) NOT NULL,
  prezime_studenta_snapshot VARCHAR(100) NOT NULL,
  prosjek_snapshot DECIMAL(4,2) NULL,
  prihod_po_clanu_snapshot DECIMAL(14,2) NULL,
  godina_studija_snapshot TINYINT UNSIGNED NULL,
  vrijeme_zaprimanja_snapshot DATETIME(6) NOT NULL,
  status_stipendije ENUM('OSTVARIO','ISPOD_CRTE','ODBIJEN') NOT NULL,
  primijenjen_tie_breaker VARCHAR(100) NULL,
  CONSTRAINT uq_stavka_prijava UNIQUE (rang_lista_id, prijava_id),
  CONSTRAINT uq_stavka_pozicija UNIQUE (rang_lista_id, pozicija),
  CONSTRAINT fk_stavka_lista FOREIGN KEY (rang_lista_id) REFERENCES rang_liste(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_stavka_prijava FOREIGN KEY (prijava_id) REFERENCES prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_stavka_pozicija CHECK (pozicija > 0 AND ukupno_bodova >= 0),
  CONSTRAINT chk_stavka_prihod CHECK (prihod_po_clanu_snapshot IS NULL OR prihod_po_clanu_snapshot >= 0),
  INDEX idx_stavke_prijava (prijava_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 25. Zalba je na konkretnu OBJAVLJENU PRELIMINARNU verziju rang-liste.
CREATE TABLE zalbe (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  prijava_id BIGINT UNSIGNED NOT NULL,
  rang_lista_id BIGINT UNSIGNED NOT NULL,
  tekst_zalbe TEXT NOT NULL,
  prilog_pdf_id BIGINT UNSIGNED NULL,
  podnesena_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  status ENUM('PODNESENA','U_OBRADI','USVOJENA','ODBIJENA') NOT NULL DEFAULT 'PODNESENA',
  odluka_obrazlozenje TEXT NULL,
  rijesio_korisnik_id BIGINT UNSIGNED NULL,
  rijeseno_at DATETIME(6) NULL,
  CONSTRAINT uq_zalba_prijava_lista UNIQUE (prijava_id, rang_lista_id),
  CONSTRAINT fk_zalba_prijava FOREIGN KEY (prijava_id) REFERENCES prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_zalba_lista FOREIGN KEY (rang_lista_id) REFERENCES rang_liste(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_zalba_pdf FOREIGN KEY (prilog_pdf_id) REFERENCES pdf_datoteke(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_zalba_rijesio FOREIGN KEY (rijesio_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_zalba_tekst CHECK (CHAR_LENGTH(TRIM(tekst_zalbe)) > 0),
  CONSTRAINT chk_zalba_odluka CHECK (
    (status IN ('PODNESENA','U_OBRADI') AND odluka_obrazlozenje IS NULL
       AND rijesio_korisnik_id IS NULL AND rijeseno_at IS NULL)
    OR (status IN ('USVOJENA','ODBIJENA') AND odluka_obrazlozenje IS NOT NULL
       AND CHAR_LENGTH(TRIM(odluka_obrazlozenje)) > 0
       AND rijesio_korisnik_id IS NOT NULL AND rijeseno_at IS NOT NULL
       AND rijeseno_at >= podnesena_at)
  ),
  INDEX idx_zalba_status_at (status, podnesena_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 26. Verzije sablona sa imenovanim placeholderima (npr. {{student_ime}}).
CREATE TABLE sabloni_ugovora (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  naziv VARCHAR(150) NOT NULL,
  verzija SMALLINT UNSIGNED NOT NULL,
  sadrzaj_sablona LONGTEXT NOT NULL,
  aktivan BOOLEAN NOT NULL DEFAULT TRUE,
  kreirao_korisnik_id BIGINT UNSIGNED NOT NULL,
  kreirano_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_sablon_verzija UNIQUE (naziv, verzija),
  CONSTRAINT fk_sablon_admin FOREIGN KEY (kreirao_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_sablon_verzija CHECK (verzija >= 1 AND CHAR_LENGTH(TRIM(sadrzaj_sablona)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 27. Ugovor samo za studenta dobitnika na objavljenoj konacnoj listi.
CREATE TABLE ugovori (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  prijava_id BIGINT UNSIGNED NOT NULL,
  rang_stavka_id BIGINT UNSIGNED NOT NULL,
  sablon_id BIGINT UNSIGNED NOT NULL,
  broj_ugovora VARCHAR(100) NOT NULL,
  broj_racuna_snapshot VARCHAR(34) NOT NULL,
  naziv_banke_snapshot VARCHAR(150) NOT NULL,
  datum_ugovora DATE NOT NULL,
  datum_potpisivanja DATE NULL,
  mjesecni_iznos DECIMAL(12,2) NOT NULL,
  broj_rata SMALLINT UNSIGNED NOT NULL,
  ukupni_iznos DECIMAL(14,2) GENERATED ALWAYS AS (mjesecni_iznos * broj_rata) STORED,
  status ENUM('NACRT','PRIPREMLJEN','POTPISAN','AKTIVAN','ZAVRSEN','RASKINUT') NOT NULL DEFAULT 'NACRT',
  pdf_datoteka_id BIGINT UNSIGNED NULL,
  kreirao_korisnik_id BIGINT UNSIGNED NOT NULL,
  kreirano_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_ugovor_prijava UNIQUE (prijava_id),
  CONSTRAINT uq_ugovor_broj UNIQUE (broj_ugovora),
  CONSTRAINT uq_ugovor_rang_stavka UNIQUE (rang_stavka_id),
  CONSTRAINT uq_ugovor_pdf UNIQUE (pdf_datoteka_id),
  CONSTRAINT fk_ugovor_prijava FOREIGN KEY (prijava_id) REFERENCES prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_ugovor_stavka FOREIGN KEY (rang_stavka_id) REFERENCES rang_lista_stavke(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_ugovor_sablon FOREIGN KEY (sablon_id) REFERENCES sabloni_ugovora(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_ugovor_pdf FOREIGN KEY (pdf_datoteka_id) REFERENCES pdf_datoteke(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_ugovor_admin FOREIGN KEY (kreirao_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_ugovor_iznos CHECK (mjesecni_iznos > 0 AND broj_rata > 0),
  CONSTRAINT chk_ugovor_broj CHECK (CHAR_LENGTH(TRIM(broj_ugovora)) > 0),
  CONSTRAINT chk_ugovor_racun CHECK (CHAR_LENGTH(TRIM(broj_racuna_snapshot)) >= 10
    AND CHAR_LENGTH(TRIM(naziv_banke_snapshot)) > 0),
  CONSTRAINT chk_ugovor_datum CHECK (datum_potpisivanja IS NULL OR datum_potpisivanja >= datum_ugovora),
  CONSTRAINT chk_ugovor_status CHECK (
    status NOT IN ('POTPISAN','AKTIVAN','ZAVRSEN') OR datum_potpisivanja IS NOT NULL
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 28. Evidencija pojedinacnih rata isplate (po potrebi desktop modula).
CREATE TABLE isplate (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ugovor_id BIGINT UNSIGNED NOT NULL,
  broj_rate SMALLINT UNSIGNED NOT NULL,
  iznos DECIMAL(12,2) NOT NULL,
  planirano_za DATE NOT NULL,
  isplaceno_at DATETIME(6) NULL,
  status ENUM('PLANIRANA','DOSPJELA','ISPLACENA','OTKAZANA') NOT NULL DEFAULT 'PLANIRANA',
  referenca_transakcije VARCHAR(150) NULL,
  evidentirao_korisnik_id BIGINT UNSIGNED NOT NULL,
  CONSTRAINT uq_isplate_rata UNIQUE (ugovor_id, broj_rate),
  CONSTRAINT uq_isplate_transakcija UNIQUE (referenca_transakcije),
  CONSTRAINT fk_isplata_ugovor FOREIGN KEY (ugovor_id) REFERENCES ugovori(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_isplata_korisnik FOREIGN KEY (evidentirao_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_isplata_iznos CHECK (broj_rate > 0 AND iznos > 0),
  CONSTRAINT chk_isplata_status CHECK (
    (status = 'ISPLACENA' AND isplaceno_at IS NOT NULL)
    OR (status <> 'ISPLACENA' AND isplaceno_at IS NULL)
  ),
  INDEX idx_isplate_status_planirano (status, planirano_za)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 29. Notifikacije studentima/komisiji/administraciji.
CREATE TABLE notifikacije (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  korisnik_id BIGINT UNSIGNED NOT NULL,
  prijava_id BIGINT UNSIGNED NULL,
  konkurs_id BIGINT UNSIGNED NULL,
  naslov VARCHAR(200) NOT NULL,
  poruka TEXT NOT NULL,
  tip ENUM('SISTEM','PRIJAVA','DOPUNA','RANG_LISTA','ZALBA','UGOVOR') NOT NULL,
  procitano BOOLEAN NOT NULL DEFAULT FALSE,
  procitano_at DATETIME(6) NULL,
  kreirano_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_notif_korisnik FOREIGN KEY (korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_notif_prijava FOREIGN KEY (prijava_id) REFERENCES prijave(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_notif_konkurs FOREIGN KEY (konkurs_id) REFERENCES konkursi(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_notif_status CHECK (
    (procitano = FALSE AND procitano_at IS NULL) OR
    (procitano = TRUE AND procitano_at IS NOT NULL)
  ),
  INDEX idx_notif_korisnik_procitano (korisnik_id, procitano, kreirano_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 30. Postavke 1:0..1 uz korisnika (nije novi nalog).
CREATE TABLE korisnicke_postavke (
  korisnik_id BIGINT UNSIGNED PRIMARY KEY,
  tema ENUM('LIGHT','DARK') NOT NULL DEFAULT 'LIGHT',
  jezik CHAR(2) NOT NULL DEFAULT 'bs',
  stavki_po_stranici SMALLINT UNSIGNED NOT NULL DEFAULT 20,
  CONSTRAINT fk_postavke_korisnik FOREIGN KEY (korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT chk_postavke_limit CHECK (stavki_po_stranici BETWEEN 5 AND 200)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 31. Evidencija backup zadataka (ne sadrzi stvarni backup).
CREATE TABLE backup_evidencija (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pokrenuo_korisnik_id BIGINT UNSIGNED NOT NULL,
  naziv_fajla VARCHAR(255) NULL,
  storage_kljuc VARCHAR(500) NULL,
  velicina_bajta BIGINT UNSIGNED NULL,
  status ENUM('U_TOKU','USPJESNO','NEUSPJESNO') NOT NULL DEFAULT 'U_TOKU',
  napomena TEXT,
  pocetak_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  zavrsetak_at DATETIME(6) NULL,
  CONSTRAINT fk_backup_korisnik FOREIGN KEY (pokrenuo_korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_backup_velicina CHECK (velicina_bajta IS NULL OR velicina_bajta > 0),
  CONSTRAINT chk_backup_status CHECK (
    (status = 'U_TOKU' AND zavrsetak_at IS NULL)
    OR (status <> 'U_TOKU' AND zavrsetak_at IS NOT NULL AND zavrsetak_at >= pocetak_at)
  ),
  INDEX idx_backup_status_vrijeme (status, pocetak_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 33. Append-only revizijski trag.
-- Paznja: ne upisivati sirovi JMBG/IBAN, hash lozinke, PDF sadrzaj u JSON.
CREATE TABLE audit_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  korisnik_id BIGINT UNSIGNED NULL,
  uloga_snapshot VARCHAR(20) NULL,
  akcija ENUM('INSERT','UPDATE','DELETE','STATUS_CHANGE','SCORE_OVERRIDE',
              'DOCUMENT_DOWNLOAD','DOCUMENT_REVIEW','LOGIN','LOGIN_FAILED',
              'LOGOUT','RANK_PUBLISH','BACKUP','OTHER') NOT NULL,
  entitet VARCHAR(100) NOT NULL,
  entitet_id BIGINT UNSIGNED NULL,
  stara_vrijednost JSON NULL,
  nova_vrijednost JSON NULL,
  opis TEXT NULL,
  ip_adresa VARCHAR(45) NULL,
  vrijeme_akcije DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_audit_korisnik FOREIGN KEY (korisnik_id) REFERENCES korisnici(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_audit_entitet CHECK (CHAR_LENGTH(TRIM(entitet)) > 0),
  INDEX idx_audit_user_vrijeme (korisnik_id, vrijeme_akcije),
  INDEX idx_audit_entitet_id (entitet, entitet_id),
  INDEX idx_audit_vrijeme (vrijeme_akcije)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------
-- Sifrarnici neophodni za rad aplikacije (bez stvarnih licnih podataka).
-- ---------------------------------------------------------------
INSERT INTO uloge (sifra,naziv,opis) VALUES
 ('ADMIN','Administrator','Upravljanje konkursima, korisnicima i objavama'),
 ('KOMISIJA','Clan komisije','Provjera dodijeljenih prijava i bodovanje'),
 ('STUDENT','Student','Vlastiti profil, prijava, dokumenti i zalbe');

INSERT INTO izvori_bodovanja
 (sifra,naziv,tip_vrijednosti,nacin_dobavljanja,opis) VALUES
 ('PROSJEK_OCJENA','Prosjek ocjena','BROJ','SISTEM','Snapshot prijave'),
 ('PRIHOD_PO_CLANU','Prosjecni prihod po clanu','BROJ','SISTEM','Iz kucne liste i izvora prihoda'),
 ('BROJ_CLANOVA','Broj clanova domacinstva','BROJ','SISTEM','Iz kucne liste'),
 ('GODINA_STUDIJA','Godina studija','BROJ','SISTEM','Snapshot prijave'),
 ('CIKLUS_STUDIJA','Ciklus studija','TEKST','SISTEM','I, II, III ciklus'),
 ('INVALIDITET_STUDENTA','Stepen invaliditeta studenta','BROJ','UNOS','Postotak ili dokazani broj'),
 ('INVALIDITET_CLANA','Stepen invaliditeta clana domacinstva','BROJ','UNOS','Postotak ili dokazani broj'),
 ('BORACKA_KATEGORIJA','Boracka kategorija','BOOL','UNOS','Dokazuje se dokumentom'),
 ('BROJ_PREMINULIH_RODITELJA','Broj preminulih roditelja','BROJ','UNOS','0, 1 ili 2'),
 ('DEFICITARNO_ZANIMANJE','Deficitarno zanimanje','BOOL','UNOS','Potvrda zanimanja/smjera'),
 ('NAGRADE','Nagrade na takmicenjima','BROJ','UNOS','Broj priznatih nagrada');

INSERT INTO tipovi_dokumenata (sifra,naziv,opis) VALUES
 ('CIPS','Uvjerenje o prebivalistu (CIPS)',NULL),
 ('LICNA_KARTA','Kopija licne karte',NULL),
 ('POTVRDA_STUDIRANJA','Potvrda o redovnom studiranju','Prvi upis godine, bez obnavljanja'),
 ('UVJERENJE_OCJENE','Uvjerenje o polozenim ispitima i prosjeku','Studenti druge i visih godina'),
 ('SVJEDOCANSTVO','Svjedocanstvo razreda srednje skole','Vise razreda: redni_broj 1..4'),
 ('DIPLOMA_SREDNJA','Diploma o zavrsenoj srednjoj skoli','Za brucose'),
 ('KUCNA_LISTA','Ovjerena kucna lista',NULL),
 ('PLATNA_LISTA','Platna lista clana domacinstva',NULL),
 ('PENZIONI_CEK','Penzioni cek clana domacinstva',NULL),
 ('BIRO','Uvjerenje o nezaposlenosti',NULL),
 ('POREZNA','Uvjerenje Porezne uprave o prihodima',NULL),
 ('POTVRDA_SKOL','Potvrda o skolovanju brata/sestre',NULL),
 ('IZJAVA_NEPRIMANJE','Izjava o neprimanju druge javne stipendije',NULL),
 ('INVALIDITET','Rjesenje o invaliditetu',NULL),
 ('SMRTNI_LIST','Izvod iz maticne knjige umrlih','Roditelj'),
 ('BORACKI_STATUS','Uvjerenje o borackom statusu',NULL),
 ('NAGRADE','Dokaz o nagradama/takmicenjima',NULL);

-- ---------------------------------------------------------------
-- Pogled za dashboard i deterministicku statistiku prihoda.
-- COALESCE sumira osobe bez prihoda kao 0. Ne dupliramo agregate u prijave.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_prihodi_domacinstva AS
SELECT p.id AS prijava_id,
       COUNT(c.id) AS broj_clanova,
       COALESCE(SUM(pc.ukupno_po_clanu), 0.00) AS ukupni_prihod,
       CASE WHEN COUNT(c.id) = 0 THEN NULL
            ELSE ROUND(COALESCE(SUM(pc.ukupno_po_clanu),0.00)/COUNT(c.id),2)
       END AS prihod_po_clanu
FROM prijave p
LEFT JOIN clanovi_domacinstva c ON c.prijava_id = p.id
LEFT JOIN (
  SELECT clan_domacinstva_id, SUM(mjesecni_iznos) AS ukupno_po_clanu
  FROM primanja_clanova GROUP BY clan_domacinstva_id
) pc ON pc.clan_domacinstva_id = c.id
GROUP BY p.id;

CREATE OR REPLACE VIEW v_dashboard_prijave AS
SELECT p.konkurs_id, p.kategorija_id, p.status,
       p.fakultet_snapshot AS fakultet, p.prosjek_ocjena_snapshot AS prosjek_ocjena,
       COUNT(*) AS broj_prijava
FROM prijave p
GROUP BY p.konkurs_id, p.kategorija_id, p.status,
         p.fakultet_snapshot, p.prosjek_ocjena_snapshot;

-- Ende schema.sql. Izvrsiti triggers.sql nakon ovog fajla.
