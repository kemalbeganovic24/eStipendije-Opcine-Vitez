# Vitez eStipendija

[![CI](https://github.com/kemalbeganovic24/eStipendije-Opcine-Vitez/actions/workflows/ci.yml/badge.svg)](https://github.com/kemalbeganovic24/eStipendije-Opcine-Vitez/actions/workflows/ci.yml)

Desktop aplikacija za upravljanje stipendijama Općine Vitez.

*Radni naziv projekta. Projektni zadatak iz predmeta Metode razvoja softvera, Politehnički fakultet Univerziteta u Zenici, akademska 2026/2027.*


---

## 1. O projektu

### Problem
Dodjela općinskih stipendija se danas oslanja na papirne prijave, ručnu provjeru dokumenata i ručno bodovanje. To je sporo, podložno greškama i teško za praćenje, a građani nemaju uvid u to kako je odluka donesena. Studenti moraju fizički dostavljati prijave u općinu.

### Rješenje
Vitez eStipendija digitalizira cijeli proces: student sam podnosi prijavu elektronski, bez odlaska u općinu, a općinska služba upravlja konkursom, raspoređuje prijave komisiji, provjerava ih i boduje po pravilniku, te izrađuje rang-liste, ugovore i izvještaje u PDF formatu.

### Ciljevi
- Studentima omogućiti podnošenje prijave bez odlaska u općinu
- Smanjiti papirologiju i vrijeme potrebno komisiji za obradu prijava
- Osigurati pravedno i ponovljivo bodovanje prema pravilniku
- Povećati transparentnost kroz evidenciju svake izmjene (audit log)
- Omogućiti brzo generisanje rang-lista, ugovora i izvještaja

### Naručilac
Općina Vitez, Služba za društvene djelatnosti. *(Status saradnje: u razgovoru.)*

---

## 2. Korisničke uloge

- **Administrator (općinski službenik):** upravlja konkursima, kriterijima, korisnicima (dodaje i uređuje korisnike, među njima i članove komisije, te ih deaktivira ili briše), dodjeljuje prijave komisiji, vodi postavke i backup, ima uvid u sve prijave i audit log
- **Član komisije:** vidi samo prijave koje su mu dodijeljene, pregleda ih i razmatra, boduje, korigira bodove uz obrazloženje, pravi i potvrđuje rang-listu, odlučuje o žalbama
- **User (student / aplikant):** unosi svoje podatke i podnosi prijavu za stipendiju, vidi samo vlastitu prijavu i prati njen status. Dokumente šalje elektronski putem web aplikacije (faza 2)

Student ne vidi tuđe prijave, korisnike ni postavke konkursa. Komisija ne unosi i ne mijenja prijave.

---

## 3. Funkcionalnosti

### Autentifikacija i autorizacija
- Prijava korisnika, hashiranje lozinki (BCrypt)
- Kontrola pristupa po ulogama u cijelom interfejsu, uz provjeru u servisnom sloju
- Promjena lozinke, zaključavanje računa nakon više neuspjelih pokušaja

### Konkursi
- Kreiranje i uređivanje konkursa, kategorija, rokova (datum i sat isteka roka)
- Definisanje kriterija bodovanja i obaveznih dokumenata
- Statusi konkursa: nacrt, otvoren, zatvoren, objavljen, arhiviran

### Prijave i dokumenti
- Student sam podnosi prijavu: lični podaci, studij, kategorija, članovi domaćinstva i primanja
- Sistem automatski dodjeljuje broj prijave, bilježi vrijeme zaprimanja i provjerava rok konkursa
- Zaštita od dvostrukih prijava: jedan student ima jednu prijavu po konkursu
- Slanje i prilaganje dokumenata (CIPS, potvrda o statusu studenta, kućna lista i dr.) elektronski uz validaciju tipa i veličine: **faza 2, web aplikacija**
- Pregled dokumenata u aplikaciji, odobravanje ili odbijanje uz napomenu

### Raspodjela, bodovanje i rang-liste
- Nasumična i ravnomjerna raspodjela prijava članovima komisije
- Automatski izračun bodova iz konfigurabilnih pravila
- Ručna korekcija bodova uz obavezno obrazloženje
- Rang-liste s pravilima izjednačenja, potvrda i objava
- Čuvanje verzija rang-lista (preliminarna i konačna)

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

1. Administrator kreira konkurs, kategorije, kriterije i listu obaveznih dokumenata, pa ga otvori za prijave
2. Student sam podnosi prijavu: upisuje svoje podatke, bira kategoriju i unosi članove domaćinstva i primanja. Sistem dodjeljuje broj prijave, bilježi vrijeme zaprimanja i provjerava rok
3. Student dokumente prilaže elektronski putem web aplikacije (faza 2) i prati status prijave
4. Nakon isteka roka, konkurs se zatvara za nove prijave
5. Administrator nasumično i ravnomjerno raspoređuje prijave članovima komisije
6. Svaki član komisije pregleda samo svoje prijave, provjerava dokumente i po potrebi traži dopunu
7. Sistem računa bodove, a komisija može korigovati uz obrazloženje
8. Generiše se preliminarna rang-lista i otvara žalbeni rok
9. Nakon žalbi komisija potvrđuje konačnu listu
10. Generišu se ugovori i izvještaji, a konkurs se arhivira

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
- Poslovna pravila (bodovanje, statusi, vlasništvo nad prijavom) žive samo u servisnom sloju
- Svi SQL upiti koriste PreparedStatement (zaštita od SQL injectiona)
- Dokumenti se u fazi 2 šalju putem web aplikacije, a u bazi su samo putanja, hash i metapodaci

**Ograničenje trenutne arhitekture:** desktop aplikacija se spaja direktno na bazu, pa svaka kopija aplikacije ima pristupne podatke. To je prihvatljivo za razvoj i demonstraciju na izmišljenim podacima, ali ne za stvarne studente (pogledati poglavlje 14 i 15).

---

## 6. Model podataka (pregled)

Glavne tabele:
- **users**, **roles**: korisnici i uloge
- **competitions**, **categories**, **criteria**, **required_documents**: konkursi i pravila
- **candidates**, **applications**, **application_documents**: kandidati, prijave i dokumenti
- **household_members**: članovi domaćinstva i primanja
- **deficit_professions**: lista deficitarnih zanimanja po prioritetu
- **score_items**: bodovi po kriteriju (automatski i ručni)
- **application_assignments**: raspodjela prijava članovima komisije
- **appeals**: žalbe
- **contracts**, **payments**: ugovori i evidencija isplata
- **audit_log**: evidencija izmjena

Ključne veze: jedan konkurs ima više kategorija, kriterija i prijava, jedna prijava ima više dokumenata, bodova i žalbi, jedan kandidat može imati samo jednu prijavu po konkursu, a svaka prijava pripada tačno jednom studentu.

Detaljan ER dijagram: `docs/er-dijagram`.

---

## 7. Bodovanje

Pravila bodovanja se ne pišu u kod, nego se čuvaju u bazi (tabela `criteria`) i mijenjaju iz aplikacije, jer se pravilnik mijenja iz godine u godinu.

Tipovi kriterija:
- **FORMULA:** bodovi se računaju iz vrijednosti (npr. prosjek)
- **SKALA:** vrijednosti se mapiraju na bodove (npr. broj članova domaćinstva)
- **DA_NE:** fiksni bodovi ako je uslov ispunjen

Pravila dosljednosti bodovanja (provjeravaju se u servisnom sloju, a dodatno ih čuvaju ograničenja i triggeri u bazi):
- kriterij mora pripadati konkursu i kategoriji prijave koja se boduje
- bodovi po kriteriju ne smiju prelaziti dozvoljeni maksimum
- svaka ručna korekcija bodova zahtijeva obrazloženje i bilježi se u audit log
- kriterij koji je već korišten za bodovanje ne mijenja se, nego se deaktivira

---

## 8. Tehnologije

- **Jezik:** Java 27
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
    triggers.sql      - SQL triggeri
    seed.sql          - testni podaci (izmišljeni)
  docs/               - ER, use case, UML, testni plan
  .github/workflows/
    ci.yml
  pom.xml
```

---

## 10. Pokretanje projekta
### Pokretanje JavaFX aplikacije (Maven Wrapper)

Projekat koristi JavaFX, JDK 27 i Maven. Za pokretanje nije potrebno zasebno instalirati Maven jer projekat sadrži Maven Wrapper.

**Postupak:**

1. Klonirati GitHub repozitorij i otvoriti folder projekta u IntelliJ IDEA.
2. U IntelliJ-u podesiti Project SDK na JDK 27.
3. Učitati Maven zavisnosti iz `pom.xml`.
4. Otvoriti terminal u glavnom folderu projekta.

Na Windowsu pokrenuti:

```powershell
.\mvnw.cmd clean javafx:run
```

Na Linuxu i macOS-u:

```bash
./mvnw clean javafx:run
```

Aplikacija će otvoriti JavaFX prozor s naslovom **eStipendija Vitez**.

Za zaustavljanje aplikacije zatvoriti JavaFX prozor ili prekinuti proces u terminalu pomoću `Ctrl + C`.

**Napomena:** Trenutna verzija aplikacije prikazuje samo početni JavaFX prozor. Funkcionalnosti koje zahtijevaju MySQL
bazu bit će dostupne nakon implementacije baze podataka i DAO sloja.
### Preduvjeti

- JDK 27
- Maven Wrapper (uključen u projekat)
- Pristup razvojnom Aiven MySQL servisu
- Lokalno podešene environment varijable
- Aiven CA certifikat i Java PKCS12 truststore

### 1. Baza podataka

Aplikacija koristi MySQL bazu `estipendija` na Aiven Cloud platformi.

SQL skripte nalaze se u folderu `db/`:

- `schema.sql` – struktura baze podataka
- `triggers.sql` – SQL triggeri
- `seed.sql` – početni razvojni i testni podaci

Skripte ne treba ponovo izvršavati na postojećoj zajedničkoj bazi bez prethodnog dogovora s timom. Izmjene šeme radi samo jedan član tima, preko numerisanih migracija u `db/migrations/`, uz pull request.

### 2. Konfiguracija JDBC konekcije

Aplikacija koristi `src/main/resources/application.properties`, koji sadrži reference na environment varijable bez stvarnih lozinki.

Svaki član tima mora lokalno podesiti:

| Varijabla | Opis |
|---|---|
| `DB_HOST` | Puna Host adresa iz Aiven Connection information |
| `DB_PORT` | Port MySQL servisa na Aivenu |
| `DB_USERNAME` | MySQL korisničko ime |
| `DB_PASSWORD` | MySQL lozinka |
| `DB_TRUSTSTORE_PASSWORD` | Lozinka lokalnog Java truststorea |

Na Windowsu se varijable mogu podesiti kroz **Edit environment variables for your account → User variables**.

Nakon izmjene potrebno je ponovno pokrenuti IntelliJ IDEA.

**Sigurnost:** Stvarne lozinke, connection stringovi s kredencijalima, privatni ključevi i lokalni truststore ne smiju se objavljivati na GitHubu. Environment varijable su razvojno rješenje i nisu namjenski šifrirani sef za lozinke.

### 2.1. TLS certifikat i truststore

Aplikacija koristi TLS režim `VERIFY_IDENTITY`, koji provjerava certifikat i identitet Aiven servera.

1. U Aiven konzoli otvoriti MySQL servis i preuzeti njegov CA certifikat (`ca.pem`).
2. Na Windowsu kreirati lokalni folder `~/.estipendija`.
3. Importovati CA certifikat u Java PKCS12 truststore.

Primjer za PowerShell, ako je `ca.pem` u folderu Downloads:

```powershell
New-Item -ItemType Directory -Force "$HOME\.estipendija" | Out-Null

keytool -importcert -trustcacerts -noprompt -alias aiven-mysql-ca -file "$HOME\Downloads\ca.pem" -keystore "$HOME\.estipendija\aiven-truststore.p12" -storetype PKCS12
```

Prilikom kreiranja truststorea postaviti zasebnu lozinku i sačuvati je lokalno kao `DB_TRUSTSTORE_PASSWORD`.

Svaki član tima priprema vlastiti lokalni truststore. Nije potrebno kopirati tuđi truststore ili dijeliti njegovu lozinku.

### 2.2. Testiranje konekcije

Obični JUnit testovi, bez povezivanja na Aiven:

```powershell
.\mvnw.cmd clean test
```

Ručno pokretanje JDBC integracijskog testa:

```powershell
.\mvnw.cmd "-Dtest=DatabaseConnectionTest" "-Dtest.excluded.groups=" test
```

Integracijski test otvara konekciju s bazom i izvršava read-only `SELECT` upit. Za njegovo pokretanje moraju biti dostupne lokalne environment varijable, truststore i Aiven servis.

Integracijski test je isključen iz običnog Maven testiranja kako GitHub CI ne bi zahtijevao lokalne pristupne podatke članova tima.
### 3. Pokretanje

```
.\mvnw.cmd javafx:run
```

### 4. Testovi i build

Testovi koriste JUnit 5 i Maven Surefire. Potreban je JDK 27.
Početna tri testa provjeravaju dostupnost i JavaFX tip klase `org.example.Main`,
JDK 27 runtime i potpis `main` metode, bez pokretanja JavaFX prozora.

Na Windowsu:

```powershell
.\mvnw.cmd test
.\mvnw.cmd -B clean verify
```

Na Linuxu/macOS-u:

```bash
chmod +x mvnw
./mvnw test
./mvnw -B clean verify
```

Surefire izvještaji nalaze se u `target/surefire-reports/`. CI izvršava iste
testove u zasebnom koraku `Run JUnit tests`; neuspješan test zaustavlja build. Build također
pada ako Surefire ne pronađe nijedan test.

---

## 11. CI/CD (GitHub Actions)

- **CI:** svaki push na `main`, `feature/**`, `docs/**` i `fix/**` grane te otvaranje, ažuriranje ili ponovno otvaranje pull requesta prema `main` pokreće workflow.
- **Kompajliranje:** korak `Compile application and tests` izvršava `./mvnw -B test-compile`.
- **Testovi:** korak `Run JUnit tests` izvršava `./mvnw -B test`. Ako kompajliranje padne, testovi se preskaču; greška kompajliranja ili pad testa označava CI kao neuspješan.
- **JUnit izvještaj:** `Publish JUnit test report` se izvršava uz `if: always()`, čak i nakon greške. Iz `target/surefire-reports/*.xml` prikazuje broj uspješnih, neuspješnih i preskočenih testova te pojedinačne rezultate u Actions sažetku i PR provjeri `JUnit test results`. Nedostatak XML izvještaja također označava korak neuspješnim, a ne kao prolazak testova.
- **Pakovanje:** nakon uspješnih prethodnih koraka, `Package application JAR` izvršava `./mvnw -B package -DskipTests`, bez ponavljanja već izvršenih testova. Nastaje `target/VitezeStipendija-1.0-SNAPSHOT.jar` s manifestom `Main-Class: org.example.Main`.
- **Okruženje:** `ubuntu-26.04`, Temurin JDK 27 i keširanje Maven zavisnosti u oba workflowa.
- **Status:** badge na vrhu README-a prikazuje stanje zadnjeg builda
- **CD:** korak `Upload application JAR` koristi `actions/upload-artifact@v4` i `if: success()` za objavu `target/VitezeStipendija-*.jar` pod nazivom `VitezeStipendija-jar`. Ako kompajliranje, testovi ili drugi prethodni koraci padnu, upload se preskače. Ako JAR nedostaje, upload korak prijavljuje grešku.
- **Release:** push Git taga `v*` pokreće `.github/workflows/release.yml`. Na Temurin JDK-u 27 izvršava se `./mvnw -B clean verify`, zatim se objavljuje GitHub Release s automatskim bilješkama i JAR prilogom. Pad builda ili testova sprečava objavu; nedostatak JAR-a također prijavljuje grešku.

Workflow datoteka: `.github/workflows/ci.yml`

Na GitHubu otvori **Actions → CI → odabrano izvršavanje → Build and verify**
za status svakog koraka, a sažetak izvršavanja za JUnit izvještaj.
U Pull Requestu otvori **Checks → JUnit test results** za detalje testova.
Za spajanje u `main` potrebno je da CI prođe i kolega odobri review.

Za preuzimanje paketa otvori **Actions → CI → uspješno izvršavanje → Artifacts**
i klikni **VitezeStipendija-jar**. Preuzeti ZIP sadrži JAR aplikacije.
JAR ne uključuje JavaFX zavisnosti ni JDK; manifest određuje glavnu klasu,
ali za pokretanje je i dalje potrebno odgovarajuće Java/JavaFX okruženje.
Za lokalno pokretanje iz projekta koristi `./mvnw javafx:run`
(na Windowsu `.\mvnw.cmd javafx:run`).

Objava posebne JUnit provjere koristi `checks: write` dozvolu standardnog
`GITHUB_TOKEN` tokena; nije potreban lični token. Ovaj način objave namijenjen
je timskim granama u istom repozitoriju. Za PR iz forka i Dependabot izvršavanja
preskače se samo objava posebne provjere zbog read-only tokena; Actions sažetak
i status CI posla ostaju dostupni.

### Objavljivanje verzije

Verzije označavamo tagovima `vMAJOR.MINOR.PATCH`: `v0.1.0` je prvi MVP,
a `v1.0.0` je rezervisan za finalnu predaju. Prije označavanja verzije,
promjene moraju biti spojene u `main` putem PR-a, uz review kolege i uspješan CI.

Nakon spajanja release workflowa i uz čisto radno stablo:

```powershell
git switch main
git pull --ff-only origin main
git status
git tag -a v0.1.0 -m "v0.1.0: prvi MVP"
git push origin v0.1.0
```

Tag kreiraj samo ako je prethodno preuzimanje izmjena uspjelo i lokalni `main`
odgovara pregledanoj verziji. Postojeće objavljene tagove ne pomjeramo;
za naredne verzije koristimo novi broj verzije.

Provjeri **Actions → Release**, zatim **Releases → v0.1.0 → Assets**.
Očekivani prilog je `VitezeStipendija-1.0-SNAPSHOT.jar`. Git tag određuje
verziju objave; Maven verzija i naziv JAR-a ostaju `1.0-SNAPSHOT` prema
zahtjevu projekta. Release nije draft niti prerelease. Za objavu se koristi
standardni `GITHUB_TOKEN` uz `contents: write`, bez dodatnog ličnog tokena.

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

- **Grane:** `main` (stabilno), `feature/<opis>` (rad)
- **Pull request** je obavezan za spajanje u `main`, uz barem jedan review
- **Commit poruke** počinju ID-om zadatka iz YouTracka, npr. `VES-42: dodan login ekran`
- **Verzije** se označavaju tagovima (Semantic Versioning)

---

## 14. Sigurnost i zaštita podataka

Aplikacija obrađuje lične podatke (uključujući podatke o domaćinstvu i primanjima), pa se vodi računa o **Zakonu o zaštiti ličnih podataka BiH** (Sl. glasnik BiH 12/25):

- Lozinke se čuvaju isključivo kao BCrypt hash
- Pristup funkcijama ovisi o ulozi korisnika
- Prikupljaju se samo podaci nužni za provođenje konkursa
- Sve bitne izmjene se bilježe u audit log
- Razvoj i testiranje koriste **isključivo izmišljene podatke**
- Konfiguracija i lozinke nikad ne ulaze u repozitorij
- Rokove čuvanja i brisanja podataka određuje općina kao kontrolor

### 14.1. Sigurnost studentskih podataka

Veza između studenta i njegovog zapisa kandidata (`candidates.user_id`) omogućava da se utvrdi vlasnik prijave, ali sama po sebi **ne sprečava neovlašteno čitanje**. Zato:

- servisni sloj provjerava vlasništvo pri svakom čitanju i izmjeni prijave: student pristupa isključivo svojoj prijavi, član komisije samo dodijeljenim prijavama, a administrator svim prijavama
- svaka metoda koja čita ili mijenja prijavu poziva provjeru prava (`Authorization` i provjera pristupa prijavi), a provjere su pokrivene JUnit testovima
- studentima se **ne daju direktni MySQL pristupni podaci**. Studentski pristup se u fazi 2 ostvaruje isključivo kroz backend API, koji provjerava identitet i vlasništvo, a baza se ne izlaže studentskim računarima
- do tada se desktop aplikacija s direktnom vezom na bazu koristi samo za razvoj i demonstraciju s izmišljenim podacima

### 14.2. Dosljednost bodovanja

Sistem mora osigurati da je bodovanje ispravno i ponovljivo:

- kriterij bodovanja mora pripadati odgovarajućem konkursu i kategoriji prijave
- bodovi po kriteriju ne smiju prelaziti dozvoljeni maksimum
- ručne korekcije moraju imati obrazloženje i evidentirani identitet osobe koja ih je izvršila

Ove provjere se rade u servisnom sloju, a dodatno ih čuvaju CHECK ograničenja i triggeri u bazi (`triggers.sql`), tako da ih ne može zaobići ni neispravan klijent.

---

## 15. Plan razvoja

### Faza 1: desktop aplikacija (predaja na fakultetu)
- [ ] Analiza zahtjeva i dizajn (use case, ER, UML)
- [ ] Baza i DAO sloj
- [ ] Autentifikacija i uloge
- [ ] Konkursi, kriteriji, dokumenti
- [ ] Prijave studenata, raspodjela komisiji i provjera prijava
- [ ] Bodovanje, rang-liste
- [ ] PDF izvještaji i ugovori
- [ ] Analitika, backup, teme
- [ ] Testiranje i CI/CD
- [ ] Dokumentacija i prezentacija

### Faza 2: proširenje (nakon predaje, uz dogovor s općinom)
- [ ] Backend REST API ispred baze (studenti nikad ne dobijaju direktan pristup bazi)
- [ ] Web aplikacija za studente: online prijava, slanje dokumenata, praćenje statusa
- [ ] Email obavijesti
- [ ] Javna stranica s rang-listama

### Planirane izmjene baze i sigurnosti

| Prioritet | Izmjena | Zašto |
|---|---|---|
| Visok | Povezati `users` i `candidates` (`candidates.user_id`) | Da student može pristupati isključivo svojoj prijavi |
| Visok | Dodati socijalne podatke prijave | Nedostaju članovi domaćinstva i primanja |
| Visok | Dodati vrijeme završetka konkursa | Trenutno postoji datum, ali ne i satnica poput 14:00 |
| Srednji | Dodati `broj_protokola` | Automatska evidencija zaprimljene prijave |
| Srednji | Dodati evidenciju verzija rang-lista | Čuvanje preliminarnih i konačnih rezultata |
| Srednji | Provjeriti indekse i validacije | Brže pretrage i manje nekonzistentnih podataka |

Uz izmjene šeme važe i dvije stvari opisane u poglavlju 14: provjera vlasništva nad prijavom u servisu i studentski pristup preko backend API-ja, te dosljednost bodovanja (kriterij pripada konkursu i kategoriji, bodovi unutar maksimuma, obrazloženje za ručne korekcije).

---

## 16. Dokumentacija

U folderu `docs/`:
- Opis aplikacije (cilj, partner, funkcionalnosti, uloge)
- ER dijagram i use case dijagram
- UML dijagram klasa
- Testni plan i testni slučajevi
- Obrazloženje i opis primjene Scruma
- [Opis implementiranog CI/CD procesa (PDF)](docs/Opis-implementiranog-CI-CD-procesa.pdf)
- YouTrack export (zadaci, statusi, datumi)
- Korisničko i tehničko uputstvo

---

## 17. Tim

- **Kemal Beganović:** *vođa tima*
- **Emir Đelilbašić:** *član*
- **Ramo Kozlić:** *član*
- **Mugdin Krnjić:** *član*

Politehnički fakultet Univerziteta u Zenici, Softversko inženjerstvo, akademska 2026/2027.

---

## 18. Status

U razvoju. Zadnje ažuriranje: 21.11.2026.

## 19. Licenca i vlasništvo

Prava na izvorni kod i uslovi korištenja bit će definisani ugovorom s Općinom Vitez i pravilima studenata.
