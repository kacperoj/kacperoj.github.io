----P1(XML)-----
SELECT 
    w.wypozyczenie_id,
    w.dataWypozyczenia,
    p.marka,
    p.model,
    k.nazwisko
FROM wypozyczenia w
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
JOIN klienci k ON w.klient_id = k.klient_id
FOR XML AUTO, ELEMENTS, ROOT('RaportWypozyczen');

----P2(XML)-----
SELECT 
    w.wypozyczenie_id AS [Wypozyczenie/ID],
    w.dataWypozyczenia AS [Wypozyczenie/Data],
    k.nazwisko AS [Wypozyczenie/Klient],
    p.marka AS [Wypozyczenie/Pojazd],
    (SELECT pl.kwota, pl.metodaPlatnosci, pl.dataPlatnosci
     FROM platnosci pl
     WHERE pl.wypozyczenie_id = w.wypozyczenie_id
     FOR XML PATH('Platnosc'), TYPE) AS [Wypozyczenie/Platnosci]
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
FOR XML PATH('Raport'), ROOT('WypozyczeniaCalkowite');

----P3(JSON)-----
DECLARE @jsonN NVARCHAR(MAX);

SET @jsonN = (
    SELECT imie, nazwisko, telefon, email
    FROM klienci
    WHERE prywatny = 1
    FOR JSON PATH, ROOT('KlienciPrywatni')
);

-- Sprawdzenie poprawno�ci
SELECT ISJSON(@jsonN) AS CzyPoprawnyJSON;

-- Analiza - wyci�gni�cie nazwisk z JSONa
SELECT nazwisko
FROM OPENJSON(@jsonN, '$.KlienciPrywatni')
WITH (
    nazwisko NVARCHAR(40) '$.nazwisko'
);


----P4(JSON)-----
--Profil klienta z histori� wypo�ycze� 
-- Zapytanie generuj�ce struktur� JSON z informacjami o klientach prywatnych
-- oraz ich histori� wypo�ycze� (model pojazdu i szczeg�y transakcji)

SELECT 
    JSON_VALUE(klient.value, '$.nazwisko') AS Nazwisko,
    JSON_VALUE(klient.value, '$.HistoriaWypozyczen[0].model') AS PierwszyPojazd,
    -- Opcjonalnie: pobranie ca�ego obiektu JSON dla wiersza
    klient.value AS PelnyJsonKlienta
FROM (
    -- Podzapytanie buduj�ce struktur� JSON bezpo�rednio z tabel
    SELECT (
        SELECT 
            k.imie, 
            k.nazwisko,
            (SELECT w.dataWypozyczenia, p.model, w.kwotaCalkowita
             FROM wypozyczenia w
             JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
             WHERE w.klient_id = k.klient_id
             FOR JSON PATH) AS HistoriaWypozyczen
        FROM klienci k
        WHERE k.prywatny = 1
        FOR JSON PATH, ROOT('KlienciZHistoria')
    ) AS JsonContent
) AS SourceData
-- U�ywamy CROSS APPLY, aby "rozpakowa�" tablic� JSON do wierszy
CROSS APPLY OPENJSON(SourceData.JsonContent, '$.KlienciZHistoria') AS klient;

--historia kosztów naprawy samochodów 
SELECT 
    p.marka AS [Pojazd/Marka],
    p.model AS [Pojazd/Model],
    p.nrRejestr AS [Pojazd/Rejestracja],
    (SELECT u.opis AS [Opis], u.koszt AS [Koszt], u.data_zgloszenia AS [DataZgloszenia]
     FROM uszkodzenia u
     JOIN wypozyczenia w ON u.wypozyczenie_id = w.wypozyczenie_id
     WHERE w.pojazd_id = p.pojazd_id
     FOR XML PATH('Usterka'), TYPE) AS [Pojazd/ZgloszoneUszkodzenia],
    (SELECT SUM(u2.koszt) 
     FROM uszkodzenia u2
     JOIN wypozyczenia w2 ON u2.wypozyczenie_id = w2.wypozyczenie_id
     WHERE w2.pojazd_id = p.pojazd_id) AS [Pojazd/SumaKosztowNapraw]
FROM pojazdy p
WHERE EXISTS (
    SELECT 1 FROM uszkodzenia u3 
    JOIN wypozyczenia w3 ON u3.wypozyczenie_id = w3.wypozyczenie_id 
    WHERE w3.pojazd_id = p.pojazd_id
)
FOR XML PATH('Samochod'), ROOT('RaportUsterkowy');


--njbardziej efektywni pracownicy

DECLARE @jsonPremie NVARCHAR(MAX);

SET @jsonPremie = (
    SELECT 
        p.pracownik_id,
        p.imie,
        p.nazwisko,
        p.stanowisko,
        (SELECT SUM(pr2.kwota) FROM premiePracownikow pr2 WHERE pr2.pracownik_id = p.pracownik_id) AS SumaPremii,
        (SELECT pr.miesiac, pr.kwota, pr.opis
         FROM premiePracownikow pr
         WHERE pr.pracownik_id = p.pracownik_id
         FOR JSON PATH) AS SzczegolyPremii
    FROM pracownicy p
    FOR JSON PATH, ROOT('EfektywnoscPracownikow')
);

-- Sprawdzenie poprawności wygenerowanego dokumentu
SELECT ISJSON(@jsonPremie) AS CzyPoprawnyJSON;

-- Analiza - Filtrowanie pracowników z poziomu JSON, którzy mają przypisane jakiekolwiek premie
SELECT 
    JSON_VALUE(pracownik.value, '$.imie') AS Imie,
    JSON_VALUE(pracownik.value, '$.nazwisko') AS Nazwisko,
    JSON_VALUE(pracownik.value, '$.SumaPremii') AS LacznaKwotaPremii
FROM OPENJSON(@jsonPremie, '$.EfektywnoscPracownikow') AS pracownik
WHERE JSON_QUERY(pracownik.value, '$.SzczegolyPremii') IS NOT NULL;