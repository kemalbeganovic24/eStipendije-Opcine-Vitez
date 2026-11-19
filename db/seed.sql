USE estipendija;

INSERT INTO roles (naziv, opis)
SELECT 'ADMIN', 'Administrator sistema'
    WHERE NOT EXISTS (
    SELECT 1 FROM roles WHERE naziv = 'ADMIN'
);

INSERT INTO roles (naziv, opis)
SELECT 'KOMISIJA', 'Clan komisije za stipendije'
    WHERE NOT EXISTS (
    SELECT 1 FROM roles WHERE naziv = 'KOMISIJA'
);

INSERT INTO roles (naziv, opis)
SELECT 'USER', 'Korisnik aplikacije'
    WHERE NOT EXISTS (
    SELECT 1 FROM roles WHERE naziv = 'USER'
);


INSERT INTO competitions (
    naziv,
    opis,
    akademska_godina,
    datum_objave,
    datum_pocetka,
    datum_zavrsetka,
    budzet,
    broj_stipendija,
    status,
    created_by
)
SELECT
    'VES-16 Testni konkurs 2026/2027',
    'Izmisljeni konkurs za razvoj i testiranje aplikacije.',
    '2026/2027',
    NULL,
    '2026-11-01',
    '2027-03-31',
    30000.00,
    30,
    'NACRT',
    u.id
FROM users u
WHERE u.username = 'admin'
  AND NOT EXISTS (
    SELECT 1
    FROM competitions c
    WHERE c.naziv = 'VES-16 Testni konkurs 2026/2027'
      AND c.akademska_godina = '2026/2027'
);


INSERT INTO categories (
    competition_id,
    naziv,
    opis,
    maksimalan_broj_stipendija
)
SELECT
    c.id,
    k.naziv,
    k.opis,
    k.kvota
FROM competitions c
         CROSS JOIN (
    SELECT
        'Opca kategorija' AS naziv,
        'Testna kategorija za studente.' AS opis,
        15 AS kvota

    UNION ALL

    SELECT
        'Nadareni studenti',
        'Testna kategorija za uspjesne studente.',
        10

    UNION ALL

    SELECT
        'Studenti slabijeg imovinskog stanja',
        'Testna socijalna kategorija.',
        5
) AS k
WHERE c.naziv = 'VES-16 Testni konkurs 2026/2027'
  AND c.akademska_godina = '2026/2027'
  AND NOT EXISTS (
    SELECT 1
    FROM categories postojece
    WHERE postojece.competition_id = c.id
      AND postojece.naziv = k.naziv
);


INSERT INTO criteria (
    competition_id,
    category_id,
    naziv,
    opis,
    tip_bodovanja,
    pravilo_json,
    maksimalni_bodovi,
    aktivan
)
SELECT
    c.id,
    NULL,
    k.naziv,
    k.opis,
    k.tip_bodovanja,
    k.pravilo_json,
    k.maksimalni_bodovi,
    TRUE
FROM competitions c
         CROSS JOIN (
    SELECT
        'Prosjek ocjena' AS naziv,
        'Testno bodovanje prema prosjeku ocjena.' AS opis,
        'FORMULA' AS tip_bodovanja,
        JSON_OBJECT(
                'formula', 'prosjek_ocjena * 4',
                'min_prosjek', 6.00,
                'max_prosjek', 10.00
        ) AS pravilo_json,
        40.00 AS maksimalni_bodovi

    UNION ALL

    SELECT
        'Godina studija',
        'Testno bodovanje prema godini studija.',
        'SKALA',
        JSON_OBJECT(
                'stavke', JSON_ARRAY(
                JSON_OBJECT('godina', 1, 'bodovi', 5),
                JSON_OBJECT('godina', 2, 'bodovi', 10),
                JSON_OBJECT('godina', 3, 'bodovi', 15),
                JSON_OBJECT('godina', 4, 'bodovi', 20)
                          )
        ),
        20.00

    UNION ALL

    SELECT
        'Posebna socijalna okolnost',
        'Testni kriterij sa odgovorom DA ili NE.',
        'DA_NE',
        JSON_OBJECT(
                'da', 20,
                'ne', 0
        ),
        20.00
) AS k
WHERE c.naziv = 'VES-16 Testni konkurs 2026/2027'
  AND c.akademska_godina = '2026/2027'
  AND NOT EXISTS (
    SELECT 1
    FROM criteria cr
    WHERE cr.competition_id = c.id
      AND cr.category_id IS NULL
      AND cr.naziv = k.naziv
);


INSERT INTO required_documents (
    competition_id,
    category_id,
    naziv,
    opis,
    obavezan,
    dozvoljeni_formati,
    maksimalna_velicina_mb,
    aktivan
)
SELECT
    c.id,
    cat.id,
    d.naziv,
    d.opis,
    d.obavezan,
    d.formati,
    d.max_mb,
    TRUE
FROM competitions c
         CROSS JOIN (
    SELECT
        'Potvrda o redovnom studiranju' AS naziv,
        'Testna potvrda o statusu studenta.' AS opis,
        NULL AS kategorija,
        1 AS obavezan,
        'pdf,jpg,png' AS formati,
        5 AS max_mb

    UNION ALL

    SELECT
        'Potvrda o prebivalistu',
        'Testni dokaz o prebivalistu.',
        NULL,
        1,
        'pdf,jpg,png',
        5

    UNION ALL

    SELECT
        'Uvjerenje o prosjeku ocjena',
        'Testno uvjerenje o prosjeku.',
        'Nadareni studenti',
        1,
        'pdf',
        5

    UNION ALL

    SELECT
        'Dokaz o prihodima domacinstva',
        'Testna potvrda o prihodima.',
        'Studenti slabijeg imovinskog stanja',
        1,
        'pdf,jpg,png',
        5

    UNION ALL

    SELECT
        'Motivaciono pismo',
        'Opcionalni testni dokument.',
        'Opca kategorija',
        0,
        'pdf',
        3
) AS d
         LEFT JOIN categories cat
                   ON cat.competition_id = c.id
                       AND cat.naziv = d.kategorija
WHERE c.naziv = 'VES-16 Testni konkurs 2026/2027'
  AND c.akademska_godina = '2026/2027'

  AND (
    d.kategorija IS NULL
        OR cat.id IS NOT NULL
    )

  AND NOT EXISTS (
    SELECT 1
    FROM required_documents rd
    WHERE rd.competition_id = c.id
      AND rd.naziv = d.naziv
      AND rd.category_id <=> cat.id
);


INSERT INTO candidates (
    ime,
    prezime,
    datum_rodjenja,
    email,
    telefon,
    adresa,
    grad
)
SELECT
    k.ime,
    k.prezime,
    k.datum_rodjenja,
    k.email,
    NULL,
    NULL,
    k.grad
FROM (
         SELECT
             'Amar' AS ime,
             'Testic' AS prezime,
             DATE('2004-03-15') AS datum_rodjenja,
    'amar.testic@example.com' AS email,
    'Vitez' AS grad

UNION ALL

SELECT
    'Lejla',
    'Primjeric',
    DATE('2003-07-21'),
    'lejla.primjeric@example.com',
    'Vitez'

UNION ALL

SELECT
    'Harun',
    'Demo',
    DATE('2005-01-10'),
    'harun.demo@example.com',
    'Busovaca'

UNION ALL

SELECT
    'Sara',
    'Uzor',
    DATE('2004-11-06'),
    'sara.uzor@example.com',
    'Vitez'

UNION ALL

SELECT
    'Emir',
    'Probni',
    DATE('2002-09-18'),
    'emir.probni@example.com',
    'Travnik'

UNION ALL

SELECT
    'Hana',
    'Modelic',
    DATE('2005-05-12'),
    'hana.modelic@example.com',
    'Vitez'
    ) AS k
WHERE NOT EXISTS (
    SELECT 1
    FROM candidates postojece
    WHERE postojece.email = k.email
    );


INSERT INTO applications (
    candidate_id,
    competition_id,
    category_id,
    submitted_by,
    fakultet,
    univerzitet,
    godina_studija,
    prosjek_ocjena,
    datum_podnosenja,
    status,
    napomena
)
SELECT
    k.id,
    c.id,
    cat.id,
    u.id,
    p.fakultet,
    p.univerzitet,
    p.godina,
    p.prosjek,
    CASE
        WHEN p.status = 'DRAFT' THEN NULL
        ELSE '2026-11-15 10:00:00'
        END,
    p.status,
    'Izmisljena prijava za razvoj i testiranje.'
FROM (
         SELECT
             'amar.testic@example.com' AS email,
             'Opca kategorija' AS kategorija,
             'Masinski fakultet' AS fakultet,
             'Univerzitet u Zenici' AS univerzitet,
             2 AS godina,
             8.20 AS prosjek,
             'PODNESENA' AS status

         UNION ALL

         SELECT
             'lejla.primjeric@example.com',
             'Nadareni studenti',
             'Elektrotehnicki fakultet',
             'Univerzitet u Sarajevu',
             3,
             9.75,
             'U_PROVJERI'

         UNION ALL

         SELECT
             'harun.demo@example.com',
             'Studenti slabijeg imovinskog stanja',
             'Ekonomski fakultet',
             'Univerzitet u Zenici',
             1,
             7.50,
             'DOPUNA_TRAZENA'

         UNION ALL

         SELECT
             'sara.uzor@example.com',
             'Opca kategorija',
             'Pravni fakultet',
             'Univerzitet u Sarajevu',
             2,
             8.90,
             'PROVJERENA'

         UNION ALL

         SELECT
             'emir.probni@example.com',
             'Nadareni studenti',
             'Fakultet informacijskih tehnologija',
             'Testni univerzitet',
             4,
             9.40,
             'DRAFT'

         UNION ALL

         SELECT
             'hana.modelic@example.com',
             'Studenti slabijeg imovinskog stanja',
             'Medicinski fakultet',
             'Univerzitet u Sarajevu',
             1,
             8.60,
             'PODNESENA'
     ) AS p
         JOIN candidates k
              ON k.email = p.email
         JOIN competitions c
              ON c.naziv = 'VES-16 Testni konkurs 2026/2027'
                  AND c.akademska_godina = '2026/2027'
         JOIN categories cat
              ON cat.competition_id = c.id
                  AND cat.naziv = p.kategorija
         JOIN users u
              ON u.username = 'admin'
WHERE NOT EXISTS (
    SELECT 1
    FROM applications a
    WHERE a.candidate_id = k.id
      AND a.competition_id = c.id
);
