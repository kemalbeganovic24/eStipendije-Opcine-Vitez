# Vitez eStipendija

Desktop aplikacija za upravljanje stipendijama Općine Vitez.

*Radni naziv projekta. Projektni zadatak iz predmeta Metode razvoja softvera, Politehnički fakultet Univerziteta u Zenici, akademska 2026/2027.*

![CI](https://github.com/<korisnik>/<repozitorij>/actions/workflows/ci.yml/badge.svg)

---

## 1. O projektu

### Problem
Dodjela općinskih stipendija se danas oslanja na papirne prijave, ručnu provjeru dokumenata i ručno bodovanje. To je sporo, podložno greškama i teško za praćenje, a građani nemaju uvid u to kako je odluka donesena.

### Rješenje
StipVitez digitalizira cijeli proces na strani općine: od kreiranja konkursa i unosa prijava, preko provjere dokumentacije i automatskog bodovanja po pravilniku, do rang-lista, ugovora i izvještaja u PDF formatu.

### Ciljevi
- Smanjiti papirologiju i vrijeme potrebno komisiji za obradu prijava
- Osigurati pravedno i ponovljivo bodovanje prema pravilniku
- Povećati transparentnost kroz evidenciju svake izmjene (audit log)
- Omogućiti brzo generisanje rang-lista, ugovora i izvještaja

### Naručilac
Općina Vitez, Služba za djelatnosti. *(Status saradnje: u razgovoru.)*

---

## 2. Korisničke uloge

- **Administrator:** upravlja konkursima, kriterijima, korisnicima, postavkama i backupom, ima uvid u audit log
- **Član komisije:** pregleda dodijeljene prijave, boduje, korigira bodove uz obrazloženje, potvrđuje rang-listu, odlučuje o žalbama
- **Referent:** unosi prijave i dokumente, provjerava dokumentaciju

---

## 3. Funkcionalnosti

### Autentifikacija i autorizacija
- Prijava korisnika, hashiranje lozinki (BCrypt)
- Kontrola pristupa po ulogama u cijelom interfejsu
- Promjena lozinke, zaključavanje računa nakon više neuspjelih pokušaja

### Konkursi
- Kreiranje i uređivanje konkursa, kategorija, rokova
- Definisanje kriterija bodovanja i obaveznih dokumenata
- Statusi konkursa: nacrt, otvoren, zatvoren, objavljen, arhiviran

### Prijave i dokumenti
- Unos kandidata i prijava kroz korake
- Prilaganje dokumenata uz validaciju tipa i veličine
- Pregled dokumenata u aplikaciji, odobravanje ili odbijanje uz napomenu
- Zaštita od dvostrukih prijava istog kandidata

### Raspodjela, bodovanje i rang-liste
- Nasumična i ravnomjerna raspodjela prijava članovima komisije
- Automatski izračun bodova iz konfigurabilnih pravila
- Ručna korekcija bodova uz obavezno obrazloženje
- Rang-liste s pravilima izjednačenja, potvrda i objava

### Izvještaji i ugovori
- Izvoz rang-lista i izvještaja u PDF (iText / PDFBox) i Excel
- Generisanje ugovora za stipendiste iz šablona

### Dodatno
- Dashboard i grafikoni (prijave po kategoriji, školi i prosjeku)
- Pretraga i filtriranje, svijetla i tamna tema
- Backup baze podataka
- Notifikacije u aplikaciji
- Audit log: ko je, šta i kada promijenio

---

## 4. Tok procesa

1. Administrator kreira konkurs, kategorije, kriterije i listu obaveznih dokumenata, pa ga objavi
2. Referent unosi prijave kandidata i prilaže dokumente
3. Nakon roka, konkurs se zatvara za nove prijave
4. Sistem nasumično raspoređuje prijave članovima komisije
5. Dokumenti se provjeravaju, a po potrebi se traži dopuna
6. Sistem računa bodove, a komisija može korigovati uz obrazloženje
7. Generiše se preliminarna rang-lista i otvara žalbeni rok
8. Nakon žalbi komisija potvrđuje konačnu listu
9. Generišu se ugovori i izvještaji, a konkurs se arhivira

### Statusi prijave
DRAFT, PODNESENA, U_PROVJERI, DOPUNA_TRAŽENA, PROVJERENA, BODOVANA, NA_RANG_LISTI, ODOBRENA, ODBIJENA, ŽALBA, KONAČNA, POVUČENA

---

## 5. Arhitektura

Slojevita (MVC + DAO) desktop aplikacija koja direktno koristi MySQL bazu.

```
+---------------------------------------------+
| VIEW        FXML + CSS                      |
+---------------------------------------------+
| CONTROLLER  JavaFX kontroleri               |
+---------------------------------------------+
| SERVICE     bodovanje, rang-liste, statusi  |
+---------------------------------------------+
| DAO         pristup bazi (JDBC)             |
+---------------------------------------------+
| MySQL       baza podataka                   |
+---------------------------------------------+
  UTIL: PDF, konekcija, validacija, backup
```

Pravila:
- Kontroleri ne pristupaju bazi direktno, samo preko servisa i DAO sloja
- Poslovna pravila (bodovanje, statusi) žive samo u servisnom sloju
- Svi SQL upiti koriste PreparedStatement (zaštita od SQL injectiona)
- Dokumenti se čuvaju na disku, a u bazi su samo putanja, hash i metapodaci

---

## 6. Model podataka (pregled)

Glavne tabele:
- **users**, **roles**: korisnici i uloge
- **competitions**, **categories**, **criteria**, **required_documents**: konkursi i pravila
- **candidates**, **applications**, **application_documents**: prijave i dokumenti
- **score_items**: bodovi po kriteriju (automatski i ručni)
- **application_assignments**: raspodjela prijava članovima komisije
- **appeals**: žalbe
- **contracts**: generisani ugovori
- **audit_log**: evidencija izmjena

Ključne veze: jedan konkurs ima više kategorija, kriterija i prijava, jedna prijava ima više dokumenata, bodova i žalbi, a jedan kandidat može imati samo jednu prijavu po konkursu.

Detaljan ER dijagram: `docs/er-dijagram`.

---

## 7. Bodovanje

Pravila bodovanja se ne pišu u kod, nego se čuvaju u bazi (tabela `criteria`) i mijenjaju iz aplikacije, jer se pravilnik mijenja iz godine u godinu.

Tipovi kriterija:
- **FORMULA:** bodovi se računaju iz vrijednosti (npr. prosjek)
- **SKALA:** vrijednosti se mapiraju na bodove (npr. broj članova domaćinstva)
- **DA_NE:** fiksni bodovi ako je uslov ispunjen

Svaka ručna korekcija zahtijeva obrazloženje i bilježi se u audit log.

---

## 8. Tehnologije

- **Jezik:** Java 25
- **GUI:** JavaFX (FXML, CSS)
- **Baza:** MySQL 8, JDBC, HikariCP
- **PDF:** iText / PDFBox
- **Sigurnost:** BCrypt
- **Build:** Maven
- **Testiranje:** JUnit 5
- **Version control:** Git + GitHub
- **CI/CD:** GitHub Actions
- **Upravljanje zadacima:** YouTrack
- **Dizajn:** Figma, draw.io / PlantUML

---

## 9. Struktura repozitorija

```
stipvitez/
  src/
    main/
      java/ba/vitez/stipvitez/
        model/        - entiteti
        dao/          - Data Access Object sloj
        service/      - poslovna logika
        controller/   - JavaFX kontroleri
        util/         - PDF, konekcija, validacija, backup
        Main.java
      resources/
        view/         - FXML datoteke
        css/          - teme
        application.example.properties
    test/java/        - JUnit testovi
  db/
    schema.sql        - šema baze
    seed.sql          - testni podaci (izmišljeni)
  docs/               - ER, use case, UML, testni plan
  .github/workflows/
    ci.yml
  pom.xml
```

---

## 10. Pokretanje projekta

### Preduvjeti
- JDK 25
- Maven 3.9+
- MySQL 8 (lokalno ili Docker)

### 1. Baza podataka

```
docker run --name stipvitez-db -e MYSQL_ROOT_PASSWORD=<lozinka> -e MYSQL_DATABASE=stipvitez -p 3306:3306 -d mysql:8
mysql -u root -p stipvitez < db/schema.sql
mysql -u root -p stipvitez < db/seed.sql
```

### 2. Konfiguracija

```
cp src/main/resources/application.example.properties src/main/resources/application.properties
```

Upiši parametre baze u `application.properties`. Ta datoteka je u `.gitignore` i nikad se ne commituje.

### 3. Pokretanje

```
mvn javafx:run
```

### 4. Testovi i build

```
mvn -B verify
```

---

## 11. CI/CD (GitHub Actions)

- **CI:** nakon svakog push-a i pull requesta pokreće se build i JUnit testovi
- **Status:** badge na vrhu README-a prikazuje stanje zadnjeg builda
- **CD:** JAR se sprema kao artefakt svakog uspješnog builda
- **Verzionisanje:** stabilne verzije se označavaju Git tagom `v*` (npr. `v0.1.0`), a workflow automatski pravi GitHub Release s JAR-om

Workflow datoteka: `.github/workflows/ci.yml`

---

## 12. Metodologija razvoja: Scrum

**Zašto Scrum:** tim od 3 do 4 člana, zahtjevi koji se pojašnjavaju s općinom tokom rada i potreba za redovnim demonstracijama napretka. Kratke iteracije omogućavaju da povratnu informaciju uvrstimo odmah.

**Kako ga primjenjujemo:**
- **Sprintovi** od 2 sedmice, planiranje na početku
- **Product backlog** u YouTracku, prioritizovan metodom MoSCoW
- **Uloge:** Product Owner, Scrum Master/voditelj projekta, razvojni tim
- **Događaji:** sprint planning, kratki daily, sprint review s demo prikazom, retrospektiva
- **Definition of Done:** kod prošao pull request review, testovi prolaze, CI je zelen, zadatak dokumentovan
- **Praćenje:** YouTrack agile board, burndown, velocity

Dokaz primjene (burndown, retrospektive, export zadataka) nalazi se u `docs/scrum/`.

---

## 13. Rad s Gitom

- **Grane:** `main` (stabilno), `develop` (integracija), `feature/<opis>` (rad)
- **Pull request** je obavezan za spajanje u `develop` i `main`, uz barem jedan review
- **Commit poruke** počinju ID-om zadatka iz YouTracka, npr. `STIP-42: dodan login ekran`
- **Verzije** se označavaju tagovima (Semantic Versioning)

---

## 14. Sigurnost i zaštita podataka

Aplikacija obrađuje lične podatke, pa se vodi računa o **Zakonu o zaštiti ličnih podataka BiH** (Sl. glasnik BiH 12/25):

- Lozinke se čuvaju isključivo kao BCrypt hash
- Pristup funkcijama ovisi o ulozi korisnika
- Prikupljaju se samo podaci nužni za provođenje konkursa
- Sve bitne izmjene se bilježe u audit log
- Razvoj i testiranje koriste **isključivo izmišljene podatke**
- Konfiguracija i lozinke nikad ne ulaze u repozitorij
- Roktovi čuvanja i brisanja podataka određuje općina kao kontrolor

---

## 15. Plan razvoja

### Faza 1: desktop aplikacija (predaja na fakultetu)
- [ ] Analiza zahtjeva i dizajn (use case, ER, UML)
- [ ] Baza i DAO sloj
- [ ] Autentifikacija i uloge
- [ ] Konkursi, kriteriji, dokumenti
- [ ] Prijave i provjera dokumentacije
- [ ] Raspodjela, bodovanje, rang-liste
- [ ] PDF izvještaji i ugovori
- [ ] Analitika, backup, teme
- [ ] Testiranje i CI/CD
- [ ] Dokumentacija i prezentacija

### Faza 2: proširenje (nakon predaje, uz dogovor s općinom)
- [ ] REST API sloj nad postojećom bazom
- [ ] Web aplikacija za kandidate (online prijava, praćenje statusa)
- [ ] Email obavijesti
- [ ] Javna stranica s rang-listama

---

## 16. Dokumentacija

U folderu `docs/`:
- Opis aplikacije (cilj, partner, funkcionalnosti, uloge)
- ER dijagram i use case dijagram
- UML dijagram klasa
- Testni plan i testni slučajevi
- Obrazloženje i opis primjene Scruma
- Opis CI/CD procesa
- YouTrack export (zadaci, statusi, datumi)
- Korisničko i tehničko uputstvo

---

## 17. Tim

- **Kemal Beganović:** *(uloga)*
- **[Ime i prezime]:** *(uloga)*
- **[Ime i prezime]:** *(uloga)*
- **[Ime i prezime]:** *(uloga)*

Politehnički fakultet Univerziteta u Zenici, Softversko inženjerstvo, akademska 2026/2027.

---

## 18. Status

U razvoju. Zadnje ažuriranje: 14.10.2026.

## 19. Licenca i vlasništvo

Prava na izvorni kod i uslovi korištenja bit će definisani ugovorom s Općinom Vitez i pravilima fakulteta.