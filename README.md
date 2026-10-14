# eStipendije-Op-ine-Vitez
Digitalna platforma za prijavu, bodovanje i dodjelu stipendija Općine Vitez.

## O projektu

eStipendija Vitez je web aplikacija koja digitalizira cijeli proces dodjele
stipendija: od objave javnog konkursa i online prijave kandidata, preko
provjere dokumentacije i bodovanja, do objave rang-lista i rezultata.

Cilj projekta je smanjiti papirologiju, ubrzati rad općinske komisije,
povećati transparentnost postupka i olakšati učenicima i studentima
prijavu na konkurs.

## Ključne funkcionalnosti

**Za kandidate**
- Registracija i prijava na sistem
- Online obrazac za prijavu na konkurs
- Upload potrebne dokumentacije (uvjerenja, potvrde, dokazi o prosjeku)
- Praćenje statusa prijave u realnom vremenu
- Email obavijesti o promjenama statusa

**Za općinsku komisiju i administratore**
- Kreiranje i upravljanje konkursima, rokovima i kriterijima
- Pregled i provjera pristiglih prijava i dokumenata
- Konfigurabilno automatsko bodovanje prema važećem pravilniku
- Generisanje rang-lista i izvještaja (PDF/Excel)
- Evidencija svih izmjena (audit log)
- Upravljanje korisnicima i ulogama

## Tehnologije

- **Backend:** (npr. NestJS / ASP.NET Core / Spring Boot)
- **Frontend:** React / Next.js, TypeScript, Tailwind CSS
- **Baza podataka:** PostgreSQL
- **Pohrana dokumenata:** S3-kompatibilno skladište
- **DevOps:** Docker, GitHub Actions

## Sigurnost i zaštita podataka

Projekat vodi računa o zaštiti ličnih podataka u skladu sa važećim
propisima: kontrola pristupa po ulogama, enkripcija, validacija uploada,
minimizacija podataka i evidencija pristupa.

## Status

U razvoju (MVP faza).

## Autor

[Tvoje ime], student softverskog inženjerstva
