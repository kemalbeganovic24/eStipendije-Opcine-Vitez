# eStipendija Vitez

Digitalna platforma za upravljanje stipendijama Općine Vitez.

## O projektu

eStipendija Vitez je sistem koji digitalizira cijeli proces dodjele
stipendija: od objave javnog konkursa i online prijave kandidata, preko
provjere dokumentacije i bodovanja, do objave rang-lista i rezultata.

Sistem se sastoji od tri dijela:

- **Backend (REST API):** sva poslovna logika, bodovanje, autentifikacija i pohrana podataka
- **Web aplikacija:** namijenjena kandidatima (učenicima i studentima) za prijavu na konkurs
- **Desktop aplikacija:** namijenjena administratorima i općinskoj komisiji za upravljanje konkursima, prijavama i rang-listama

Cilj projekta je smanjiti papirologiju, ubrzati rad komisije, povećati
transparentnost postupka i olakšati kandidatima prijavu.

## Arhitektura

```
[Web aplikacija]    ──┐
 (kandidati)          ├──►  [Backend REST API]  ──►  [PostgreSQL]
[Desktop aplikacija] ─┘      (Spring Boot)         [Pohrana dokumenata]
 (admin / komisija)
```

Web i desktop aplikacija koriste isti backend, tako da se poslovna logika
(npr. bodovanje) implementira samo jednom.

## Funkcionalnosti

### Web aplikacija (kandidati)
- Registracija i prijava na sistem
- Online obrazac za prijavu na konkurs
- Upload dokumentacije (uvjerenja, potvrde, dokazi o prosjeku)
- Praćenje statusa prijave
- Email obavijesti o promjenama statusa

### Desktop aplikacija (administratori i komisija)
- Kreiranje i upravljanje konkursima, rokovima i kriterijima
- Pregled i provjera pristiglih prijava i dokumenata
- Konfigurabilno bodovanje prema važećem pravilniku
- Generisanje rang-lista i izvještaja (PDF/Excel)
- Upravljanje korisnicima i ulogama
- Pregled evidencije izmjena (audit log)

## Tehnologije

| Dio | Tehnologije |
|---|---|
| Backend | Java, Spring Boot, Spring Security, Spring Data JPA |
| Desktop | Java, JavaFX (FXML, CSS), jpackage |
| Web | React / Next.js, TypeScript (ili Thymeleaf) |
| Baza podataka | PostgreSQL, Flyway migracije |
| Dokumenti | S3-kompatibilno skladište / MinIO |
| Autentifikacija | JWT + refresh tokeni, uloge (Kandidat, Komisija, Administrator) |
| API dokumentacija | OpenAPI / Swagger |
| Testiranje | JUnit, Mockito, Testcontainers |
| DevOps | Docker, docker-compose, GitHub Actions |

## Struktura repozitorija

```
estipendija-vitez/
├── backend/     # Spring Boot REST API
├── desktop/     # JavaFX admin aplikacija
├── web/         # Web aplikacija za kandidate
├── docs/        # SRS, UML i ER dijagrami, testni plan
└── docker-compose.yml
```

## Pokretanje projekta

### Preduvjeti
- JDK 21+
- Maven ili Gradle
- Docker i Docker Compose
- Node.js 20+ (ako se koristi React/Next.js)

### Backend
```bash
cd backend
docker compose up -d        # pokreće PostgreSQL
./mvnw spring-boot:run
```
API dokumentacija: `http://localhost:8080/swagger-ui.html`

### Desktop aplikacija
```bash
cd desktop
./mvnw javafx:run
```

### Web aplikacija
```bash
cd web
npm install
npm run dev
```

## Sigurnost i zaštita podataka

- Kontrola pristupa po ulogama
- Hashiranje lozinki (BCrypt)
- Validacija uploadovanih dokumenata (tip i veličina)
- Evidencija svih izmjena (audit log)
- Minimizacija podataka i poštivanje propisa o zaštiti ličnih podataka

## Plan razvoja

- [ ] Backend: model baze, autentifikacija, konkursi
- [ ] Backend: prijave, dokumenti, bodovanje
- [ ] Desktop: prijava, konkursi, pregled prijava
- [ ] Web: registracija i obrazac za prijavu
- [ ] Rang-liste, izvještaji, obavijesti, audit log
- [ ] Testiranje, sigurnost, dokumentacija, deploy

## Dokumentacija

Sva projektna dokumentacija (SRS, use-case i ER dijagrami, testni plan)
nalazi se u folderu [`docs/`](docs/).

## Status

U razvoju.

## Autor

Kemal Beganović, student 3. godine softverskog inženjerstva.
Politehnički fakultet Univerziteta u Zenici, akademska 2026/2027.
