-- ============================================================================
-- VITEZ eSTIPENDIJA - DEMO SEED (iskljucivo izmisljeni podaci)
-- Kompatibilno sa: db/schema.sql + db/triggers.sql iz paketa Nova_Baza_3NF
-- MySQL 8.0.16+; izvrsite SAMO NAD NOVOM / PRAZNOM TESTNOM BAZOM.
-- Redoslijed: schema.sql -> triggers.sql -> seed.sql
-- Schema.sql VEC puni sifrarnike uloge, izvori_bodovanja, tipovi_dokumenata.
-- Zato ih ovdje NE unosimo ponovo.
--
-- Napomene:
--  1) Svi identiteti, JMBG brojevi, bankovni racuni i adrese su izmisljenI.
--     JMBG sadrzaj je namjerno testni, nije stvaran identifikator.
--  2) Storage kljucevi PDF-a su DEMO metapodaci: nema stvarnih PDF fajlova.
--     Za test prikaza/preuzimanja dokumenata dodajte fizicke testne PDF-ove,
--     izracunajte njihove stvarne SHA-256 hashove i uskladite metapodatke
--     prije seed-a (pdf_datoteke su nepromjenljive nakon unosa).
--  3) Konkurs za obradu se NAMJERNO zatvara prije simuliranog datuma isteka,
--     jer se podnosenje mora desiti dok je konkurs OTVOREN, a dodjela komisiji
--     je dozvoljena tek kada je ZATVOREN. To je iskljucivo testni scenarij.
--  4) Seed nije namijenjen za ponovljeno pokretanje: neke tabele imaju UNIQUE,
--     a audit i historija su append-only. Prvo koristite praznu TEST bazu.
--  5) Cijelo vrijeme je UTC, kao u osnovnoj semi i triggerima.
--  6) Svi demo korisnici imaju istu TEST lozinku: Test123!Demo
--     Zamijenite je prije bilo kakvog deploya na okruzenje dostupno javnosti.
-- ============================================================================
USE e_stipendija;
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET time_zone = '+00:00';
SET @sada = UTC_TIMESTAMP(6);
SET @od_demo = @sada - INTERVAL 7 DAY;
SET @do_demo = @sada + INTERVAL 15 DAY;
SET @dopuna_demo = @sada + INTERVAL 25 DAY;
SET @zalba_demo = @sada + INTERVAL 35 DAY;
-- Zapamti da su ovo rezervisane TEST adrese i podaci.
SELECT id INTO @r_admin FROM uloge WHERE sifra='ADMIN';
SELECT id INTO @r_komisija FROM uloge WHERE sifra='KOMISIJA';
SELECT id INTO @r_student FROM uloge WHERE sifra='STUDENT';
SELECT id INTO @tip_cips FROM tipovi_dokumenata WHERE sifra='CIPS';
SELECT id INTO @tip_studiranje FROM tipovi_dokumenata WHERE sifra='POTVRDA_STUDIRANJA';
SELECT id INTO @tip_kucna FROM tipovi_dokumenata WHERE sifra='KUCNA_LISTA';
SELECT id INTO @tip_ocjene FROM tipovi_dokumenata WHERE sifra='UVJERENJE_OCJENE';
SELECT id INTO @tip_borac FROM tipovi_dokumenata WHERE sifra='BORACKI_STATUS';
SELECT id INTO @tip_plata FROM tipovi_dokumenata WHERE sifra='PLATNA_LISTA';

-- Testna BCrypt vrijednost generisana eksterno (Apache htpasswd BCrypt cost 10).
-- SQL je ne hešira. Java BCrypt treba podrzavati format $2a$.
SET @bcrypt_demo = '$2a$10$UGFEfGdfutSKC5ZD5m9r0.s6awSNygIEwq3TkCfNvDpQJm8TTjjOq';

START TRANSACTION;
-- ---------------------------------------------------------------------------
-- 1. KORISNICI / STUDENTSKI PROFILI (trigger automatski kreira postavke)
-- ---------------------------------------------------------------------------
INSERT INTO korisnici (uloga_id,ime,prezime,korisnicko_ime,email,lozinka_hash)
VALUES (@r_admin,'Admin','Testic','demo.admin','admin@estipendija.invalid',@bcrypt_demo);
SET @admin = LAST_INSERT_ID();
INSERT INTO korisnici (uloga_id,ime,prezime,korisnicko_ime,email,lozinka_hash)
VALUES (@r_komisija,'Aida','Komisic','demo.komisija1','komisija1@estipendija.invalid',@bcrypt_demo);
SET @kom1 = LAST_INSERT_ID();
INSERT INTO korisnici (uloga_id,ime,prezime,korisnicko_ime,email,lozinka_hash)
VALUES (@r_komisija,'Edin','Komisic','demo.komisija2','komisija2@estipendija.invalid',@bcrypt_demo);
SET @kom2 = LAST_INSERT_ID();
INSERT INTO korisnici (uloga_id,ime,prezime,korisnicko_ime,email,lozinka_hash)
VALUES (@r_student,'Lejla','Primjer','demo.lejla','lejla@estipendija.invalid',@bcrypt_demo);
SET @u_lejla = LAST_INSERT_ID();
INSERT INTO korisnici (uloga_id,ime,prezime,korisnicko_ime,email,lozinka_hash)
VALUES (@r_student,'Amar','Ogledic','demo.amar','amar@estipendija.invalid',@bcrypt_demo);
SET @u_amar = LAST_INSERT_ID();
INSERT INTO korisnici (uloga_id,ime,prezime,korisnicko_ime,email,lozinka_hash)
VALUES (@r_student,'Nejla','Uzorak','demo.nejla','nejla@estipendija.invalid',@bcrypt_demo);
SET @u_nejla = LAST_INSERT_ID();
INSERT INTO korisnici (uloga_id,ime,prezime,korisnicko_ime,email,lozinka_hash)
VALUES (@r_student,'Mirza','Testic','demo.mirza','mirza@estipendija.invalid',@bcrypt_demo);
SET @u_mirza = LAST_INSERT_ID();
INSERT INTO korisnici (uloga_id,ime,prezime,korisnicko_ime,email,lozinka_hash)
VALUES (@r_student,'Tarik','Model','demo.tarik','tarik@estipendija.invalid',@bcrypt_demo);
SET @u_tarik = LAST_INSERT_ID();

INSERT INTO studenti (korisnik_id,ime_roditelja,jmbg,datum_rodjenja,adresa,mjesto,opcina,telefon,
 naziv_fakulteta,naziv_univerziteta,smjer,ciklus_studija,godina_studija,broj_indeksa,
 prosjek_ocjena,broj_racuna,vrsta_racuna,naziv_banke)
VALUES (@u_lejla,'Haris','9999999000001','2003-04-15','Testna ulica 1','Vitez','Vitez','060-000-0001',
 'Politehnicki fakultet','Univerzitet u Zenici','Softversko inzenjerstvo','I',2,'TEST-001',
 9.50,'TEST-RACUN-000000001','DOMACI','Demo banka');
SET @s_lejla = LAST_INSERT_ID();
INSERT INTO studenti (korisnik_id,ime_roditelja,jmbg,datum_rodjenja,adresa,mjesto,opcina,telefon,
 naziv_fakulteta,naziv_univerziteta,smjer,ciklus_studija,godina_studija,broj_indeksa,
 prosjek_ocjena,broj_racuna,vrsta_racuna,naziv_banke)
VALUES (@u_amar,'Enisa','9999999000002','2002-09-21','Testna ulica 2','Vitez','Vitez','060-000-0002',
 'Politehnicki fakultet','Univerzitet u Zenici','Softversko inzenjerstvo','I',2,'TEST-002',
 9.70,'TEST-RACUN-000000002','DOMACI','Demo banka');
SET @s_amar = LAST_INSERT_ID();
INSERT INTO studenti (korisnik_id,ime_roditelja,jmbg,datum_rodjenja,adresa,mjesto,opcina,telefon,
 naziv_fakulteta,naziv_univerziteta,smjer,ciklus_studija,godina_studija,broj_indeksa,
 prosjek_ocjena,broj_racuna,vrsta_racuna,naziv_banke)
VALUES (@u_nejla,'Mira','9999999000003','2001-01-17','Testna ulica 3','Vitez','Vitez','060-000-0003',
 'Ekonomski fakultet','Univerzitet u Travniku','Ekonomija','I',3,'TEST-003',
 9.20,'TEST-RACUN-000000003','DOMACI','Demo banka');
SET @s_nejla = LAST_INSERT_ID();
INSERT INTO studenti (korisnik_id,ime_roditelja,jmbg,datum_rodjenja,adresa,mjesto,opcina,telefon,
 naziv_fakulteta,naziv_univerziteta,smjer,ciklus_studija,godina_studija,broj_indeksa,
 prosjek_ocjena,broj_racuna,vrsta_racuna,naziv_banke)
VALUES (@u_mirza,'Senada','9999999000004','2004-06-09','Testna ulica 4','Vitez','Vitez','060-000-0004',
 'Pravni fakultet','Univerzitet u Zenici','Pravo','I',1,'TEST-004',
 8.40,'TEST-RACUN-000000004','DOMACI','Demo banka');
SET @s_mirza = LAST_INSERT_ID();
INSERT INTO studenti (korisnik_id,ime_roditelja,jmbg,datum_rodjenja,adresa,mjesto,opcina,telefon,
 naziv_fakulteta,naziv_univerziteta,smjer,ciklus_studija,godina_studija,broj_indeksa,
 prosjek_ocjena,broj_racuna,vrsta_racuna,naziv_banke)
VALUES (@u_tarik,'Amra','9999999000005','2004-12-05','Testna ulica 5','Vitez','Vitez','060-000-0005',
 'Elektrotehnicki fakultet','Univerzitet u Sarajevu','Elektroenergetika','I',1,'TEST-005',
 8.90,'TEST-RACUN-000000005','DOMACI','Demo banka');
SET @s_tarik = LAST_INSERT_ID();
UPDATE korisnicke_postavke SET tema='DARK',stavki_po_stranici=50 WHERE korisnik_id=@admin;
UPDATE korisnicke_postavke SET tema='DARK' WHERE korisnik_id=@u_lejla;

-- ---------------------------------------------------------------------------
-- 2. KONKURSI / KATEGORIJE / KOMISIJA
-- ---------------------------------------------------------------------------
INSERT INTO konkursi (naziv,akademska_godina,opis,ukupan_budzet,broj_stipendija,
 datum_od,datum_do,rok_dopune,rok_zalbi,status,kreirao_korisnik_id)
VALUES ('DEMO: Konkurs sa obradom 2026/2027','2026/2027',
 'Testni konkurs koji seed podnosi i zatvara ranije radi simulacije toka komisije.',
 24000.00,4,@od_demo,@do_demo,@dopuna_demo,@zalba_demo,'OTVOREN',@admin);
SET @k_demo = LAST_INSERT_ID();
INSERT INTO konkursi (naziv,akademska_godina,opis,ukupan_budzet,broj_stipendija,
 datum_od,datum_do,rok_dopune,rok_zalbi,status,kreirao_korisnik_id)
VALUES ('DEMO: Otvoreni konkurs 2026/2027','2026/2027',
 'Otvoren konkurs za dodatno testiranje studentske prijave i dokumentacije.',
 15000.00,3,@sada - INTERVAL 2 DAY,@sada + INTERVAL 45 DAY,
 @sada + INTERVAL 55 DAY,@sada + INTERVAL 65 DAY,'OTVOREN',@admin);
SET @k_otvoreni = LAST_INSERT_ID();
INSERT INTO konkursi (naziv,akademska_godina,opis,ukupan_budzet,broj_stipendija,
 datum_od,datum_do,status,kreirao_korisnik_id)
VALUES ('DEMO: Nacrt buduceg konkursa 2027/2028','2027/2028',
 'Konkurs u pripremi, bez studentskih prijava.',
 35000.00,7,@sada + INTERVAL 150 DAY,@sada + INTERVAL 190 DAY,'NACRT',@admin);
SET @k_nacrt = LAST_INSERT_ID();

INSERT INTO kategorije_stipendija (konkurs_id,naziv,opis,kvota_stipendija,min_prosjek)
VALUES (@k_demo,'Opca kategorija - uspjeh','Kriteriji uspjeha na studiju.',1,8.00);
SET @kat_opca = LAST_INSERT_ID();
INSERT INTO kategorije_stipendija (konkurs_id,naziv,opis,kvota_stipendija,min_prosjek)
VALUES (@k_demo,'Socijalna kategorija','Prioritet studentima s nizim prihodima po clanu.',2,7.50);
SET @kat_soc = LAST_INSERT_ID();
INSERT INTO kategorije_stipendija (konkurs_id,naziv,opis,kvota_stipendija,min_prosjek)
VALUES (@k_demo,'Boracka populacija','Posebna kategorija uz dokaz o statusu.',1,7.00);
SET @kat_bor = LAST_INSERT_ID();
INSERT INTO kategorije_stipendija (konkurs_id,naziv,opis,kvota_stipendija,min_prosjek)
VALUES (@k_otvoreni,'Deficitarna zanimanja','Otvoreni demo konkurs.',2,7.00);
SET @kat_def = LAST_INSERT_ID();
INSERT INTO kategorije_stipendija (konkurs_id,naziv,kvota_stipendija,min_prosjek)
VALUES (@k_otvoreni,'Nadareni studenti',1,9.00);
SET @kat_nadareni = LAST_INSERT_ID();
INSERT INTO kategorije_stipendija (konkurs_id,naziv,kvota_stipendija)
VALUES (@k_nacrt,'Opca kategorija - nacrt',7);

INSERT INTO clanovi_komisije_konkursa (konkurs_id,korisnik_id)
VALUES (@k_demo,@kom1),(@k_demo,@kom2),(@k_otvoreni,@kom1);

-- ---------------------------------------------------------------------------
-- 3. KONFIGURACIJA USLOVA, KRITERIJA, SKALA, TIE-BREAKERA I PDF ZAHTJEVA
-- Sve prije prvog podnosenja prijave, kao sto zahtijevaju triggeri.
-- ---------------------------------------------------------------------------
INSERT INTO uslovi_kategorija (kategorija_id,izvor_sifra,operator_poredjenja,vrijednost_broj)
VALUES (@kat_opca,'PROSJEK_OCJENA','GTE',8.0000),
       (@kat_soc,'PROSJEK_OCJENA','GTE',7.5000),
       (@kat_bor,'PROSJEK_OCJENA','GTE',7.0000);
INSERT INTO kriteriji_bodovanja
 (konkurs_id,kategorija_id,naziv,opis,tip_kriterija,izvor_sifra,koeficijent,fiksni_bodovi,max_bodova)
VALUES (@k_demo,NULL,'Prosjek ocjena','Prosjek ocjena x 5.','FORMULA','PROSJEK_OCJENA',5.0000,NULL,50.00);
SET @kr_prosjek = LAST_INSERT_ID();
INSERT INTO kriteriji_bodovanja
 (konkurs_id,kategorija_id,naziv,opis,tip_kriterija,izvor_sifra,koeficijent,fiksni_bodovi,max_bodova)
VALUES (@k_demo,NULL,'Godina studija','Godina studija x 2.','FORMULA','GODINA_STUDIJA',2.0000,NULL,10.00);
SET @kr_godina = LAST_INSERT_ID();
INSERT INTO kriteriji_bodovanja
 (konkurs_id,kategorija_id,naziv,opis,tip_kriterija,izvor_sifra,koeficijent,fiksni_bodovi,max_bodova)
VALUES (@k_demo,@kat_soc,'Prihodi po clanu','Skala prosjecnih mjesecnih prihoda.',
 'SKALA','PRIHOD_PO_CLANU',NULL,NULL,30.00);
SET @kr_prihod = LAST_INSERT_ID();
INSERT INTO kriteriji_bodovanja
 (konkurs_id,kategorija_id,naziv,opis,tip_kriterija,izvor_sifra,koeficijent,fiksni_bodovi,max_bodova)
VALUES (@k_demo,@kat_bor,'Boracki status','Dokazani status nosi 10 bodova.',
 'DA_NE','BORACKA_KATEGORIJA',NULL,10.00,10.00);
SET @kr_borac = LAST_INSERT_ID();
INSERT INTO kriteriji_bodovanja
 (konkurs_id,kategorija_id,naziv,opis,tip_kriterija,izvor_sifra,koeficijent,fiksni_bodovi,max_bodova)
VALUES (@k_otvoreni,@kat_def,'Uspjeh za deficitarna zanimanja','Prosjek x 4.',
 'FORMULA','PROSJEK_OCJENA',4.0000,NULL,40.00);

INSERT INTO skale_kriterija (kriterij_id,od_vrijednost,do_vrijednost,bodovi)
VALUES (@kr_prihod,0.0000,300.0000,30.00),
       (@kr_prihod,300.0001,600.0000,20.00),
       (@kr_prihod,600.0001,1200.0000,10.00),
       (@kr_prihod,1200.0001,999999.0000,0.00);

INSERT INTO pravila_izjednacenja (konkurs_id,kategorija_id,prioritet,pravilo)
VALUES (@k_demo,@kat_opca,1,'VISI_PROSJEK'),
       (@k_demo,@kat_opca,2,'NIZI_PRIHOD_PO_CLANU'),
       (@k_demo,@kat_opca,3,'VISA_GODINA_STUDIJA'),
       (@k_demo,@kat_opca,4,'RANIJE_VRIJEME_PRIJAVE');

INSERT INTO zahtjevi_dokumenata
 (konkurs_id,kategorija_id,tip_dokumenta_id,obavezan,maksimalno_bajta,odnosi_se_na,napomena)
VALUES (@k_demo,NULL,@tip_cips,TRUE,5242880,'STUDENT','PDF CIPS dokumenta');
SET @z_cips = LAST_INSERT_ID();
INSERT INTO zahtjevi_dokumenata
 (konkurs_id,kategorija_id,tip_dokumenta_id,obavezan,maksimalno_bajta,odnosi_se_na)
VALUES (@k_demo,NULL,@tip_studiranje,TRUE,5242880,'STUDENT');
SET @z_studiranje = LAST_INSERT_ID();
INSERT INTO zahtjevi_dokumenata
 (konkurs_id,kategorija_id,tip_dokumenta_id,obavezan,odnosi_se_na)
VALUES (@k_demo,NULL,@tip_kucna,TRUE,'STUDENT');
SET @z_kucna = LAST_INSERT_ID();
INSERT INTO zahtjevi_dokumenata
 (konkurs_id,kategorija_id,tip_dokumenta_id,obavezan,godina_od,odnosi_se_na)
VALUES (@k_demo,NULL,@tip_ocjene,TRUE,2,'STUDENT');
SET @z_ocjene = LAST_INSERT_ID();
INSERT INTO zahtjevi_dokumenata
 (konkurs_id,kategorija_id,tip_dokumenta_id,obavezan,odnosi_se_na)
VALUES (@k_demo,@kat_bor,@tip_borac,TRUE,'STUDENT');
SET @z_borac = LAST_INSERT_ID();
INSERT INTO zahtjevi_dokumenata
 (konkurs_id,kategorija_id,tip_dokumenta_id,obavezan,odnosi_se_na)
VALUES (@k_demo,@kat_soc,@tip_plata,FALSE,'SVI_PUNOLJETNI');
SET @z_plata = LAST_INSERT_ID();
INSERT INTO zahtjevi_dokumenata
 (konkurs_id,kategorija_id,tip_dokumenta_id,obavezan,odnosi_se_na)
VALUES (@k_otvoreni,NULL,@tip_cips,TRUE,'STUDENT');
SET @z_cips_otvoreni = LAST_INSERT_ID();

-- ---------------------------------------------------------------------------
-- 4. PRIJAVE: prvo DRAFT (obavezno), potom kucne liste, pa PODNESENA.
-- ---------------------------------------------------------------------------
INSERT INTO prijave (student_id,konkurs_id,kategorija_id,fakultet_snapshot,univerzitet_snapshot,
 smjer_snapshot,ciklus_studija_snapshot,godina_studija_snapshot,prosjek_ocjena_snapshot)
VALUES (@s_lejla,@k_demo,@kat_opca,'Politehnicki fakultet','Univerzitet u Zenici',
 'Softversko inzenjerstvo','I',2,9.50);
SET @p_lejla = LAST_INSERT_ID();
INSERT INTO prijave (student_id,konkurs_id,kategorija_id,fakultet_snapshot,univerzitet_snapshot,
 smjer_snapshot,ciklus_studija_snapshot,godina_studija_snapshot,prosjek_ocjena_snapshot)
VALUES (@s_amar,@k_demo,@kat_opca,'Politehnicki fakultet','Univerzitet u Zenici',
 'Softversko inzenjerstvo','I',2,9.70);
SET @p_amar = LAST_INSERT_ID();
INSERT INTO prijave (student_id,konkurs_id,kategorija_id,fakultet_snapshot,univerzitet_snapshot,
 smjer_snapshot,ciklus_studija_snapshot,godina_studija_snapshot,prosjek_ocjena_snapshot)
VALUES (@s_nejla,@k_demo,@kat_soc,'Ekonomski fakultet','Univerzitet u Travniku',
 'Ekonomija','I',3,9.20);
SET @p_nejla = LAST_INSERT_ID();
INSERT INTO prijave (student_id,konkurs_id,kategorija_id,fakultet_snapshot,univerzitet_snapshot,
 smjer_snapshot,ciklus_studija_snapshot,godina_studija_snapshot,prosjek_ocjena_snapshot)
VALUES (@s_mirza,@k_demo,@kat_bor,'Pravni fakultet','Univerzitet u Zenici',
 'Pravo','I',1,8.40);
SET @p_mirza = LAST_INSERT_ID();
INSERT INTO prijave (student_id,konkurs_id,kategorija_id,fakultet_snapshot,univerzitet_snapshot,
 smjer_snapshot,ciklus_studija_snapshot,godina_studija_snapshot,prosjek_ocjena_snapshot)
VALUES (@s_tarik,@k_otvoreni,@kat_def,'Elektrotehnicki fakultet','Univerzitet u Sarajevu',
 'Elektroenergetika','I',1,8.90);
SET @p_tarik = LAST_INSERT_ID();

-- Kucna lista: clan sa je_podnosilac=TRUE je obavezan za slanje prijave.
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana,je_podnosilac)
VALUES (@p_lejla,'Lejla Primjer','STUDENT',2003,'STUDENT_UCENIK',TRUE);
SET @cl_lejla = LAST_INSERT_ID();
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana)
VALUES (@p_lejla,'Haris Primjer','OTAC',1974,'PENZIONER');
SET @cl_lejla_otac = LAST_INSERT_ID();
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana)
VALUES (@p_lejla,'Jasna Primjer','MAJKA',1977,'ZAPOSLEN');
SET @cl_lejla_majka = LAST_INSERT_ID();
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana,je_podnosilac)
VALUES (@p_amar,'Amar Ogledic','STUDENT',2002,'STUDENT_UCENIK',TRUE);
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana)
VALUES (@p_amar,'Enisa Ogledic','MAJKA',1978,'ZAPOSLEN');
SET @cl_amar_majka = LAST_INSERT_ID();
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana)
VALUES (@p_amar,'Hasan Ogledic','OTAC',1972,'NEZAPOSLEN');
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana,je_podnosilac)
VALUES (@p_nejla,'Nejla Uzorak','STUDENT',2001,'STUDENT_UCENIK',TRUE);
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana)
VALUES (@p_nejla,'Mira Uzorak','MAJKA',1975,'ZAPOSLEN');
SET @cl_nejla_majka = LAST_INSERT_ID();
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana)
VALUES (@p_nejla,'Omer Uzorak','OTAC',1970,'PENZIONER');
SET @cl_nejla_otac = LAST_INSERT_ID();
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana)
VALUES (@p_nejla,'Emina Uzorak','SESTRA',2008,'STUDENT_UCENIK');
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana,je_podnosilac)
VALUES (@p_mirza,'Mirza Testic','STUDENT',2004,'STUDENT_UCENIK',TRUE);
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana)
VALUES (@p_mirza,'Senada Testic','MAJKA',1980,'ZAPOSLEN');
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana,je_podnosilac)
VALUES (@p_tarik,'Tarik Model','STUDENT',2004,'STUDENT_UCENIK',TRUE);
INSERT INTO clanovi_domacinstva (prijava_id,ime_prezime,srodstvo,godina_rodjenja,status_clana)
VALUES (@p_tarik,'Amra Model','MAJKA',1979,'ZAPOSLEN');
SET @cl_tarik_majka = LAST_INSERT_ID();

INSERT INTO primanja_clanova (clan_domacinstva_id,vrsta_primanja,opis,mjesecni_iznos)
VALUES (@cl_lejla_otac,'PENZIJA','Testna mjesecna penzija',500.00),
       (@cl_lejla_majka,'PLATA','Testna mjesecna plata',900.00),
       (@cl_amar_majka,'PLATA','Testna mjesecna plata',1300.00),
       (@cl_nejla_majka,'PLATA','Testna mjesecna plata',650.00),
       (@cl_nejla_otac,'PENZIJA','Testna penzija',400.00),
       (@cl_tarik_majka,'PLATA','Testna mjesecna plata',1100.00);
-- Dodatno socijalno/statusno svojstvo za boracku kategoriju.
INSERT INTO cinjenice_prijave (prijava_id,izvor_sifra,vrijednost_bool)
VALUES (@p_mirza,'BORACKA_KATEGORIJA',TRUE);
SET @cin_borac = LAST_INSERT_ID();

-- ---------------------------------------------------------------------------
-- 5. PDF METAPODACI I VERZIJE (DEMO STORAGE KLJUCEVI - FAJLOVI NE POSTOJE)
-- Sve prve verzije se pohranjuju dok su prijave DRAFT, konkurs OTVOREN.
-- ---------------------------------------------------------------------------
INSERT INTO pdf_datoteke (originalni_naziv,sigurni_naziv,storage_kljuc,velicina_bajta,sha256_hash,postavio_korisnik_id)
VALUES ('cips_lejla.pdf','demo-cips-lejla-v1.pdf','demo/konkurs-obrada/lejla/cips-v1.pdf',20480,
 SHA2('DEMO-SADRZAJ-CIPS-LEJLA-V1',256),@u_lejla);
SET @pdf_l_cips = LAST_INSERT_ID();
INSERT INTO dokumenti_prijave (prijava_id,zahtjev_dokumenta_id,verzija,pdf_datoteka_id)
VALUES (@p_lejla,@z_cips,1,@pdf_l_cips);
SET @d_lejla_cips = LAST_INSERT_ID();
INSERT INTO pdf_datoteke (originalni_naziv,sigurni_naziv,storage_kljuc,velicina_bajta,sha256_hash,postavio_korisnik_id)
VALUES ('potvrda_studiranja.pdf','demo-stud-lejla-v1.pdf','demo/konkurs-obrada/lejla/studiranje-v1.pdf',16384,
 SHA2('DEMO-SADRZAJ-STUDIRANJE-LEJLA-V1',256),@u_lejla);
SET @pdf_l_stud1 = LAST_INSERT_ID();
INSERT INTO dokumenti_prijave (prijava_id,zahtjev_dokumenta_id,verzija,pdf_datoteka_id)
VALUES (@p_lejla,@z_studiranje,1,@pdf_l_stud1);
SET @d_lejla_stud1 = LAST_INSERT_ID();
INSERT INTO pdf_datoteke (originalni_naziv,sigurni_naziv,storage_kljuc,velicina_bajta,sha256_hash,postavio_korisnik_id)
VALUES ('cips_amar.pdf','demo-cips-amar-v1.pdf','demo/konkurs-obrada/amar/cips-v1.pdf',18432,
 SHA2('DEMO-SADRZAJ-CIPS-AMAR-V1',256),@u_amar);
SET @pdf_a_cips = LAST_INSERT_ID();
INSERT INTO dokumenti_prijave (prijava_id,zahtjev_dokumenta_id,verzija,pdf_datoteka_id)
VALUES (@p_amar,@z_cips,1,@pdf_a_cips);
SET @d_amar_cips = LAST_INSERT_ID();
INSERT INTO pdf_datoteke (originalni_naziv,sigurni_naziv,storage_kljuc,velicina_bajta,sha256_hash,postavio_korisnik_id)
VALUES ('kucna_lista_nejla.pdf','demo-kucna-nejla-v1.pdf','demo/konkurs-obrada/nejla/kucna-v1.pdf',24000,
 SHA2('DEMO-SADRZAJ-KUCNA-NEJLA-V1',256),@u_nejla);
SET @pdf_n_kucna = LAST_INSERT_ID();
INSERT INTO dokumenti_prijave (prijava_id,zahtjev_dokumenta_id,verzija,pdf_datoteka_id)
VALUES (@p_nejla,@z_kucna,1,@pdf_n_kucna);
SET @d_nejla_kucna = LAST_INSERT_ID();
INSERT INTO pdf_datoteke (originalni_naziv,sigurni_naziv,storage_kljuc,velicina_bajta,sha256_hash,postavio_korisnik_id)
VALUES ('boracki_status_mirza.pdf','demo-bor-mirza-v1.pdf','demo/konkurs-obrada/mirza/boracki-v1.pdf',24576,
 SHA2('DEMO-SADRZAJ-BORACKI-MIRZA-V1',256),@u_mirza);
SET @pdf_m_borac = LAST_INSERT_ID();
INSERT INTO dokumenti_prijave (prijava_id,zahtjev_dokumenta_id,verzija,pdf_datoteka_id)
VALUES (@p_mirza,@z_borac,1,@pdf_m_borac);
SET @d_mirza_borac = LAST_INSERT_ID();

-- Pet prijava; jednu ostavljamo u otvorenom konkursu, ostale idu u obradu.
UPDATE prijave SET status='PODNESENA' WHERE id=@p_lejla;
UPDATE prijave SET status='PODNESENA' WHERE id=@p_amar;
UPDATE prijave SET status='PODNESENA' WHERE id=@p_nejla;
UPDATE prijave SET status='PODNESENA' WHERE id=@p_mirza;
UPDATE prijave SET status='PODNESENA' WHERE id=@p_tarik;

-- ---------------------------------------------------------------------------
-- 6. SIMULACIJA ZATVARANJA KONKURSA, RASPODJELA KOMISIJI I VERIFIKACIJA
-- ---------------------------------------------------------------------------
-- Ovo je DEMO prijelaz u ZATVOREN iako datum_do jos nije prosao.
UPDATE konkursi SET status='ZATVOREN',izmijenio_korisnik_id=@admin WHERE id=@k_demo;
INSERT INTO dodjele_prijava (prijava_id,komisija_korisnik_id,dodijelio_korisnik_id,status)
VALUES (@p_lejla,@kom1,@admin,'DODIJELJENA'),
       (@p_amar,@kom2,@admin,'DODIJELJENA'),
       (@p_nejla,@kom1,@admin,'DODIJELJENA'),
       (@p_mirza,@kom2,@admin,'DODIJELJENA');
UPDATE dodjele_prijava SET status='U_OBRADI' WHERE prijava_id IN (@p_lejla,@p_amar,@p_nejla,@p_mirza);
UPDATE prijave SET status='U_PROVJERI' WHERE id IN (@p_lejla,@p_amar,@p_nejla,@p_mirza);

UPDATE dokumenti_prijave SET status='ODOBREN',pregledao_korisnik_id=@kom1
WHERE id=@d_lejla_cips;
UPDATE dokumenti_prijave
SET status='DOPUNA_TRAZENA',napomena_komisije='Molimo dostaviti citljiv PDF potvrde o studiranju.',
 pregledao_korisnik_id=@kom1
WHERE id=@d_lejla_stud1;
-- AFTER UPDATE trigger je sada postavio status prijave = DOPUNA_TRAZENA.
INSERT INTO pdf_datoteke (originalni_naziv,sigurni_naziv,storage_kljuc,velicina_bajta,sha256_hash,postavio_korisnik_id)
VALUES ('potvrda_studiranja_dopuna.pdf','demo-stud-lejla-v2.pdf','demo/konkurs-obrada/lejla/studiranje-v2.pdf',20000,
 SHA2('DEMO-SADRZAJ-STUDIRANJE-LEJLA-V2',256),@u_lejla);
SET @pdf_l_stud2 = LAST_INSERT_ID();
INSERT INTO dokumenti_prijave (prijava_id,zahtjev_dokumenta_id,verzija,pdf_datoteka_id)
VALUES (@p_lejla,@z_studiranje,2,@pdf_l_stud2);
SET @d_lejla_stud2 = LAST_INSERT_ID();
UPDATE dokumenti_prijave SET status='ODOBREN',pregledao_korisnik_id=@kom1
WHERE id=@d_lejla_stud2;
UPDATE dokumenti_prijave SET status='ODOBREN',pregledao_korisnik_id=@kom2
WHERE id=@d_amar_cips;
UPDATE dokumenti_prijave SET status='ODOBREN',pregledao_korisnik_id=@kom1
WHERE id=@d_nejla_kucna;
UPDATE dokumenti_prijave SET status='ODOBREN',pregledao_korisnik_id=@kom2
WHERE id=@d_mirza_borac;
UPDATE cinjenice_prijave SET verifikovano=TRUE,verifikovao_korisnik_id=@kom2
WHERE id=@cin_borac;
UPDATE prijave SET status='PROVJERENA' WHERE id IN (@p_lejla,@p_amar,@p_nejla,@p_mirza);

-- ---------------------------------------------------------------------------
-- 7. AUTOMATSKO BODOVANJE I JEDNA RUCNA KOREKCIJA (generise historiju + audit)
-- ---------------------------------------------------------------------------
INSERT INTO bodovi_prijave
 (prijava_id,kriterij_id,ulazna_vrijednost,automatski_bodovi,konacni_bodovi)
VALUES (@p_lejla,@kr_prosjek,9.5000,47.50,47.50),
       (@p_lejla,@kr_godina,2.0000,4.00,4.00),
       (@p_amar,@kr_prosjek,9.7000,48.50,48.50),
       (@p_amar,@kr_godina,2.0000,4.00,4.00),
       (@p_nejla,@kr_prosjek,9.2000,46.00,46.00),
       (@p_nejla,@kr_godina,3.0000,6.00,6.00),
       (@p_nejla,@kr_prihod,262.5000,30.00,30.00),
       (@p_mirza,@kr_prosjek,8.4000,42.00,42.00),
       (@p_mirza,@kr_godina,1.0000,2.00,2.00),
       (@p_mirza,@kr_borac,1.0000,10.00,10.00);
-- Amar dobiva korekciju 48.50 -> 47.50; ukupno 51.50 kao Lejla.
-- Tie-breaker VISI_PROSJEK favorizuje Amara (9.70 > 9.50).
UPDATE bodovi_prijave SET je_rucno_korigovano=TRUE,
 korigovani_bodovi=47.50,konacni_bodovi=47.50,
 obrazlozenje_korekcije='Testno uskladjivanje koeficijenta po komisijskoj provjeri.',
 korigovao_korisnik_id=@kom2
WHERE prijava_id=@p_amar AND kriterij_id=@kr_prosjek;
UPDATE prijave SET status='BODOVANA' WHERE id IN (@p_lejla,@p_amar,@p_nejla,@p_mirza);

-- ---------------------------------------------------------------------------
-- 8. PRELIMINARNA RANG-LISTA v1 -> POTVRDJENA -> OBJAVLJENA
-- ---------------------------------------------------------------------------
INSERT INTO rang_liste (kategorija_id,verzija_broj,tip_liste,kreirao_korisnik_id)
VALUES (@kat_opca,1,'PRELIMINARNA',@admin);
SET @lista_prelim = LAST_INSERT_ID();
INSERT INTO rang_lista_stavke
 (rang_lista_id,prijava_id,pozicija,ukupno_bodova,ime_studenta_snapshot,
 prezime_studenta_snapshot,prosjek_snapshot,prihod_po_clanu_snapshot,
 godina_studija_snapshot,vrijeme_zaprimanja_snapshot,status_stipendije,primijenjen_tie_breaker)
SELECT @lista_prelim,p.id,
 CASE WHEN p.id=@p_amar THEN 1 ELSE 2 END,
 51.50,u.ime,u.prezime,p.prosjek_ocjena_snapshot,v.prihod_po_clanu,
 p.godina_studija_snapshot,p.vrijeme_zaprimanja,
 CASE WHEN p.id=@p_amar THEN 'OSTVARIO' ELSE 'ISPOD_CRTE' END,
 'VISI_PROSJEK'
FROM prijave p
JOIN studenti s ON s.id=p.student_id
JOIN korisnici u ON u.id=s.korisnik_id
JOIN v_prihodi_domacinstva v ON v.prijava_id=p.id
WHERE p.id IN (@p_lejla,@p_amar);
UPDATE rang_liste SET status='POTVRDJENA',potvrdio_korisnik_id=@kom1 WHERE id=@lista_prelim;
UPDATE rang_liste SET status='OBJAVLJENA',objavio_korisnik_id=@admin WHERE id=@lista_prelim;
UPDATE prijave SET status='NA_RANG_LISTI' WHERE id IN (@p_lejla,@p_amar);

-- ---------------------------------------------------------------------------
-- 9. STUDENTSKA ZALBA (samo na objavljenu preliminarnu listu) I ODLUKA
-- ---------------------------------------------------------------------------
INSERT INTO zalbe (prijava_id,rang_lista_id,tekst_zalbe)
VALUES (@p_lejla,@lista_prelim,
 'Testna zalba: molim dodatnu provjeru obracuna prosjeka ocjena na preliminarnoj listi.');
SET @zalba_lejla = LAST_INSERT_ID();
UPDATE zalbe SET status='U_OBRADI' WHERE id=@zalba_lejla;
UPDATE zalbe SET status='ODBIJENA',
 odluka_obrazlozenje='Komisija je ponovo provjerila bodove; odluka preliminarne liste ostaje ista.',
 rijesio_korisnik_id=@kom1 WHERE id=@zalba_lejla;

-- ---------------------------------------------------------------------------
-- 10. KONACNA RANG-LISTA v2: NOVI snapshot, nista ne prepisuje preliminarnu.
-- ---------------------------------------------------------------------------
INSERT INTO rang_liste (kategorija_id,verzija_broj,tip_liste,kreirao_korisnik_id)
VALUES (@kat_opca,2,'KONACNA',@admin);
SET @lista_konacna = LAST_INSERT_ID();
INSERT INTO rang_lista_stavke
 (rang_lista_id,prijava_id,pozicija,ukupno_bodova,ime_studenta_snapshot,
 prezime_studenta_snapshot,prosjek_snapshot,prihod_po_clanu_snapshot,
 godina_studija_snapshot,vrijeme_zaprimanja_snapshot,status_stipendije,primijenjen_tie_breaker)
SELECT @lista_konacna,p.id,
 CASE WHEN p.id=@p_amar THEN 1 ELSE 2 END,
 51.50,u.ime,u.prezime,p.prosjek_ocjena_snapshot,v.prihod_po_clanu,
 p.godina_studija_snapshot,p.vrijeme_zaprimanja,
 CASE WHEN p.id=@p_amar THEN 'OSTVARIO' ELSE 'ISPOD_CRTE' END,
 'VISI_PROSJEK'
FROM prijave p
JOIN studenti s ON s.id=p.student_id
JOIN korisnici u ON u.id=s.korisnik_id
JOIN v_prihodi_domacinstva v ON v.prijava_id=p.id
WHERE p.id IN (@p_lejla,@p_amar);
UPDATE rang_liste SET status='POTVRDJENA',potvrdio_korisnik_id=@kom1 WHERE id=@lista_konacna;
UPDATE rang_liste SET status='OBJAVLJENA',objavio_korisnik_id=@admin WHERE id=@lista_konacna;
UPDATE prijave SET status='ODOBRENA' WHERE id=@p_amar;
UPDATE prijave SET status='ODBIJENA' WHERE id=@p_lejla;
UPDATE konkursi SET status='OBJAVLJEN',izmijenio_korisnik_id=@admin WHERE id=@k_demo;

-- ---------------------------------------------------------------------------
-- 11. SABLON, UGOVOR, RATE (ugovor samo za pobjednika na KONACNOJ listi)
-- ---------------------------------------------------------------------------
INSERT INTO sabloni_ugovora (naziv,verzija,sadrzaj_sablona,kreirao_korisnik_id)
VALUES ('Demo sablon ugovora o stipendiranju',1,
 'Ugovor izmedju Opcine Vitez i {{student_ime}} {{student_prezime}}; iznos {{mjesecni_iznos}}.',
 @admin);
SET @sablon = LAST_INSERT_ID();
SELECT id INTO @stavka_pobjednik FROM rang_lista_stavke
 WHERE rang_lista_id=@lista_konacna AND prijava_id=@p_amar;
INSERT INTO ugovori
 (prijava_id,rang_stavka_id,sablon_id,broj_ugovora,broj_racuna_snapshot,naziv_banke_snapshot,
 datum_ugovora,mjesecni_iznos,broj_rata,status,kreirao_korisnik_id)
VALUES (@p_amar,@stavka_pobjednik,@sablon,'DEMO-UG-2026-001',
 'TEST-RACUN-000000002','Demo banka',UTC_DATE(),250.00,3,'NACRT',@admin);
SET @ugovor_amar = LAST_INSERT_ID();
UPDATE ugovori SET datum_potpisivanja=UTC_DATE(),status='POTPISAN' WHERE id=@ugovor_amar;
INSERT INTO isplate (ugovor_id,broj_rate,iznos,planirano_za,status,evidentirao_korisnik_id)
VALUES (@ugovor_amar,1,250.00,UTC_DATE(),'PLANIRANA',@admin),
       (@ugovor_amar,2,250.00,UTC_DATE()+INTERVAL 1 MONTH,'PLANIRANA',@admin),
       (@ugovor_amar,3,250.00,UTC_DATE()+INTERVAL 2 MONTH,'PLANIRANA',@admin);
UPDATE isplate SET status='ISPLACENA',referenca_transakcije='DEMO-TX-0001'
WHERE ugovor_id=@ugovor_amar AND broj_rate=1;

-- ---------------------------------------------------------------------------
-- 12. NOTIFIKACIJE, BACKUP I DODATNI AUDIT TEST ZAPIS
-- ---------------------------------------------------------------------------
INSERT INTO notifikacije (korisnik_id,prijava_id,konkurs_id,naslov,poruka,tip)
VALUES (@u_lejla,@p_lejla,@k_demo,'Potrebna dopuna','Nova verzija PDF potvrde je zatrazena.','DOPUNA'),
       (@u_amar,@p_amar,@k_demo,'Konačna rang-lista','Ostvareno pravo na stipendiju.','RANG_LISTA'),
       (@u_nejla,@p_nejla,@k_demo,'Bodovanje završeno','Prijava je bodovana.','PRIJAVA'),
       (@u_tarik,@p_tarik,@k_otvoreni,'Prijava zaprimljena','Prijava je uspjesno podnesena.','PRIJAVA');
UPDATE notifikacije SET procitano=TRUE WHERE korisnik_id=@u_lejla AND tip='DOPUNA';

-- Evidencija backupa nije stvarni backup fajl.
INSERT INTO backup_evidencija (pokrenuo_korisnik_id,status,napomena)
VALUES (@admin,'U_TOKU','DEMO: simulacija backup procesa bez izrade kopije baze.');
SET @backup_id=LAST_INSERT_ID();
UPDATE backup_evidencija SET status='NEUSPJESNO',zavrsetak_at=UTC_TIMESTAMP(6),
 napomena='DEMO: backup nije fizicki izvrsen; ovo je samo testna evidencija.'
WHERE id=@backup_id;
INSERT INTO audit_log (korisnik_id,akcija,entitet,entitet_id,opis)
VALUES (@admin,'OTHER','seed',NULL,'Testni skup podataka kreiran. Svi identiteti su izmisljeni.');

COMMIT;

-- ---------------------------------------------------------------------------
-- 13. KONTROLNI UPITI: redni brojevi, historija, 1:1, pregled workflowa
-- Ovi SELECT-i su read-only i korisni u MySQL Workbenchu / konzoli.
-- ---------------------------------------------------------------------------
SELECT 'korisnici' AS tabela,COUNT(*) AS broj FROM korisnici
UNION ALL SELECT 'studenti',COUNT(*) FROM studenti
UNION ALL SELECT 'konkursi',COUNT(*) FROM konkursi
UNION ALL SELECT 'kategorije_stipendija',COUNT(*) FROM kategorije_stipendija
UNION ALL SELECT 'prijave',COUNT(*) FROM prijave
UNION ALL SELECT 'clanovi_domacinstva',COUNT(*) FROM clanovi_domacinstva
UNION ALL SELECT 'primanja_clanova',COUNT(*) FROM primanja_clanova
UNION ALL SELECT 'pdf_datoteke (metadata)',COUNT(*) FROM pdf_datoteke
UNION ALL SELECT 'dokumenti_prijave',COUNT(*) FROM dokumenti_prijave
UNION ALL SELECT 'dodjele_prijava',COUNT(*) FROM dodjele_prijava
UNION ALL SELECT 'bodovi_prijave',COUNT(*) FROM bodovi_prijave
UNION ALL SELECT 'historija_korekcija',COUNT(*) FROM historija_korekcija
UNION ALL SELECT 'rang_liste',COUNT(*) FROM rang_liste
UNION ALL SELECT 'rang_lista_stavke',COUNT(*) FROM rang_lista_stavke
UNION ALL SELECT 'zalbe',COUNT(*) FROM zalbe
UNION ALL SELECT 'ugovori',COUNT(*) FROM ugovori
UNION ALL SELECT 'isplate',COUNT(*) FROM isplate
UNION ALL SELECT 'notifikacije',COUNT(*) FROM notifikacije
UNION ALL SELECT 'backup_evidencija',COUNT(*) FROM backup_evidencija
UNION ALL SELECT 'audit_log',COUNT(*) FROM audit_log;

SELECT p.id,p.broj_protokola,p.status,k.naziv AS konkurs,kat.naziv AS kategorija,
       u.korisnicko_ime AS student,v.broj_clanova,v.prihod_po_clanu
FROM prijave p JOIN studenti s ON s.id=p.student_id JOIN korisnici u ON u.id=s.korisnik_id
JOIN konkursi k ON k.id=p.konkurs_id JOIN kategorije_stipendija kat ON kat.id=p.kategorija_id
LEFT JOIN v_prihodi_domacinstva v ON v.prijava_id=p.id ORDER BY p.id;

SELECT rl.id,rl.verzija_broj,rl.tip_liste,rl.status,rs.pozicija,rs.ukupno_bodova,
       rs.ime_studenta_snapshot,rs.prezime_studenta_snapshot,rs.status_stipendije
FROM rang_liste rl JOIN rang_lista_stavke rs ON rs.rang_lista_id=rl.id
ORDER BY rl.kategorija_id,rl.verzija_broj,rs.pozicija;
