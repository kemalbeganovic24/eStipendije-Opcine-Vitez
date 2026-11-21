-- ===============================================================
-- VITEZ eSTIPENDIJA: PROCEDURE I TRIGGERI (MySQL 8.0.16+)
-- Izvrsiti NAKON schema.sql. Koristiti mysql CLI / MySQL Workbench
-- s podrskom za DELIMITER. DATETIME(6) u UTC.
-- Validacija u bazi je druga linija odbrane, ne zamjena za RBAC API.
-- ===============================================================
USE e_stipendija;
SET time_zone = '+00:00';
DELIMITER $$

-- Centralna provera: prijava/kriterij pripadaju istom konkursu i kategoriji,
-- svi bodovi su unutar granica, a rucni potpisnik je dodijeljena komisija.
CREATE PROCEDURE sp_provjeri_bodovanje(
  IN p_prijava BIGINT UNSIGNED,
  IN p_kriterij BIGINT UNSIGNED,
  IN p_automatski DECIMAL(8,2),
  IN p_korigovani DECIMAL(8,2),
  IN p_konacni DECIMAL(8,2),
  IN p_rucno BOOLEAN,
  IN p_korigovao BIGINT UNSIGNED,
  IN p_nova_stavka BOOLEAN
)
BEGIN
  DECLARE v_konkurs_p BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_kategorija_p BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_konkurs_k BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_kategorija_k BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_max DECIMAL(8,2) DEFAULT NULL;
  DECLARE v_aktivan BOOLEAN DEFAULT FALSE;
  DECLARE v_dodijeljen INT DEFAULT 0;

  SELECT p.konkurs_id, p.kategorija_id, k.konkurs_id, k.kategorija_id,
         k.max_bodova, k.aktivan
    INTO v_konkurs_p, v_kategorija_p, v_konkurs_k, v_kategorija_k, v_max, v_aktivan
  FROM prijave p JOIN kriteriji_bodovanja k ON k.id = p_kriterij
  WHERE p.id = p_prijava;

  IF v_konkurs_p IS NULL OR v_konkurs_k IS NULL OR v_konkurs_p <> v_konkurs_k
     OR (v_kategorija_k IS NOT NULL AND v_kategorija_k <> v_kategorija_p) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Kriterij nije u konkursu/kategoriji prijave';
  END IF;
  IF p_nova_stavka AND NOT v_aktivan THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Neaktivan kriterij ne moze dobiti nove bodove';
  END IF;
  IF p_automatski IS NULL OR p_konacni IS NULL OR p_automatski < 0
     OR p_konacni < 0 OR p_automatski > v_max OR p_konacni > v_max
     OR (p_korigovani IS NOT NULL AND (p_korigovani < 0 OR p_korigovani > v_max)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bodovi su van [0, max_bodova]';
  END IF;
  IF p_rucno THEN
    SELECT COUNT(*) INTO v_dodijeljen
    FROM dodjele_prijava d
    JOIN korisnici u ON u.id = d.komisija_korisnik_id AND u.aktivan = TRUE
    JOIN uloge r ON r.id = u.uloga_id AND r.sifra = 'KOMISIJA'
    WHERE d.prijava_id = p_prijava AND d.komisija_korisnik_id = p_korigovao
      AND d.status IN ('DODIJELJENA','U_OBRADI');
    IF v_dodijeljen = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rucnu korekciju moze unijeti samo dodijeljeni clan komisije';
    END IF;
  END IF;
END$$

-- Izdavanje djelovodnog broja sigurno je pri istovremenim zahtjevima.
-- Brojac je poseban red; FOR UPDATE serijalizuje dodjelu brojeva.
CREATE PROCEDURE sp_izdaj_protokol(
  IN p_konkurs BIGINT UNSIGNED,
  OUT p_broj VARCHAR(50)
)
BEGIN
  DECLARE v_redni BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_godina CHAR(4) DEFAULT NULL;
  INSERT IGNORE INTO brojaci_protokola (konkurs_id, posljednji_broj)
    VALUES (p_konkurs, 0);
  SELECT posljednji_broj INTO v_redni FROM brojaci_protokola
    WHERE konkurs_id = p_konkurs FOR UPDATE;
  SELECT LEFT(akademska_godina, 4) INTO v_godina
    FROM konkursi WHERE id = p_konkurs;
  SET v_redni = v_redni + 1;
  UPDATE brojaci_protokola SET posljednji_broj = v_redni
    WHERE konkurs_id = p_konkurs;
  -- ID konkursa u broju garantuje globalnu jedinstvenost i ako dva
  -- konkursa iste akademske godine koriste odvojene brojače.
  SET p_broj = CONCAT('STIP-',v_godina,'-K',p_konkurs,'-',
                     LPAD(v_redni, GREATEST(6, CHAR_LENGTH(v_redni)), '0'));
END$$

-- Pravila za skalu: samo tip SKALA, nepreklapajuci zatvoreni intervali,
-- bez izmjena ako je kriterij vec koristen pri bodovanju.
CREATE PROCEDURE sp_provjeri_skalu(
  IN p_kriterij BIGINT UNSIGNED,
  IN p_preskoci_id BIGINT UNSIGNED,
  IN p_od DECIMAL(14,4),
  IN p_do DECIMAL(14,4),
  IN p_bodovi DECIMAL(8,2)
)
BEGIN
  DECLARE v_tip VARCHAR(12) DEFAULT NULL;
  DECLARE v_max DECIMAL(8,2) DEFAULT NULL;
  DECLARE v_koristen INT DEFAULT 0;
  DECLARE v_preklopi INT DEFAULT 0;
  SELECT tip_kriterija, max_bodova INTO v_tip,v_max
    FROM kriteriji_bodovanja WHERE id = p_kriterij FOR UPDATE;
  IF v_tip IS NULL OR v_tip <> 'SKALA' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Skale su dozvoljene samo za SKALA kriterij';
  END IF;
  SELECT COUNT(*) INTO v_koristen FROM bodovi_prijave WHERE kriterij_id=p_kriterij;
  IF v_koristen > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nije dozvoljena promjena skale koja je vec koristena';
  END IF;
  IF p_od > p_do OR p_bodovi < 0 OR p_bodovi > v_max THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Neispravne granice ili bodovi skale';
  END IF;
  SELECT COUNT(*) INTO v_preklopi FROM skale_kriterija
    WHERE kriterij_id = p_kriterij
      AND (p_preskoci_id IS NULL OR id <> p_preskoci_id)
      AND od_vrijednost <= p_do AND do_vrijednost >= p_od;
  IF v_preklopi > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Preklapanje intervala skale';
  END IF;
END$$

-- Provjera dodjele: samo aktivan clan komisije imenovan na konkurs
-- i samo aktivan ADMIN koji dodjeljuje; nakon zatvaranja konkursa.
CREATE PROCEDURE sp_provjeri_dodjelu(
  IN p_prijava BIGINT UNSIGNED,
  IN p_komisija BIGINT UNSIGNED,
  IN p_admin BIGINT UNSIGNED
)
BEGIN
  DECLARE v_konkurs BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_kstatus VARCHAR(20) DEFAULT NULL;
  DECLARE v_prijava_status VARCHAR(25) DEFAULT NULL;
  DECLARE v_ok INT DEFAULT 0;
  DECLARE v_admin_ok INT DEFAULT 0;
  SELECT p.konkurs_id, k.status, p.status
    INTO v_konkurs, v_kstatus, v_prijava_status
  FROM prijave p JOIN konkursi k ON k.id=p.konkurs_id WHERE p.id=p_prijava;
  IF v_konkurs IS NULL OR v_kstatus NOT IN ('ZATVOREN','OBJAVLJEN')
     OR v_prijava_status IN ('DRAFT','POVUCENA') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dodjela moguca tek nakon zatvaranja konkursa';
  END IF;
  SELECT COUNT(*) INTO v_ok
  FROM clanovi_komisije_konkursa ck
  JOIN korisnici u ON u.id=ck.korisnik_id AND u.aktivan = TRUE
  JOIN uloge r ON r.id=u.uloga_id AND r.sifra='KOMISIJA'
  WHERE ck.konkurs_id=v_konkurs AND ck.korisnik_id=p_komisija AND ck.aktivan=TRUE;
  SELECT COUNT(*) INTO v_admin_ok
  FROM korisnici u JOIN uloge r ON r.id=u.uloga_id
  WHERE u.id=p_admin AND u.aktivan=TRUE AND r.sifra='ADMIN';
  IF v_ok=0 OR v_admin_ok=0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Neispravno imenovanje komisije ili administrator';
  END IF;
END$$

-- Pravila za datoteku dokumenta / odnos prema prijavi / verziju.
CREATE PROCEDURE sp_provjeri_upload(
  IN p_prijava BIGINT UNSIGNED,
  IN p_zahtjev BIGINT UNSIGNED,
  IN p_clan BIGINT UNSIGNED,
  IN p_redni SMALLINT UNSIGNED,
  IN p_verzija SMALLINT UNSIGNED,
  IN p_pdf BIGINT UNSIGNED
)
BEGIN
  DECLARE v_konkurs BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_kat BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_godina TINYINT UNSIGNED DEFAULT NULL;
  DECLARE v_ciklus VARCHAR(4) DEFAULT NULL;
  DECLARE v_status VARCHAR(30) DEFAULT NULL;
  DECLARE v_rok DATETIME(6) DEFAULT NULL;
  DECLARE v_rok_dopune DATETIME(6) DEFAULT NULL;
  DECLARE v_z_konkurs BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_z_kat BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_z_ciklus VARCHAR(4) DEFAULT NULL;
  DECLARE v_z_god_od TINYINT UNSIGNED DEFAULT NULL;
  DECLARE v_z_god_do TINYINT UNSIGNED DEFAULT NULL;
  DECLARE v_cilj VARCHAR(30) DEFAULT NULL;
  DECLARE v_student_korisnik BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_uploader BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_max_bajta BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_velicina BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_status_konkursa VARCHAR(20) DEFAULT NULL;
  DECLARE v_pripada INT DEFAULT 0;
  DECLARE v_prethodna SMALLINT UNSIGNED DEFAULT 0;

  SELECT p.konkurs_id,p.kategorija_id,p.godina_studija_snapshot,
         p.ciklus_studija_snapshot,p.status,k.datum_do,k.rok_dopune,s.korisnik_id
    INTO v_konkurs,v_kat,v_godina,v_ciklus,v_status,v_rok,v_rok_dopune,v_student_korisnik
  FROM prijave p JOIN konkursi k ON k.id=p.konkurs_id
  JOIN studenti s ON s.id=p.student_id
  WHERE p.id = p_prijava;
  SELECT konkurs_id,kategorija_id,cilkus.ciklus_studija,cilkus.godina_od,
         cilkus.godina_do,cilkus.odnosi_se_na
    INTO v_z_konkurs,v_z_kat,v_z_ciklus,v_z_god_od,v_z_god_do,v_cilj
  FROM zahtjevi_dokumenata cilkus WHERE cilkus.id = p_zahtjev;
  SELECT postavio_korisnik_id,velicina_bajta INTO v_uploader,v_velicina
    FROM pdf_datoteke WHERE id=p_pdf;
  SELECT maksimalno_bajta INTO v_max_bajta FROM zahtjevi_dokumenata WHERE id=p_zahtjev;
  SELECT status INTO v_status_konkursa FROM konkursi WHERE id=v_konkurs;

  IF v_konkurs IS NULL OR v_z_konkurs <> v_konkurs
     OR (v_z_kat IS NOT NULL AND v_z_kat <> v_kat)
     OR (v_z_god_od IS NOT NULL AND (v_godina IS NULL OR v_godina < v_z_god_od))
     OR (v_z_god_do IS NOT NULL AND (v_godina IS NULL OR v_godina > v_z_god_do))
     OR (v_z_ciklus IS NOT NULL AND NOT (v_z_ciklus <=> v_ciklus)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Zahtjev PDF dokumenta ne vrijedi za ovu prijavu';
  END IF;
  IF v_max_bajta IS NOT NULL AND v_velicina > v_max_bajta THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PDF prelazi maksimalnu velicinu dokumenta';
  END IF;
  IF v_uploader <> v_student_korisnik THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dokument mora postaviti vlasnik prijave';
  END IF;
  IF v_cilj = 'STUDENT' AND p_clan IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dokument studenta ne moze imati clana domacinstva';
  END IF;
  IF v_cilj <> 'STUDENT' AND p_clan IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dokument mora navesti clana domacinstva';
  END IF;
  IF p_clan IS NOT NULL THEN
    SELECT COUNT(*) INTO v_pripada FROM clanovi_domacinstva
      WHERE id=p_clan AND prijava_id=p_prijava;
    IF v_pripada = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Clan domacinstva nije iz ove prijave';
    END IF;
  END IF;
  IF NOT (
    ((v_status = 'DOPUNA_TRAZENA') AND v_rok_dopune IS NOT NULL
       AND UTC_TIMESTAMP(6) <= v_rok_dopune)
    OR (v_status IN ('DRAFT','PODNESENA') AND v_status_konkursa = 'OTVOREN'
        AND UTC_TIMESTAMP(6) <= v_rok)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rok za dostavljanje PDF dokumenta je istekao';
  END IF;
  SELECT COALESCE(MAX(verzija),0) INTO v_prethodna
  FROM dokumenti_prijave
  WHERE prijava_id=p_prijava AND zahtjev_dokumenta_id=p_zahtjev
    AND IFNULL(clan_domacinstva_id,0)=IFNULL(p_clan,0) AND redni_broj=p_redni;
  IF p_verzija <> v_prethodna + 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Verzija mora biti prethodna verzija + 1';
  END IF;
END$$

-- Pomocni postupak za provjeru prava onoga ko verifikuje dokument.
CREATE PROCEDURE sp_provjeri_pregled_dokumenta(
  IN p_prijava BIGINT UNSIGNED,
  IN p_komisija BIGINT UNSIGNED
)
BEGIN
  DECLARE v_ok INT DEFAULT 0;
  SELECT COUNT(*) INTO v_ok FROM dodjele_prijava d
  JOIN korisnici u ON u.id=d.komisija_korisnik_id AND u.aktivan=TRUE
  JOIN uloge r ON r.id=u.uloga_id AND r.sifra='KOMISIJA'
  WHERE d.prijava_id=p_prijava AND d.komisija_korisnik_id=p_komisija
    AND d.status IN ('DODIJELJENA','U_OBRADI');
  IF v_ok=0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dokument moze verifikovati samo dodijeljeni clan komisije';
  END IF;
END$$

-- Kriterij mora odgovarati tipu podatka; ne izvrsavamo proizvoljan SQL.
CREATE PROCEDURE sp_provjeri_izvor_kriterija(
  IN p_izvor VARCHAR(45), IN p_tip VARCHAR(10)
)
BEGIN
  DECLARE v_tip VARCHAR(12) DEFAULT NULL;
  SELECT tip_vrijednosti INTO v_tip FROM izvori_bodovanja WHERE sifra=p_izvor;
  IF v_tip IS NULL OR (p_tip='DA_NE' AND v_tip<>'BOOL')
     OR (p_tip IN ('FORMULA','SKALA') AND v_tip<>'BROJ') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Tip bodovanja ne odgovara izvoru podatka';
  END IF;
END$$

-- Izmjene podataka domacinstva i posebnih cinjenica samo tokom nacrta
-- ili pravovremene, sluzbeno zatrazene dopune.
CREATE PROCEDURE sp_provjeri_izmjenu_podataka(IN p_prijava BIGINT UNSIGNED)
BEGIN
  DECLARE v_status VARCHAR(30) DEFAULT NULL;
  DECLARE v_rok DATETIME(6) DEFAULT NULL;
  DECLARE v_dopuna DATETIME(6) DEFAULT NULL;
  DECLARE v_otvor DATETIME(6) DEFAULT NULL;
  SELECT p.status,k.datum_od,k.datum_do,k.rok_dopune
    INTO v_status,v_otvor,v_rok,v_dopuna
  FROM prijave p JOIN konkursi k ON k.id=p.konkurs_id WHERE p.id=p_prijava;
  IF v_status IS NULL OR NOT (
      (v_status='DRAFT' AND UTC_TIMESTAMP(6)<=v_rok)
      OR (v_status='DOPUNA_TRAZENA' AND v_dopuna IS NOT NULL
           AND UTC_TIMESTAMP(6)<=v_dopuna)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Podatke prijave mozete mijenjati samo u nacrtu ili roku dopune';
  END IF;
END$$

-- Provjera tipa vrijednosti posebnih cinjenica (ostali izvori su izvedeni).
CREATE PROCEDURE sp_provjeri_cinjenicu(
  IN p_izvor VARCHAR(45),
  IN p_broj DECIMAL(14,4),
  IN p_bool BOOLEAN,
  IN p_tekst VARCHAR(255)
)
BEGIN
  DECLARE v_tip VARCHAR(12) DEFAULT NULL;
  DECLARE v_nacin VARCHAR(12) DEFAULT NULL;
  SELECT tip_vrijednosti,nacin_dobavljanja INTO v_tip,v_nacin
    FROM izvori_bodovanja WHERE sifra=p_izvor;
  IF v_nacin <> 'UNOS' OR
     (v_tip='BROJ' AND (p_broj IS NULL OR p_bool IS NOT NULL OR p_tekst IS NOT NULL)) OR
     (v_tip='BOOL' AND (p_bool IS NULL OR p_broj IS NOT NULL OR p_tekst IS NOT NULL)) OR
     (v_tip='TEKST' AND (p_tekst IS NULL OR p_broj IS NOT NULL OR p_bool IS NOT NULL)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pogresan tip ili izvor posebne cinjenice';
  END IF;
END$$

CREATE TRIGGER trg_uslov_bi BEFORE INSERT ON uslovi_kategorija FOR EACH ROW
BEGIN
  DECLARE v_tip VARCHAR(10) DEFAULT NULL;
  IF EXISTS(SELECT 1 FROM prijave WHERE kategorija_id=NEW.kategorija_id AND status<>'DRAFT') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Uslovi kategorije se ne dodaju nakon prijava';
  END IF;
  SELECT tip_vrijednosti INTO v_tip FROM izvori_bodovanja WHERE sifra=NEW.izvor_sifra;
  IF (v_tip='BROJ' AND NEW.vrijednost_broj IS NULL)
     OR (v_tip='BOOL' AND (NEW.vrijednost_bool IS NULL OR NEW.operator_poredjenja NOT IN('EQ','NE')))
     OR (v_tip='TEKST' AND (NEW.vrijednost_tekst IS NULL OR NEW.operator_poredjenja NOT IN('EQ','NE'))) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Uslov kategorije: pogresan tip ili operator';
  END IF;
END$$
CREATE TRIGGER trg_uslov_bu BEFORE UPDATE ON uslovi_kategorija FOR EACH ROW
BEGIN
  DECLARE v_tip VARCHAR(10) DEFAULT NULL;
  IF EXISTS(SELECT 1 FROM prijave WHERE kategorija_id=OLD.kategorija_id AND status<>'DRAFT') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Uslovi kategorije su zakljucani nakon prijava';
  END IF;
  SELECT tip_vrijednosti INTO v_tip FROM izvori_bodovanja WHERE sifra=NEW.izvor_sifra;
  IF (v_tip='BROJ' AND NEW.vrijednost_broj IS NULL)
     OR (v_tip='BOOL' AND (NEW.vrijednost_bool IS NULL OR NEW.operator_poredjenja NOT IN('EQ','NE')))
     OR (v_tip='TEKST' AND (NEW.vrijednost_tekst IS NULL OR NEW.operator_poredjenja NOT IN('EQ','NE'))) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Uslov kategorije: pogresan tip ili operator';
  END IF;
END$$

CREATE TRIGGER trg_uslov_bd BEFORE DELETE ON uslovi_kategorija FOR EACH ROW
BEGIN
  IF EXISTS(SELECT 1 FROM prijave WHERE kategorija_id=OLD.kategorija_id AND status<>'DRAFT') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Uslovi kategorije se ne brisu nakon prijava';
  END IF;
END$$
CREATE TRIGGER trg_kategorija_bu BEFORE UPDATE ON kategorije_stipendija FOR EACH ROW
BEGIN
  IF EXISTS(SELECT 1 FROM prijave WHERE kategorija_id=OLD.id AND status<>'DRAFT') AND (
      NOT (NEW.naziv <=> OLD.naziv)
      OR NOT (NEW.opis <=> OLD.opis)
      OR NOT (NEW.kvota_stipendija <=> OLD.kvota_stipendija)
      OR NOT (NEW.min_prosjek <=> OLD.min_prosjek)
      OR NOT (NEW.aktivna <=> OLD.aktivna)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Kategorija sa podnesenim prijavama je zakljucana';
  END IF;
END$$

-- ----------------------------------------------------------------
-- Korisnicke uloge i clanstvo u komisiji
-- ----------------------------------------------------------------
CREATE TRIGGER trg_student_bi BEFORE INSERT ON studenti FOR EACH ROW
BEGIN
  DECLARE v_ok INT DEFAULT 0;
  SELECT COUNT(*) INTO v_ok FROM korisnici u JOIN uloge r ON r.id=u.uloga_id
    WHERE u.id=NEW.korisnik_id AND r.sifra='STUDENT';
  IF v_ok=0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Profil studenta trazi korisnika s ulogom STUDENT';
  END IF;
END$$

CREATE TRIGGER trg_korisnici_bu BEFORE UPDATE ON korisnici FOR EACH ROW
BEGIN
  DECLARE v_nova_uloga VARCHAR(20) DEFAULT NULL;
  SELECT sifra INTO v_nova_uloga FROM uloge WHERE id=NEW.uloga_id;
  IF EXISTS(SELECT 1 FROM studenti WHERE korisnik_id=OLD.id)
     AND v_nova_uloga <> 'STUDENT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Korisnik sa studentskim profilom mora ostati STUDENT';
  END IF;
  IF EXISTS(SELECT 1 FROM clanovi_komisije_konkursa WHERE korisnik_id=OLD.id)
     AND v_nova_uloga <> 'KOMISIJA' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Imenovan clan komisije mora ostati KOMISIJA';
  END IF;
END$$

CREATE TRIGGER trg_clan_komisije_bi BEFORE INSERT ON clanovi_komisije_konkursa FOR EACH ROW
BEGIN
  DECLARE v_ok INT DEFAULT 0;
  SELECT COUNT(*) INTO v_ok FROM korisnici u JOIN uloge r ON r.id=u.uloga_id
   WHERE u.id=NEW.korisnik_id AND u.aktivan=TRUE AND r.sifra='KOMISIJA';
  IF v_ok=0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Na konkurs se moze imenovati samo aktivan clan komisije';
  END IF;
END$$

CREATE TRIGGER trg_student_bu BEFORE UPDATE ON studenti FOR EACH ROW
BEGIN
  IF NEW.korisnik_id <> OLD.korisnik_id OR NEW.jmbg <> OLD.jmbg THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Identitet studentskog profila je nepromjenljiv';
  END IF;
END$$

-- ----------------------------------------------------------------
-- Prijave: prvo DRAFT, zatim server daje broj i vrijeme u transakciji.
-- Ne vjerovati timestampu koji posalje browser / desktop klijent.
-- ----------------------------------------------------------------
CREATE TRIGGER trg_prijava_bi BEFORE INSERT ON prijave FOR EACH ROW
BEGIN
  IF NEW.status <> 'DRAFT' OR NEW.broj_protokola IS NOT NULL
     OR NEW.vrijeme_zaprimanja IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nova prijava prvo mora biti DRAFT';
  END IF;
END$$

CREATE TRIGGER trg_prijava_bu BEFORE UPDATE ON prijave FOR EACH ROW
BEGIN
  DECLARE v_start DATETIME(6) DEFAULT NULL;
  DECLARE v_end DATETIME(6) DEFAULT NULL;
  DECLARE v_status VARCHAR(20) DEFAULT NULL;
  DECLARE v_rok DATETIME(6) DEFAULT NULL;
  DECLARE v_broj VARCHAR(50) DEFAULT NULL;
  DECLARE v_clanovi INT DEFAULT 0;
  DECLARE v_now DATETIME(6);
  SET v_now = UTC_TIMESTAMP(6);
  IF NEW.id <> OLD.id OR NEW.student_id <> OLD.student_id
     OR NEW.konkurs_id <> OLD.konkurs_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nije dozvoljena promjena identiteta prijave';
  END IF;
  IF OLD.status <> 'DRAFT' AND NEW.kategorija_id <> OLD.kategorija_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Kategorija podnesene prijave je nepromjenljiva';
  END IF;
  IF OLD.status NOT IN ('DRAFT','DOPUNA_TRAZENA') AND (
      NOT (NEW.fakultet_snapshot <=> OLD.fakultet_snapshot)
      OR NOT (NEW.univerzitet_snapshot <=> OLD.univerzitet_snapshot)
      OR NOT (NEW.smjer_snapshot <=> OLD.smjer_snapshot)
      OR NOT (NEW.ciklus_studija_snapshot <=> OLD.ciklus_studija_snapshot)
      OR NOT (NEW.godina_studija_snapshot <=> OLD.godina_studija_snapshot)
      OR NOT (NEW.prosjek_ocjena_snapshot <=> OLD.prosjek_ocjena_snapshot)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Podaci o studiju zakljucani su nakon podnosenja';
  END IF;
  IF OLD.status = 'DOPUNA_TRAZENA' AND (
      NOT (NEW.fakultet_snapshot <=> OLD.fakultet_snapshot)
      OR NOT (NEW.univerzitet_snapshot <=> OLD.univerzitet_snapshot)
      OR NOT (NEW.smjer_snapshot <=> OLD.smjer_snapshot)
      OR NOT (NEW.ciklus_studija_snapshot <=> OLD.ciklus_studija_snapshot)
      OR NOT (NEW.godina_studija_snapshot <=> OLD.godina_studija_snapshot)
      OR NOT (NEW.prosjek_ocjena_snapshot <=> OLD.prosjek_ocjena_snapshot)
  ) THEN
    SELECT rok_dopune INTO v_rok FROM konkursi WHERE id=NEW.konkurs_id;
    IF v_rok IS NULL OR v_now > v_rok THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rok za dopunu studijskih podataka je istekao';
    END IF;
  END IF;
  IF OLD.status = 'DRAFT' AND NEW.status='PODNESENA' THEN
    SELECT datum_od,datum_do,status INTO v_start,v_end,v_status
      FROM konkursi WHERE id=NEW.konkurs_id;
    IF v_status <> 'OTVOREN' OR v_now < v_start OR v_now > v_end THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Prijava nije podnesena u roku otvorenog konkursa';
    END IF;
    IF NEW.fakultet_snapshot IS NULL OR NEW.godina_studija_snapshot IS NULL
       OR NEW.ciklus_studija_snapshot IS NULL OR NEW.prosjek_ocjena_snapshot IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nedostaju obavezni obrazovni podaci';
    END IF;
    SELECT COUNT(*) INTO v_clanovi FROM clanovi_domacinstva
      WHERE prijava_id=NEW.id AND je_podnosilac=TRUE;
    IF v_clanovi = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Kucna lista mora sadrzati podnosioca';
    END IF;
    CALL sp_izdaj_protokol(NEW.konkurs_id,v_broj);
    SET NEW.broj_protokola = v_broj;
    SET NEW.vrijeme_zaprimanja = v_now;
  ELSE
    IF NEW.broj_protokola IS NULL AND OLD.status <> 'DRAFT' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ne moze se ukloniti broj protokola';
    END IF;
    IF NOT (NEW.broj_protokola <=> OLD.broj_protokola)
       OR NOT (NEW.vrijeme_zaprimanja <=> OLD.vrijeme_zaprimanja) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Protokol i vrijeme zaprimanja ne mogu se mijenjati';
    END IF;
  END IF;
  IF OLD.status='DRAFT' AND NEW.status NOT IN('DRAFT','PODNESENA') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='DRAFT prelazi samo u PODNESENA';
  END IF;
  IF OLD.status <> 'DRAFT' AND NEW.status='DRAFT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Podnesena prijava se ne moze vratiti u DRAFT';
  END IF;
  IF OLD.status='POVUCENA' AND NEW.status <> 'POVUCENA' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Povucena prijava se ne moze aktivirati';
  END IF;
END$$

CREATE TRIGGER trg_prijava_bd BEFORE DELETE ON prijave FOR EACH ROW
BEGIN
  IF OLD.status <> 'DRAFT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Podnesene prijave se ne brisu';
  END IF;
END$$

CREATE TRIGGER trg_prijava_au AFTER UPDATE ON prijave FOR EACH ROW
BEGIN
  DECLARE v_korisnik BIGINT UNSIGNED DEFAULT NULL;
  IF OLD.status <> NEW.status THEN
    -- Sistem ne zna autenticiranog AKTERA izmjene iz samog FK-a studenta.
    -- Zato upisujemo sistemski događaj; servis zasebno biljezi stvarnog aktera.
    SET v_korisnik = NULL;
    INSERT INTO audit_log(korisnik_id,akcija,entitet,entitet_id,stara_vrijednost,nova_vrijednost,opis)
    VALUES(v_korisnik,'STATUS_CHANGE','prijave',NEW.id,
           JSON_OBJECT('status',OLD.status),
           JSON_OBJECT('status',NEW.status,'broj_protokola',NEW.broj_protokola),
           'Automatski statusni zapis; servis mora zasebno evidentirati stvarnog aktera');
  END IF;
END$$

-- ----------------------------------------------------------------
-- Dodjela prijave i prava pristupa.
-- ----------------------------------------------------------------
CREATE TRIGGER trg_dodjela_bi BEFORE INSERT ON dodjele_prijava FOR EACH ROW
BEGIN
  CALL sp_provjeri_dodjelu(NEW.prijava_id,NEW.komisija_korisnik_id,NEW.dodijelio_korisnik_id);
END$$
CREATE TRIGGER trg_dodjela_bu BEFORE UPDATE ON dodjele_prijava FOR EACH ROW
BEGIN
  IF NEW.prijava_id<>OLD.prijava_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nije dozvoljen premjestaj dodjele na drugu prijavu';
  END IF;
  IF NEW.komisija_korisnik_id <> OLD.komisija_korisnik_id THEN
    CALL sp_provjeri_dodjelu(NEW.prijava_id,NEW.komisija_korisnik_id,NEW.dodijelio_korisnik_id);
  END IF;
END$$
CREATE TRIGGER trg_dodjela_au AFTER UPDATE ON dodjele_prijava FOR EACH ROW
BEGIN
  IF NEW.komisija_korisnik_id <> OLD.komisija_korisnik_id OR NEW.status <> OLD.status THEN
    INSERT INTO audit_log(korisnik_id,akcija,entitet,entitet_id,stara_vrijednost,nova_vrijednost)
    VALUES(NEW.dodijelio_korisnik_id,'UPDATE','dodjele_prijava',NEW.id,
      JSON_OBJECT('clan',OLD.komisija_korisnik_id,'status',OLD.status),
      JSON_OBJECT('clan',NEW.komisija_korisnik_id,'status',NEW.status));
  END IF;
END$$

-- ----------------------------------------------------------------
-- Kucna lista / prihodi / posebne cinjenice: ogranicenje izmjena.
-- ----------------------------------------------------------------
CREATE TRIGGER trg_clan_dom_bi BEFORE INSERT ON clanovi_domacinstva FOR EACH ROW
BEGIN
  CALL sp_provjeri_izmjenu_podataka(NEW.prijava_id);
END$$
CREATE TRIGGER trg_clan_dom_bu BEFORE UPDATE ON clanovi_domacinstva FOR EACH ROW
BEGIN
  IF NEW.prijava_id <> OLD.prijava_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Clan ne prelazi na drugu prijavu';
  END IF;
  CALL sp_provjeri_izmjenu_podataka(OLD.prijava_id);
END$$
CREATE TRIGGER trg_clan_dom_bd BEFORE DELETE ON clanovi_domacinstva FOR EACH ROW
BEGIN
  CALL sp_provjeri_izmjenu_podataka(OLD.prijava_id);
END$$
CREATE TRIGGER trg_primanja_bi BEFORE INSERT ON primanja_clanova FOR EACH ROW
BEGIN
  DECLARE v_prijava BIGINT UNSIGNED DEFAULT NULL;
  SELECT prijava_id INTO v_prijava FROM clanovi_domacinstva WHERE id=NEW.clan_domacinstva_id;
  CALL sp_provjeri_izmjenu_podataka(v_prijava);
END$$
CREATE TRIGGER trg_primanja_bu BEFORE UPDATE ON primanja_clanova FOR EACH ROW
BEGIN
  DECLARE v_prijava BIGINT UNSIGNED DEFAULT NULL;
  IF NEW.clan_domacinstva_id<>OLD.clan_domacinstva_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Prihod ne prelazi drugom clanu';
  END IF;
  SELECT prijava_id INTO v_prijava FROM clanovi_domacinstva WHERE id=OLD.clan_domacinstva_id;
  CALL sp_provjeri_izmjenu_podataka(v_prijava);
END$$
CREATE TRIGGER trg_primanja_bd BEFORE DELETE ON primanja_clanova FOR EACH ROW
BEGIN
  DECLARE v_prijava BIGINT UNSIGNED DEFAULT NULL;
  SELECT prijava_id INTO v_prijava FROM clanovi_domacinstva WHERE id=OLD.clan_domacinstva_id;
  CALL sp_provjeri_izmjenu_podataka(v_prijava);
END$$
CREATE TRIGGER trg_cinjenica_bi BEFORE INSERT ON cinjenice_prijave FOR EACH ROW
BEGIN
  CALL sp_provjeri_izmjenu_podataka(NEW.prijava_id);
  CALL sp_provjeri_cinjenicu(NEW.izvor_sifra,NEW.vrijednost_broj,
                            NEW.vrijednost_bool,NEW.vrijednost_tekst);
  IF NEW.verifikovano THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Student ne moze sam verifikovati cinjenicu';
  END IF;
END$$
CREATE TRIGGER trg_cinjenica_bu BEFORE UPDATE ON cinjenice_prijave FOR EACH ROW
BEGIN
  IF NEW.prijava_id<>OLD.prijava_id OR NEW.izvor_sifra<>OLD.izvor_sifra THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Identitet cinjenice je nepromjenljiv';
  END IF;
  IF OLD.verifikovano THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Verifikovana cinjenica je nepromjenljiva';
  END IF;
  CALL sp_provjeri_cinjenicu(NEW.izvor_sifra,NEW.vrijednost_broj,
                            NEW.vrijednost_bool,NEW.vrijednost_tekst);
  IF NOT OLD.verifikovano AND NEW.verifikovano THEN
    CALL sp_provjeri_pregled_dokumenta(NEW.prijava_id,NEW.verifikovao_korisnik_id);
    SET NEW.verifikovano_at=UTC_TIMESTAMP(6);
  ELSE
    CALL sp_provjeri_izmjenu_podataka(NEW.prijava_id);
  END IF;
END$$
CREATE TRIGGER trg_cinjenica_bd BEFORE DELETE ON cinjenice_prijave FOR EACH ROW
BEGIN
  IF OLD.verifikovano THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Verifikovana cinjenica se ne brise';
  END IF;
  CALL sp_provjeri_izmjenu_podataka(OLD.prijava_id);
END$$

-- Metapodaci PDF fajla se ne mijenjaju: svaki novi upload = novi red.
CREATE TRIGGER trg_pdf_bu BEFORE UPDATE ON pdf_datoteke FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='PDF datoteka je nepromjenljiva; otvorite novu verziju';
END$$

-- ----------------------------------------------------------------
-- PDF: verzionisanje i neizmjenjiva historija provjere.
-- ----------------------------------------------------------------
CREATE TRIGGER trg_dokument_bi BEFORE INSERT ON dokumenti_prijave FOR EACH ROW
BEGIN
  IF NEW.status <> 'NA_CEKANJU' OR NEW.pregledao_korisnik_id IS NOT NULL
     OR NEW.pregledano_at IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Novi dokument mora cekati provjeru';
  END IF;
  CALL sp_provjeri_upload(NEW.prijava_id,NEW.zahtjev_dokumenta_id,
                          NEW.clan_domacinstva_id,NEW.redni_broj,
                          NEW.verzija,NEW.pdf_datoteka_id);
END$$
CREATE TRIGGER trg_dokument_bu BEFORE UPDATE ON dokumenti_prijave FOR EACH ROW
BEGIN
  IF NEW.prijava_id<>OLD.prijava_id OR NEW.zahtjev_dokumenta_id<>OLD.zahtjev_dokumenta_id
     OR NOT (NEW.clan_domacinstva_id <=> OLD.clan_domacinstva_id)
     OR NEW.redni_broj<>OLD.redni_broj OR NEW.verzija<>OLD.verzija
     OR NEW.pdf_datoteka_id<>OLD.pdf_datoteka_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Datoteka/verzija je nepromjenljiva; dodajte novu verziju';
  END IF;
  IF OLD.status <> 'NA_CEKANJU' AND (
     NEW.status<>OLD.status OR NOT (NEW.napomena_komisije <=> OLD.napomena_komisije)
     OR NOT (NEW.pregledao_korisnik_id <=> OLD.pregledao_korisnik_id)
     OR NOT (NEW.pregledano_at <=> OLD.pregledano_at)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Verifikacija je nepromjenljiva nakon odluke';
  END IF;
  IF OLD.status = 'NA_CEKANJU' AND NEW.status <> OLD.status THEN
    CALL sp_provjeri_pregled_dokumenta(NEW.prijava_id,NEW.pregledao_korisnik_id);
    SET NEW.pregledano_at = UTC_TIMESTAMP(6);
  END IF;
END$$
CREATE TRIGGER trg_dokument_au AFTER UPDATE ON dokumenti_prijave FOR EACH ROW
BEGIN
  IF NEW.status <> OLD.status THEN
    IF NEW.status = 'DOPUNA_TRAZENA' THEN
      UPDATE prijave SET status='DOPUNA_TRAZENA'
      WHERE id=NEW.prijava_id AND status IN ('PODNESENA','U_PROVJERI','PROVJERENA');
    END IF;
    INSERT INTO audit_log(korisnik_id,akcija,entitet,entitet_id,stara_vrijednost,nova_vrijednost,opis)
    VALUES(NEW.pregledao_korisnik_id,'DOCUMENT_REVIEW','dokumenti_prijave',NEW.id,
      JSON_OBJECT('status',OLD.status),JSON_OBJECT('status',NEW.status,'verzija',NEW.verzija),
      NEW.napomena_komisije);
  END IF;
END$$
CREATE TRIGGER trg_dokument_bd BEFORE DELETE ON dokumenti_prijave FOR EACH ROW
BEGIN
  IF OLD.status <> 'NA_CEKANJU' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Odluceni dokumenti ostaju u historiji';
  END IF;
END$$

-- ----------------------------------------------------------------
-- Konfiguracija bodovanja: skale ne smiju biti promijenjene nakon upotrebe.
-- ----------------------------------------------------------------
CREATE TRIGGER trg_skala_bi BEFORE INSERT ON skale_kriterija FOR EACH ROW
BEGIN
  CALL sp_provjeri_skalu(NEW.kriterij_id,NULL,NEW.od_vrijednost,NEW.do_vrijednost,NEW.bodovi);
END$$
CREATE TRIGGER trg_skala_bu BEFORE UPDATE ON skale_kriterija FOR EACH ROW
BEGIN
  CALL sp_provjeri_skalu(NEW.kriterij_id,OLD.id,NEW.od_vrijednost,NEW.do_vrijednost,NEW.bodovi);
END$$
CREATE TRIGGER trg_skala_bd BEFORE DELETE ON skale_kriterija FOR EACH ROW
BEGIN
  IF EXISTS(SELECT 1 FROM bodovi_prijave WHERE kriterij_id=OLD.kriterij_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Zabranjeno brisanje koristenog intervala skale';
  END IF;
END$$
CREATE TRIGGER trg_kriterij_bi BEFORE INSERT ON kriteriji_bodovanja FOR EACH ROW
BEGIN
  CALL sp_provjeri_izvor_kriterija(NEW.izvor_sifra,NEW.tip_kriterija);
END$$
CREATE TRIGGER trg_kriterij_bu BEFORE UPDATE ON kriteriji_bodovanja FOR EACH ROW
BEGIN
  CALL sp_provjeri_izvor_kriterija(NEW.izvor_sifra,NEW.tip_kriterija);
  IF EXISTS(SELECT 1 FROM bodovi_prijave WHERE kriterij_id=OLD.id) THEN
    IF NOT (
      NEW.aktivan=FALSE AND OLD.aktivan=TRUE
      AND (NEW.konkurs_id <=> OLD.konkurs_id)
      AND (NEW.kategorija_id <=> OLD.kategorija_id)
      AND (NEW.naziv <=> OLD.naziv)
      AND (NEW.opis <=> OLD.opis)
      AND (NEW.tip_kriterija <=> OLD.tip_kriterija)
      AND (NEW.izvor_sifra <=> OLD.izvor_sifra)
      AND (NEW.koeficijent <=> OLD.koeficijent)
      AND (NEW.fiksni_bodovi <=> OLD.fiksni_bodovi)
      AND (NEW.max_bodova <=> OLD.max_bodova)
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Koristen kriterij se moze samo deaktivirati';
    END IF;
  END IF;
END$$
CREATE TRIGGER trg_kriterij_bd BEFORE DELETE ON kriteriji_bodovanja FOR EACH ROW
BEGIN
  IF EXISTS(SELECT 1 FROM bodovi_prijave WHERE kriterij_id=OLD.id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Koristen kriterij se ne moze brisati';
  END IF;
END$$

CREATE TRIGGER trg_bodovi_bi BEFORE INSERT ON bodovi_prijave FOR EACH ROW
BEGIN
  IF NEW.je_rucno_korigovano AND NEW.korigovano_at IS NULL THEN
    SET NEW.korigovano_at=UTC_TIMESTAMP(6);
  END IF;
  CALL sp_provjeri_bodovanje(NEW.prijava_id,NEW.kriterij_id,NEW.automatski_bodovi,
       NEW.korigovani_bodovi,NEW.konacni_bodovi,NEW.je_rucno_korigovano,
       NEW.korigovao_korisnik_id,TRUE);
END$$
CREATE TRIGGER trg_bodovi_bu BEFORE UPDATE ON bodovi_prijave FOR EACH ROW
BEGIN
  IF NEW.prijava_id<>OLD.prijava_id OR NEW.kriterij_id<>OLD.kriterij_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ne mogu se promijeniti veze bodovne stavke';
  END IF;
  IF OLD.je_rucno_korigovano AND NOT NEW.je_rucno_korigovano THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rucnu korekciju nije dozvoljeno brisati; uradite novu korekciju';
  END IF;
  IF NEW.je_rucno_korigovano AND
     (NOT (NEW.konacni_bodovi <=> OLD.konacni_bodovi)
      OR NOT (NEW.korigovao_korisnik_id <=> OLD.korigovao_korisnik_id)
      OR NOT (NEW.obrazlozenje_korekcije <=> OLD.obrazlozenje_korekcije)) THEN
    SET NEW.korigovano_at=UTC_TIMESTAMP(6);
  END IF;
  CALL sp_provjeri_bodovanje(NEW.prijava_id,NEW.kriterij_id,NEW.automatski_bodovi,
       NEW.korigovani_bodovi,NEW.konacni_bodovi,NEW.je_rucno_korigovano,
       NEW.korigovao_korisnik_id,FALSE);
END$$
CREATE TRIGGER trg_bodovi_ai AFTER INSERT ON bodovi_prijave FOR EACH ROW
BEGIN
  IF NEW.je_rucno_korigovano THEN
    INSERT INTO historija_korekcija
      (bodovna_stavka_id,stari_bodovi,novi_bodovi,obrazlozenje,komisija_korisnik_id,promjena_at)
    VALUES (NEW.id,NEW.automatski_bodovi,NEW.konacni_bodovi,
            NEW.obrazlozenje_korekcije,NEW.korigovao_korisnik_id,NEW.korigovano_at);
    INSERT INTO audit_log(korisnik_id,akcija,entitet,entitet_id,stara_vrijednost,nova_vrijednost)
    VALUES(NEW.korigovao_korisnik_id,'SCORE_OVERRIDE','bodovi_prijave',NEW.id,
      JSON_OBJECT('bodovi',NEW.automatski_bodovi),JSON_OBJECT('bodovi',NEW.konacni_bodovi));
  END IF;
END$$
CREATE TRIGGER trg_bodovi_au AFTER UPDATE ON bodovi_prijave FOR EACH ROW
BEGIN
  IF NEW.je_rucno_korigovano AND (
     NOT (NEW.konacni_bodovi <=> OLD.konacni_bodovi)
     OR NOT (NEW.obrazlozenje_korekcije <=> OLD.obrazlozenje_korekcije)
     OR NOT (NEW.korigovao_korisnik_id <=> OLD.korigovao_korisnik_id)
  ) THEN
    INSERT INTO historija_korekcija
      (bodovna_stavka_id,stari_bodovi,novi_bodovi,obrazlozenje,komisija_korisnik_id,promjena_at)
    VALUES (NEW.id,OLD.konacni_bodovi,NEW.konacni_bodovi,
            NEW.obrazlozenje_korekcije,NEW.korigovao_korisnik_id,NEW.korigovano_at);
    INSERT INTO audit_log(korisnik_id,akcija,entitet,entitet_id,stara_vrijednost,nova_vrijednost)
    VALUES(NEW.korigovao_korisnik_id,'SCORE_OVERRIDE','bodovi_prijave',NEW.id,
      JSON_OBJECT('bodovi',OLD.konacni_bodovi),JSON_OBJECT('bodovi',NEW.konacni_bodovi));
  END IF;
END$$
CREATE TRIGGER trg_bodovi_bd BEFORE DELETE ON bodovi_prijave FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Bodovne stavke se ne brisu; historija mora ostati';
END$$

CREATE TRIGGER trg_hist_bu BEFORE UPDATE ON historija_korekcija FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Historija korekcija je append-only';
END$$
CREATE TRIGGER trg_hist_bd BEFORE DELETE ON historija_korekcija FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Historija korekcija se ne brise';
END$$

CREATE TRIGGER trg_tie_bi BEFORE INSERT ON pravila_izjednacenja FOR EACH ROW
BEGIN
  IF EXISTS (
    SELECT 1 FROM rang_liste rl JOIN kategorije_stipendija kat ON kat.id=rl.kategorija_id
    WHERE rl.status IN ('POTVRDJENA','OBJAVLJENA')
      AND kat.konkurs_id=NEW.konkurs_id
      AND (NEW.kategorija_id IS NULL OR kat.id=NEW.kategorija_id)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pravila izjednacenja su zakljucana nakon potvrde liste';
  END IF;
END$$

-- Pravila izjednacenja zakljucavaju se kada postoji potvrdjena lista.
CREATE TRIGGER trg_tie_bu BEFORE UPDATE ON pravila_izjednacenja FOR EACH ROW
BEGIN
  IF EXISTS (
    SELECT 1 FROM rang_liste rl
      JOIN kategorije_stipendija kat ON kat.id=rl.kategorija_id
    WHERE rl.status IN ('POTVRDJENA','OBJAVLJENA')
      AND kat.konkurs_id=OLD.konkurs_id
      AND (OLD.kategorija_id IS NULL OR kat.id=OLD.kategorija_id)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Koristeno pravilo izjednacenja se ne mijenja';
  END IF;
END$$
CREATE TRIGGER trg_tie_bd BEFORE DELETE ON pravila_izjednacenja FOR EACH ROW
BEGIN
  IF EXISTS (
    SELECT 1 FROM rang_liste rl
      JOIN kategorije_stipendija kat ON kat.id=rl.kategorija_id
    WHERE rl.status IN ('POTVRDJENA','OBJAVLJENA')
      AND kat.konkurs_id=OLD.konkurs_id
      AND (OLD.kategorija_id IS NULL OR kat.id=OLD.kategorija_id)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Koristeno pravilo izjednacenja se ne brise';
  END IF;
END$$

CREATE TRIGGER trg_zahtjev_bi BEFORE INSERT ON zahtjevi_dokumenata FOR EACH ROW
BEGIN
  IF EXISTS(SELECT 1 FROM prijave WHERE konkurs_id=NEW.konkurs_id AND status<>'DRAFT') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ne dodavati zahtjeve nakon prvih prijava';
  END IF;
END$$

-- Zahtjev za dokumente se ne prepisuje nakon prve podnesene prijave.
CREATE TRIGGER trg_zahtjev_bu BEFORE UPDATE ON zahtjevi_dokumenata FOR EACH ROW
BEGIN
  IF EXISTS(SELECT 1 FROM prijave p WHERE p.konkurs_id=OLD.konkurs_id
     AND p.status<>'DRAFT') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ne mijenjati dokumentacijske zahtjeve nakon podnosenja';
  END IF;
END$$
CREATE TRIGGER trg_zahtjev_bd BEFORE DELETE ON zahtjevi_dokumenata FOR EACH ROW
BEGIN
  IF EXISTS(SELECT 1 FROM prijave p WHERE p.konkurs_id=OLD.konkurs_id
     AND p.status<>'DRAFT') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ne brisati dokumentacijske zahtjeve nakon podnosenja';
  END IF;
END$$

-- ----------------------------------------------------------------
-- Rang-liste: snapshot pripada istoj kategoriji, a nakon potvrde
-- stavke se ne mijenjaju (za novi poredak napraviti NOVU verziju).
-- ----------------------------------------------------------------
CREATE TRIGGER trg_rang_stavka_bi BEFORE INSERT ON rang_lista_stavke FOR EACH ROW
BEGIN
  DECLARE v_kat_p BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_kat_r BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_status VARCHAR(20) DEFAULT NULL;
  SELECT kategorija_id INTO v_kat_p FROM prijave WHERE id=NEW.prijava_id;
  SELECT kategorija_id,status INTO v_kat_r,v_status FROM rang_liste WHERE id=NEW.rang_lista_id;
  IF v_kat_p IS NULL OR v_kat_p<>v_kat_r OR v_status <> 'NACRT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Stavka nije u kategoriji ili je lista zakljucana';
  END IF;
END$$
CREATE TRIGGER trg_rang_stavka_bu BEFORE UPDATE ON rang_lista_stavke FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(20) DEFAULT NULL;
  IF NEW.rang_lista_id<>OLD.rang_lista_id OR NEW.prijava_id<>OLD.prijava_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Identitet stavke nije promjenljiv';
  END IF;
  SELECT status INTO v_status FROM rang_liste WHERE id=OLD.rang_lista_id;
  IF v_status <> 'NACRT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Potvrdjena/objavljena rang-lista se ne mijenja';
  END IF;
END$$
CREATE TRIGGER trg_rang_stavka_bd BEFORE DELETE ON rang_lista_stavke FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(20) DEFAULT NULL;
  SELECT status INTO v_status FROM rang_liste WHERE id=OLD.rang_lista_id;
  IF v_status <> 'NACRT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ne brisu se stavke potvrdjene/objavljene liste';
  END IF;
END$$
CREATE TRIGGER trg_rang_lista_bu BEFORE UPDATE ON rang_liste FOR EACH ROW
BEGIN
  DECLARE v_broj INT DEFAULT 0;
  IF NEW.id<>OLD.id OR NEW.kategorija_id<>OLD.kategorija_id
      OR NEW.verzija_broj<>OLD.verzija_broj OR NEW.tip_liste<>OLD.tip_liste
      OR NEW.kreirao_korisnik_id<>OLD.kreirao_korisnik_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Identitet/verzija rang-liste je nepromjenljiv';
  END IF;
  IF OLD.status = 'OBJAVLJENA' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Objavljena rang-lista je trajni snapshot';
  END IF;
  IF OLD.status = 'POTVRDJENA' AND (
      NOT (NEW.potvrdio_korisnik_id <=> OLD.potvrdio_korisnik_id)
      OR NOT (NEW.potvrdjeno_at <=> OLD.potvrdjeno_at)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Podaci potvrde rang-liste su nepromjenljivi';
  END IF;
  IF OLD.status = 'POTVRDJENA' AND NEW.status NOT IN ('POTVRDJENA','OBJAVLJENA') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Potvrdjena lista moze samo u OBJAVLJENA';
  END IF;
  IF OLD.status = 'NACRT' AND NEW.status='OBJAVLJENA' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Listu treba prvo potvrditi';
  END IF;
  IF OLD.status = 'NACRT' AND NEW.status='POTVRDJENA' THEN
    IF NOT EXISTS (
      SELECT 1 FROM korisnici u JOIN uloge r ON r.id=u.uloga_id
      WHERE u.id=NEW.potvrdio_korisnik_id AND u.aktivan=TRUE
        AND r.sifra IN ('ADMIN','KOMISIJA')
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Listu potvrdjuje admin ili komisija';
    END IF;
    SELECT COUNT(*) INTO v_broj FROM rang_lista_stavke WHERE rang_lista_id=OLD.id;
    IF v_broj = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ne moze se potvrditi prazna rang-lista';
    END IF;
    IF NEW.potvrdjeno_at IS NULL THEN SET NEW.potvrdjeno_at=UTC_TIMESTAMP(6); END IF;
  END IF;
  IF OLD.status = 'POTVRDJENA' AND NEW.status='OBJAVLJENA' THEN
    IF NOT EXISTS (
      SELECT 1 FROM korisnici u JOIN uloge r ON r.id=u.uloga_id
      WHERE u.id=NEW.objavio_korisnik_id AND u.aktivan=TRUE AND r.sifra='ADMIN'
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Samo administrator objavljuje rang-listu';
    END IF;
    SET NEW.datum_objave=UTC_TIMESTAMP(6);
  END IF;
END$$
CREATE TRIGGER trg_rang_lista_bd BEFORE DELETE ON rang_liste FOR EACH ROW
BEGIN
  IF OLD.status <> 'NACRT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Potvrdjena/objavljena lista se ne brise';
  END IF;
END$$
CREATE TRIGGER trg_rang_lista_au AFTER UPDATE ON rang_liste FOR EACH ROW
BEGIN
  IF OLD.status <> 'OBJAVLJENA' AND NEW.status='OBJAVLJENA' THEN
    INSERT INTO audit_log(korisnik_id,akcija,entitet,entitet_id,stara_vrijednost,nova_vrijednost)
    VALUES(NEW.objavio_korisnik_id,'RANK_PUBLISH','rang_liste',NEW.id,
      JSON_OBJECT('status',OLD.status),
      JSON_OBJECT('status',NEW.status,'verzija',NEW.verzija_broj,'tip',NEW.tip_liste));
  END IF;
END$$

-- ----------------------------------------------------------------
-- Zalbe: samo na objavljene PRELIMINARNE liste, dok je rok otvoren.
-- ----------------------------------------------------------------
CREATE TRIGGER trg_zalba_bi BEFORE INSERT ON zalbe FOR EACH ROW
BEGIN
  DECLARE v_kat_p BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_kat_l BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_rok DATETIME(6) DEFAULT NULL;
  DECLARE v_objava DATETIME(6) DEFAULT NULL;
  DECLARE v_tip VARCHAR(20) DEFAULT NULL;
  DECLARE v_status VARCHAR(20) DEFAULT NULL;
  SELECT p.kategorija_id,k.rok_zalbi INTO v_kat_p,v_rok
    FROM prijave p JOIN konkursi k ON k.id=p.konkurs_id WHERE p.id=NEW.prijava_id;
  SELECT kategorija_id,datum_objave,tip_liste,status
    INTO v_kat_l,v_objava,v_tip,v_status FROM rang_liste WHERE id=NEW.rang_lista_id;
  IF v_kat_p IS NULL OR v_kat_p<>v_kat_l OR v_tip<>'PRELIMINARNA'
     OR v_status <> 'OBJAVLJENA' OR v_rok IS NULL
     OR UTC_TIMESTAMP(6) > v_rok OR UTC_TIMESTAMP(6)<v_objava THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Zalba mora biti u roku na objavljenu preliminarnu listu';
  END IF;
  SET NEW.podnesena_at=UTC_TIMESTAMP(6);
END$$
CREATE TRIGGER trg_zalba_bu BEFORE UPDATE ON zalbe FOR EACH ROW
BEGIN
  DECLARE v_ok INT DEFAULT 0;
  DECLARE v_konkurs BIGINT UNSIGNED DEFAULT NULL;
  IF NEW.prijava_id<>OLD.prijava_id OR NEW.rang_lista_id<>OLD.rang_lista_id
    OR NEW.tekst_zalbe<>OLD.tekst_zalbe
    OR NOT (NEW.prilog_pdf_id <=> OLD.prilog_pdf_id)
    OR NEW.podnesena_at<>OLD.podnesena_at THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Podnesena zalba i prilog su nepromjenljivi';
  END IF;
  IF OLD.status IN ('USVOJENA','ODBIJENA') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rijesena zalba i obrazlozenje su nepromjenljivi';
  END IF;
  IF OLD.status IN ('PODNESENA','U_OBRADI') AND NEW.status IN ('USVOJENA','ODBIJENA') THEN
    SELECT konkurs_id INTO v_konkurs FROM prijave WHERE id=NEW.prijava_id;
    SELECT COUNT(*) INTO v_ok FROM clanovi_komisije_konkursa ck
      JOIN korisnici u ON u.id=ck.korisnik_id AND u.aktivan=TRUE
      JOIN uloge r ON r.id=u.uloga_id AND r.sifra='KOMISIJA'
      WHERE ck.konkurs_id=v_konkurs AND ck.korisnik_id=NEW.rijesio_korisnik_id
        AND ck.aktivan=TRUE;
    IF v_ok=0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Odluku o zalbi mora donijeti imenovani clan komisije';
    END IF;
    SET NEW.rijeseno_at=UTC_TIMESTAMP(6);
  END IF;
END$$
CREATE TRIGGER trg_zalba_au AFTER UPDATE ON zalbe FOR EACH ROW
BEGIN
  IF NEW.status <> OLD.status THEN
    INSERT INTO audit_log(korisnik_id,akcija,entitet,entitet_id,stara_vrijednost,nova_vrijednost)
    VALUES(NEW.rijesio_korisnik_id,'STATUS_CHANGE','zalbe',NEW.id,
      JSON_OBJECT('status',OLD.status),JSON_OBJECT('status',NEW.status));
  END IF;
END$$

-- Potvrditi moze admin ili imenovani clan komisije; objava samo ADMIN.
-- Uloga se provjerava i prilikom promjene statusa rang-liste.
CREATE TRIGGER trg_rang_lista_bi BEFORE INSERT ON rang_liste FOR EACH ROW
BEGIN
  DECLARE v_ok INT DEFAULT 0;
  SELECT COUNT(*) INTO v_ok FROM korisnici u JOIN uloge r ON r.id=u.uloga_id
    WHERE u.id=NEW.kreirao_korisnik_id AND u.aktivan=TRUE
      AND r.sifra IN ('ADMIN','KOMISIJA');
  IF v_ok=0 OR NEW.status<>'NACRT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Listu kreira admin/komisija u NACRT statusu';
  END IF;
END$$

-- ----------------------------------------------------------------
-- Ugovor samo za dobitnika na objavljenoj konacnoj listi.
-- ----------------------------------------------------------------
CREATE TRIGGER trg_ugovor_bi BEFORE INSERT ON ugovori FOR EACH ROW
BEGIN
  DECLARE v_prijava BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_status_stavke VARCHAR(25) DEFAULT NULL;
  DECLARE v_tip VARCHAR(20) DEFAULT NULL;
  DECLARE v_status_liste VARCHAR(20) DEFAULT NULL;
  SELECT st.prijava_id,st.status_stipendije,rl.tip_liste,rl.status
    INTO v_prijava,v_status_stavke,v_tip,v_status_liste
    FROM rang_lista_stavke st JOIN rang_liste rl ON rl.id=st.rang_lista_id
    WHERE st.id=NEW.rang_stavka_id;
  IF v_prijava IS NULL OR v_prijava <> NEW.prijava_id
     OR v_status_stavke<>'OSTVARIO' OR v_tip<>'KONACNA'
     OR v_status_liste<>'OBJAVLJENA' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ugovor samo za dobitnika na konacnoj objavljenoj listi';
  END IF;
END$$

-- Ne mijenjati upotrijebljeni sablon; objaviti narednu verziju.
CREATE TRIGGER trg_sablon_bu BEFORE UPDATE ON sabloni_ugovora FOR EACH ROW
BEGIN
  IF EXISTS(SELECT 1 FROM ugovori WHERE sablon_id=OLD.id) AND NOT (
    OLD.aktivan=TRUE AND NEW.aktivan=FALSE
    AND (NEW.naziv <=> OLD.naziv)
    AND (NEW.verzija <=> OLD.verzija)
    AND (NEW.sadrzaj_sablona <=> OLD.sadrzaj_sablona)
    AND (NEW.kreirao_korisnik_id <=> OLD.kreirao_korisnik_id)
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Koristen sablon smije se samo deaktivirati';
  END IF;
END$$

CREATE TRIGGER trg_ugovor_bu BEFORE UPDATE ON ugovori FOR EACH ROW
BEGIN
  IF NEW.prijava_id<>OLD.prijava_id OR NEW.rang_stavka_id<>OLD.rang_stavka_id
     OR NEW.sablon_id<>OLD.sablon_id OR NEW.broj_ugovora<>OLD.broj_ugovora THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Prijava, lista, sablon i broj ugovora su fiksni';
  END IF;
  IF OLD.status IN('POTPISAN','AKTIVAN','ZAVRSEN','RASKINUT') AND (
     NOT(NEW.mjesecni_iznos <=> OLD.mjesecni_iznos)
     OR NOT(NEW.broj_rata <=> OLD.broj_rata)
     OR NOT(NEW.broj_racuna_snapshot <=> OLD.broj_racuna_snapshot)
     OR NOT(NEW.naziv_banke_snapshot <=> OLD.naziv_banke_snapshot)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Potpisani finansijski uslovi su nepromjenljivi';
  END IF;
END$$

CREATE TRIGGER trg_backup_bi BEFORE INSERT ON backup_evidencija FOR EACH ROW
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM korisnici u JOIN uloge r ON r.id=u.uloga_id
    WHERE u.id=NEW.pokrenuo_korisnik_id AND u.aktivan=TRUE AND r.sifra='ADMIN'
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Backup moze pokrenuti samo admin';
  END IF;
END$$

CREATE TRIGGER trg_isplata_bi BEFORE INSERT ON isplate FOR EACH ROW
BEGIN
  DECLARE v_broj SMALLINT UNSIGNED DEFAULT NULL;
  DECLARE v_status VARCHAR(20) DEFAULT NULL;
  SELECT broj_rata,status INTO v_broj,v_status FROM ugovori WHERE id=NEW.ugovor_id;
  IF v_broj IS NULL OR NEW.broj_rate>v_broj OR v_status NOT IN ('POTPISAN','AKTIVAN') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rata nije dozvoljena prema ugovoru';
  END IF;
END$$
CREATE TRIGGER trg_isplata_bu BEFORE UPDATE ON isplate FOR EACH ROW
BEGIN
  IF NEW.ugovor_id<>OLD.ugovor_id OR NEW.broj_rate<>OLD.broj_rate THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ugovor i redni broj rate se ne mijenjaju';
  END IF;
  IF OLD.status='ISPLACENA' AND NEW.status<>'ISPLACENA' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Isplacena rata ne vraca se u planiranu';
  END IF;
  IF OLD.status<>'ISPLACENA' AND NEW.status='ISPLACENA' THEN
    SET NEW.isplaceno_at=UTC_TIMESTAMP(6);
  END IF;
END$$

CREATE TRIGGER trg_notifikacija_bu BEFORE UPDATE ON notifikacije FOR EACH ROW
BEGIN
  IF NEW.id<>OLD.id OR NEW.korisnik_id<>OLD.korisnik_id
     OR NOT(NEW.prijava_id <=> OLD.prijava_id)
     OR NOT(NEW.konkurs_id <=> OLD.konkurs_id)
     OR NEW.naslov<>OLD.naslov OR NEW.poruka<>OLD.poruka
     OR NEW.tip<>OLD.tip THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Notifikacija se ne prepisuje';
  END IF;
  IF OLD.procitano AND NOT NEW.procitano THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Procitana notifikacija ostaje procitana';
  END IF;
  IF NOT OLD.procitano AND NEW.procitano THEN
    SET NEW.procitano_at=UTC_TIMESTAMP(6);
  END IF;
END$$

CREATE TRIGGER trg_backup_ai AFTER INSERT ON backup_evidencija FOR EACH ROW
BEGIN
  INSERT INTO audit_log(korisnik_id,akcija,entitet,entitet_id,nova_vrijednost,opis)
  VALUES(NEW.pokrenuo_korisnik_id,'BACKUP','backup_evidencija',NEW.id,
         JSON_OBJECT('status',NEW.status),'Pokrenuta izrada backupa');
END$$
CREATE TRIGGER trg_backup_au AFTER UPDATE ON backup_evidencija FOR EACH ROW
BEGIN
  IF NEW.status<>OLD.status THEN
    INSERT INTO audit_log(korisnik_id,akcija,entitet,entitet_id,stara_vrijednost,nova_vrijednost)
    VALUES(NEW.pokrenuo_korisnik_id,'BACKUP','backup_evidencija',NEW.id,
           JSON_OBJECT('status',OLD.status),JSON_OBJECT('status',NEW.status));
  END IF;
END$$

-- ----------------------------------------------------------------
-- Podrazumijevane postavke; audit je append-only.
-- ----------------------------------------------------------------
CREATE TRIGGER trg_korisnici_ai AFTER INSERT ON korisnici FOR EACH ROW
BEGIN
  INSERT INTO korisnicke_postavke(korisnik_id) VALUES(NEW.id);
END$$

CREATE TRIGGER trg_audit_bi BEFORE INSERT ON audit_log FOR EACH ROW
BEGIN
  DECLARE v_uloga VARCHAR(20) DEFAULT NULL;
  IF NEW.korisnik_id IS NOT NULL THEN
    SELECT r.sifra INTO v_uloga FROM korisnici u JOIN uloge r ON r.id=u.uloga_id
      WHERE u.id=NEW.korisnik_id;
    SET NEW.uloga_snapshot = v_uloga;
  ELSE
    SET NEW.uloga_snapshot = 'SISTEM';
  END IF;
  SET NEW.vrijeme_akcije=UTC_TIMESTAMP(6);
END$$
CREATE TRIGGER trg_audit_bu BEFORE UPDATE ON audit_log FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Audit log je append-only';
END$$
CREATE TRIGGER trg_audit_bd BEFORE DELETE ON audit_log FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Audit log se ne brise';
END$$

DELIMITER ;
-- Kraj triggers.sql
