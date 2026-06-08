-- ============================================================
--  ZAAWANSOWANE ZAPYTANIA - Wypozyczalnia Samochodow
-- ============================================================
USE ProjektWypo;
GO

-- ============================================================
-- CZESC 1: ZAPYTANIA AGREGUJACE
-- ============================================================

-- [1] Liczba wypozyczen obsluzona przez kazdego pracownika
SELECT
    p.pracownik_id,
    p.imie + ' ' + p.nazwisko          AS Pracownik,
    p.stanowisko,
    COUNT(w.wypozyczenie_id)           AS LiczbaWypozyczen,
    SUM(w.kwotaCalkowita)              AS WygenerowanyPrzychod
FROM pracownicy p
JOIN wypozyczenia w ON p.pracownik_id = w.pracownik_id
GROUP BY p.pracownik_id, p.imie, p.nazwisko, p.stanowisko
ORDER BY LiczbaWypozyczen DESC;
GO

-- [2] Wartosc ubezpieczen wg typu nadwozia i konkretnego pojazdu (ROLLUP)
--     Wiersze z NULL to sumy czesciowe generowane przez ROLLUP
SELECT
    ISNULL(p.typNadwozia,              'SUMA WSZYSTKICH') AS TypNadwozia,
    ISNULL(p.marka + ' ' + p.model,   'Suma dla typu')   AS Pojazd,
    COUNT(uw.ubezpieczenie_id)                            AS LiczbaUbezpieczen,
    SUM(uw.koszt)                                         AS SumarycznyKosztUbezpieczen
FROM Ubezpieczenie_wypozyczenia uw
JOIN wypozyczenia w ON uw.wypozyczenie_id = w.wypozyczenie_id
JOIN pojazdy p      ON w.pojazd_id        = p.pojazd_id
GROUP BY ROLLUP (p.typNadwozia, (p.marka + ' ' + p.model));
GO

-- [3] Przychod i liczba wypozyczen w podziale na rok i miesiac
SELECT
    YEAR(w.dataWypozyczenia)           AS Rok,
    MONTH(w.dataWypozyczenia)          AS Miesiac,
    COUNT(w.wypozyczenie_id)           AS LiczbaWypozyczen,
    SUM(w.kwotaCalkowita)              AS Przychod,
    AVG(w.kwotaCalkowita)              AS SredniaWartoscWypozyczenia
FROM wypozyczenia w
GROUP BY YEAR(w.dataWypozyczenia), MONTH(w.dataWypozyczenia)
ORDER BY Rok, Miesiac;
GO

-- [4] Najbardziej dochodowe marki samochodow
SELECT
    p.marka,
    COUNT(w.wypozyczenie_id)           AS LiczbaWypozyczen,
    SUM(w.kwotaCalkowita)              AS LacznyPrzychod,
    AVG(w.kwotaCalkowita)              AS SredniPrzychodZWypozyczenia
FROM wypozyczenia w
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
GROUP BY p.marka
HAVING SUM(w.kwotaCalkowita) > 0
ORDER BY LacznyPrzychod DESC;
GO

-- [5] Przychod na pracownika z podsuma globalna (GROUPING SETS)
--     Wiersz z NULL to suma globalna wszystkich pracownikow
SELECT
    pr.pracownik_id,
    pr.imie + ' ' + pr.nazwisko        AS Pracownik,
    COUNT(w.wypozyczenie_id)           AS LiczbaWypozyczen,
    SUM(w.kwotaCalkowita)              AS LacznyPrzychod,
    AVG(w.kwotaCalkowita)              AS SredniaWartoscWypozyczenia
FROM wypozyczenia w
JOIN pracownicy pr ON w.pracownik_id = pr.pracownik_id
GROUP BY GROUPING SETS (
    (pr.pracownik_id, pr.imie, pr.nazwisko),
    ()
)
ORDER BY LacznyPrzychod DESC;
GO

-- [6] Przychod wg marki i modelu z sumami czesciowymi (ROLLUP)
SELECT
    ISNULL(p.marka, 'SUMA WSZYSTKICH') AS Marka,
    ISNULL(p.model, 'Suma dla marki')  AS Model,
    COUNT(w.wypozyczenie_id)           AS LiczbaWypozyczen,
    SUM(w.kwotaCalkowita)              AS Przychod
FROM wypozyczenia w
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
GROUP BY ROLLUP(p.marka, p.model);
GO

-- [7] Sezonowosc - liczba i sredni przychod wg kwartalu i dnia tygodnia
SELECT
    DATEPART(QUARTER, dataWypozyczenia)   AS Kwartal,
    CASE DATEPART(WEEKDAY, dataWypozyczenia)
        WHEN 1 THEN 'Niedziela' WHEN 2 THEN 'Poniedzialek'
        WHEN 3 THEN 'Wtorek'   WHEN 4 THEN 'Sroda'
        WHEN 5 THEN 'Czwartek' WHEN 6 THEN 'Piatek'
        WHEN 7 THEN 'Sobota'
    END                                   AS DzienTygodnia,
    COUNT(wypozyczenie_id)                AS LiczbaWypozyczen,
    AVG(kwotaCalkowita)                   AS SredniPrzychod
FROM wypozyczenia
GROUP BY DATEPART(QUARTER, dataWypozyczenia),
         DATEPART(WEEKDAY, dataWypozyczenia)
ORDER BY Kwartal, DATEPART(WEEKDAY, dataWypozyczenia);
GO


-- ============================================================
-- CZESC 2: CTE (Common Table Expressions)
-- ============================================================

-- [8] TOP 3 klientow wg przychodu w kazdym miesiacu
--     Dwupoziomowe CTE: najpierw agregacja, potem ranking
WITH PrzychodKlientow AS (
    SELECT
        YEAR(w.dataWypozyczenia)       AS Rok,
        MONTH(w.dataWypozyczenia)      AS Miesiac,
        k.klient_id,
        k.imie + ' ' + k.nazwisko     AS Klient,
        SUM(w.kwotaCalkowita)          AS Przychod
    FROM wypozyczenia w
    JOIN klienci k ON w.klient_id = k.klient_id
    GROUP BY YEAR(w.dataWypozyczenia), MONTH(w.dataWypozyczenia),
             k.klient_id, k.imie, k.nazwisko
),
Ranking AS (
    SELECT *,
        DENSE_RANK() OVER (PARTITION BY Rok, Miesiac ORDER BY Przychod DESC) AS Poz
    FROM PrzychodKlientow
)
SELECT Rok, Miesiac, Poz, Klient, Przychod
FROM Ranking
WHERE Poz <= 3
ORDER BY Rok, Miesiac, Poz;
GO

-- [9] Pojazdy ktore nigdy nie byly wypozyczone (antyjoin przez CTE)
WITH WypozyczoneID AS (
    SELECT DISTINCT pojazd_id FROM wypozyczenia
)
SELECT
    p.pojazd_id,
    p.marka + ' ' + p.model           AS Pojazd,
    p.nrRejestr,
    p.[status],
    p.data_dodania,
    DATEDIFF(DAY, p.data_dodania, GETDATE()) AS DniWSystemie
FROM pojazdy p
LEFT JOIN WypozyczoneID w ON p.pojazd_id = w.pojazd_id
WHERE w.pojazd_id IS NULL
ORDER BY DniWSystemie DESC;
GO

-- [10] Historia kolejnych wypozyczen kazdego pojazdu z numeracja
WITH NumerowaneWypozyczenia AS (
    SELECT
        pojazd_id,
        wypozyczenie_id,
        dataWypozyczenia,
        dataRzeczywistegoZwrotu,
        ROW_NUMBER() OVER (PARTITION BY pojazd_id ORDER BY dataWypozyczenia) AS NrWypozyczenia
    FROM wypozyczenia
)
SELECT
    p.marka + ' ' + p.model           AS Pojazd,
    p.nrRejestr,
    nw.NrWypozyczenia,
    nw.dataWypozyczenia,
    nw.dataRzeczywistegoZwrotu,
    DATEDIFF(DAY, nw.dataWypozyczenia,
             ISNULL(nw.dataRzeczywistegoZwrotu, GETDATE())) AS CzasWypozyczeniaDni
FROM NumerowaneWypozyczenia nw
JOIN pojazdy p ON nw.pojazd_id = p.pojazd_id
ORDER BY p.pojazd_id, nw.NrWypozyczenia;
GO


-- ============================================================
-- CZESC 3: WYKRYWANIE ANOMALII I RAPORTY OPERACYJNE
-- ============================================================

-- [11] Wypozyczenia przeterminowane (nie zwrocone po planowanej dacie)
SELECT
    w.wypozyczenie_id,
    k.imie + ' ' + k.nazwisko         AS Klient,
    k.telefon,
    p.marka + ' ' + p.model           AS Pojazd,
    p.nrRejestr,
    w.dataPlanowanegoZwrotu,
    DATEDIFF(DAY, w.dataPlanowanegoZwrotu, GETDATE()) AS DniPrzeterminowania,
    w.kwotaCalkowita
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
WHERE w.dataRzeczywistegoZwrotu IS NULL
  AND w.dataPlanowanegoZwrotu < CAST(GETDATE() AS DATE)
ORDER BY DniPrzeterminowania DESC;
GO

-- [12] Klienci z wielokrotnymi uszkodzeniami (ryzykowni)
WITH StatKlientow AS (
    SELECT
        w.klient_id,
        COUNT(DISTINCT w.wypozyczenie_id) AS LiczbaWypozyczen,
        COUNT(DISTINCT u.uszkodzenie_id)  AS LiczbaUszkodzen,
        SUM(u.koszt)                      AS SumaKosztowUszkodzen
    FROM wypozyczenia w
    LEFT JOIN uszkodzenia u ON w.wypozyczenie_id = u.wypozyczenie_id
    GROUP BY w.klient_id
)
SELECT
    k.imie + ' ' + k.nazwisko         AS Klient,
    k.email,
    sk.LiczbaWypozyczen,
    sk.LiczbaUszkodzen,
    CAST(sk.LiczbaUszkodzen * 100.0 / NULLIF(sk.LiczbaWypozyczen, 0)
         AS DECIMAL(5,1))              AS ProcUszkodzenNaWypozyczenie,
    ISNULL(sk.SumaKosztowUszkodzen, 0) AS SumaKosztowUszkodzen
FROM StatKlientow sk
JOIN klienci k ON sk.klient_id = k.klient_id
WHERE sk.LiczbaUszkodzen > 0
ORDER BY ProcUszkodzenNaWypozyczenie DESC;
GO

-- [13] Analiza platnosci - sredni czas od wypozyczenia do platnosci wg metody
SELECT
    pr.metodaPlatnosci,
    COUNT(*)                           AS LiczbaPlatnosci,
    AVG(DATEDIFF(MINUTE,
        CAST(w.dataWypozyczenia AS DATETIME2),
        pr.dataPlatnosci))             AS SredniCzasDoZaplatyMin,
    SUM(pr.kwota)                      AS SumaWplywow
FROM platnosci pr
JOIN wypozyczenia w ON pr.wypozyczenie_id = w.wypozyczenie_id
GROUP BY pr.metodaPlatnosci
ORDER BY SumaWplywow DESC;
GO

-- [14] Pojazdy wymagajace serwisu (wysoki przebieg lub czeste uszkodzenia)
SELECT
    p.marka + ' ' + p.model           AS Pojazd,
    p.nrRejestr,
    p.przebieg,
    p.[status],
    COUNT(u.uszkodzenie_id)            AS LiczbaUszkodzen,
    SUM(u.koszt)                       AS SumaKosztowNapraw,
    CASE
        WHEN p.przebieg > 200000          THEN 'Krytyczny przebieg'
        WHEN SUM(u.koszt) > 5000          THEN 'Wysokie koszty napraw'
        WHEN COUNT(u.uszkodzenie_id) >= 3 THEN 'Czeste uszkodzenia'
        ELSE 'OK'
    END                                AS RekomendacjaSerwisu
FROM pojazdy p
LEFT JOIN wypozyczenia w ON p.pojazd_id        = w.pojazd_id
LEFT JOIN uszkodzenia u  ON w.wypozyczenie_id  = u.wypozyczenie_id
GROUP BY p.pojazd_id, p.marka, p.model, p.nrRejestr, p.przebieg, p.[status]
HAVING COUNT(u.uszkodzenie_id) >= 1 OR p.przebieg > 150000
ORDER BY SumaKosztowNapraw DESC;
GO

-- [15] Klienci bez zadnej rezerwacji ani wypozyczenia (nieaktywni)
SELECT
    k.klient_id,
    k.imie + ' ' + k.nazwisko         AS Klient,
    k.email,
    k.telefon
FROM klienci k
WHERE NOT EXISTS (SELECT 1 FROM wypozyczenia w WHERE w.klient_id = k.klient_id)
  AND NOT EXISTS (SELECT 1 FROM rezerwacje   r WHERE r.klient_id = k.klient_id)
ORDER BY k.nazwisko;
GO