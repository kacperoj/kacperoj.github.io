-- ============================================================
--  FUNKCJE OKNA (OVER/PARTITION BY) - Wypozyczalnia Samochodow
-- ============================================================
USE ProjektWypo;
GO

-- ============================================================
-- CZESC 1: FUNKCJE RANKINGOWE
-- (RANK, DENSE_RANK, ROW_NUMBER, NTILE)
-- ============================================================

-- [1] Ranking klientow wg lacznej wartosci wypozyczen
--     RANK()       - ta sama pozycja przy remisie, potem przerwa (1,2,2,4)
--     DENSE_RANK() - ta sama pozycja przy remisie, bez przerwy  (1,2,2,3)
SELECT
    k.klient_id,
    k.imie + ' ' + k.nazwisko             AS Klient,
    COUNT(w.wypozyczenie_id)               AS LiczbaWypozyczen,
    SUM(w.kwotaCalkowita)                  AS SumaWydatkow,
    RANK()       OVER (ORDER BY SUM(w.kwotaCalkowita) DESC) AS Ranking,
    DENSE_RANK() OVER (ORDER BY SUM(w.kwotaCalkowita) DESC) AS RankingBezPrzerw
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
GROUP BY k.klient_id, k.imie, k.nazwisko
ORDER BY Ranking;
GO

-- [2] Ranking klientow generujacych najwiecej uszkodzen
--     Dwa rownolegle rankingi w jednym zapytaniu: wg liczby i wg kosztu
SELECT
    k.klient_id,
    k.imie + ' ' + k.nazwisko             AS Klient,
    COUNT(u.uszkodzenie_id)                AS LiczbaUszkodzen,
    ISNULL(SUM(u.koszt), 0)               AS SumaKosztowUszkodzen,
    RANK() OVER (ORDER BY COUNT(u.uszkodzenie_id) DESC)  AS RankingUszkodzen,
    RANK() OVER (ORDER BY ISNULL(SUM(u.koszt),0) DESC)  AS RankingKosztow
FROM klienci k
LEFT JOIN wypozyczenia w ON k.klient_id       = w.klient_id
LEFT JOIN uszkodzenia u  ON w.wypozyczenie_id = u.wypozyczenie_id
GROUP BY k.klient_id, k.imie, k.nazwisko
ORDER BY RankingUszkodzen;
GO

-- [3] Numerowanie wypozyczen kazdego klienta chronologicznie (ROW_NUMBER)
--     ROW_NUMBER zawsze daje unikalne numery nawet przy identycznych datach
SELECT
    k.imie + ' ' + k.nazwisko             AS Klient,
    w.wypozyczenie_id,
    w.dataWypozyczenia,
    w.kwotaCalkowita,
    ROW_NUMBER() OVER (
        PARTITION BY w.klient_id
        ORDER BY w.dataWypozyczenia
    )                                      AS NrWypozyczenia
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
ORDER BY k.klient_id, NrWypozyczenia;
GO

-- [4] Podzial pojazdow na 4 grupy cenowe z etykieta (NTILE)
--     Grupa 1 = najdrozsze, Grupa 4 = najtansze
SELECT
    pojazd_id,
    marka + ' ' + model                    AS Pojazd,
    typNadwozia,
    cenaZaDzien,
    NTILE(4) OVER (ORDER BY cenaZaDzien DESC) AS GrupaCenowa,
    CASE NTILE(4) OVER (ORDER BY cenaZaDzien DESC)
        WHEN 1 THEN 'Premium'
        WHEN 2 THEN 'Standard+'
        WHEN 3 THEN 'Standard'
        WHEN 4 THEN 'Ekonomiczny'
    END                                    AS KategoriaCenowa
FROM pojazdy
ORDER BY cenaZaDzien DESC;
GO

-- [5] Podzial wypozyczen na 4 grupy wg wartosci (NTILE)
--     Segmentacja transakcji bez sztywnych progow kwotowych
SELECT
    w.wypozyczenie_id,
    k.imie + ' ' + k.nazwisko             AS Klient,
    w.kwotaCalkowita,
    NTILE(4) OVER (ORDER BY w.kwotaCalkowita DESC) AS GrupaWartosci,
    CASE NTILE(4) OVER (ORDER BY w.kwotaCalkowita DESC)
        WHEN 1 THEN 'Wysoka wartosc'
        WHEN 2 THEN 'Srednia wartosc'
        WHEN 3 THEN 'Nizka wartosc'
        WHEN 4 THEN 'Minimalna wartosc'
    END                                    AS KategoriaWartosci
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
ORDER BY w.kwotaCalkowita DESC;
GO


-- ============================================================
-- CZESC 2: FUNKCJE PRZESUNIECIA
-- (LAG, LEAD, FIRST_VALUE, LAST_VALUE)
-- ============================================================

-- [6] Odstep miedzy kolejnymi wypozyczeniami klienta (LAG)
--     NULL w PoprzednieWypozyczenie = pierwsze wypozyczenie klienta
SELECT
    k.imie + ' ' + k.nazwisko             AS Klient,
    w.wypozyczenie_id,
    w.dataWypozyczenia,
    LAG(w.dataWypozyczenia) OVER (
        PARTITION BY w.klient_id
        ORDER BY w.dataWypozyczenia
    )                                      AS PoprzednieWypozyczenie,
    DATEDIFF(DAY,
        LAG(w.dataWypozyczenia) OVER (
            PARTITION BY w.klient_id
            ORDER BY w.dataWypozyczenia
        ),
        w.dataWypozyczenia
    )                                      AS DniOdPoprzedniego
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
ORDER BY k.klient_id, w.dataWypozyczenia;
GO

-- [7] Porownanie biezacego wypozyczenia z nastepnym (LEAD)
--     LEAD patrzy w przyszlosc - kiedy klient wypozyczyl auto ponownie
SELECT
    k.imie + ' ' + k.nazwisko             AS Klient,
    w.wypozyczenie_id,
    w.dataWypozyczenia,
    w.kwotaCalkowita,
    LEAD(w.dataWypozyczenia) OVER (
        PARTITION BY w.klient_id
        ORDER BY w.dataWypozyczenia
    )                                      AS NastepneWypozyczenie,
    LEAD(w.kwotaCalkowita) OVER (
        PARTITION BY w.klient_id
        ORDER BY w.dataWypozyczenia
    )                                      AS KwotaNastepnego
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
ORDER BY k.klient_id, w.dataWypozyczenia;
GO

-- [8] Pierwsze i ostatnie wypozyczenie kazdego klienta (FIRST_VALUE / LAST_VALUE)
--     LAST_VALUE wymaga ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
--     bez tego klauzula domyslna zatrzymuje sie na biezacym wierszu
SELECT DISTINCT
    k.imie + ' ' + k.nazwisko             AS Klient,
    FIRST_VALUE(w.dataWypozyczenia) OVER (
        PARTITION BY w.klient_id
        ORDER BY w.dataWypozyczenia
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                      AS PierwszeWypozyczenie,
    LAST_VALUE(w.dataWypozyczenia) OVER (
        PARTITION BY w.klient_id
        ORDER BY w.dataWypozyczenia
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                      AS OstatnieWypozyczenie,
    COUNT(w.wypozyczenie_id) OVER (
        PARTITION BY w.klient_id
    )                                      AS LacznaLiczbaWypozyczen
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
ORDER BY LacznaLiczbaWypozyczen DESC;
GO


-- ============================================================
-- CZESC 3: FUNKCJE AGREGUJACE W OKNIE
-- (SUM/AVG/COUNT OVER, narastajace sumy, srednie kroczace)
-- ============================================================

-- [9] Narastajacy przychod miesiac po miesiacu (running total)
--     ROWS UNBOUNDED PRECEDING - sumuje od pierwszego wiersza do biezacego
SELECT
    Rok, Miesiac,
    Przychod,
    SUM(Przychod) OVER (
        ORDER BY Rok, Miesiac
        ROWS UNBOUNDED PRECEDING
    )                                      AS PrzychodNarastajaco,
    LAG(Przychod, 1, 0) OVER (
        ORDER BY Rok, Miesiac
    )                                      AS PrzychodPoprzedniMiesiac,
    Przychod - LAG(Przychod, 1, 0) OVER (
        ORDER BY Rok, Miesiac
    )                                      AS ZmianaMiesieczna
FROM (
    SELECT
        YEAR(dataWypozyczenia)             AS Rok,
        MONTH(dataWypozyczenia)            AS Miesiac,
        SUM(kwotaCalkowita)                AS Przychod
    FROM wypozyczenia
    GROUP BY YEAR(dataWypozyczenia), MONTH(dataWypozyczenia)
) mies
ORDER BY Rok, Miesiac;
GO

-- [10] Srednia kroczaca ceny za dobe (okno 3 wypozyczen wstecz)
--      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW = okno 3-wierszowe
SELECT
    p.marka + ' ' + p.model               AS Pojazd,
    w.dataWypozyczenia,
    p.cenaZaDzien,
    AVG(p.cenaZaDzien) OVER (
        PARTITION BY p.pojazd_id
        ORDER BY w.dataWypozyczenia
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    )                                      AS SredniaKroczaca3
FROM wypozyczenia w
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
ORDER BY p.pojazd_id, w.dataWypozyczenia;
GO

-- [11] Udzial procentowy kazdego pracownika w przychodzie calkowitym
--      SUM() OVER () bez PARTITION BY liczy sume globalnie po wszystkich wierszach
SELECT
    pr.imie + ' ' + pr.nazwisko           AS Pracownik,
    pr.stanowisko,
    SUM(w.kwotaCalkowita)                  AS PrzychodPracownika,
    SUM(SUM(w.kwotaCalkowita)) OVER ()     AS PrzychodCalkowity,
    CAST(
        SUM(w.kwotaCalkowita) * 100.0
        / SUM(SUM(w.kwotaCalkowita)) OVER ()
    AS DECIMAL(5,2))                       AS UdzialProcentowy
FROM wypozyczenia w
JOIN pracownicy pr ON w.pracownik_id = pr.pracownik_id
GROUP BY pr.pracownik_id, pr.imie, pr.nazwisko, pr.stanowisko
ORDER BY PrzychodPracownika DESC;
GO

-- [12] Sredni przebieg w podziale na typ nadwozia z odchyleniem
--      AVG() OVER (PARTITION BY) zachowuje kazdy wiersz (brak GROUP BY)
--      dzieki czemu widac odchylenie konkretnego pojazdu od sredniej grupy
SELECT
    pojazd_id,
    marka + ' ' + model                    AS Pojazd,
    typNadwozia,
    przebieg,
    AVG(przebieg) OVER (
        PARTITION BY typNadwozia
    )                                      AS SredniPrzebiegTypu,
    przebieg - AVG(przebieg) OVER (
        PARTITION BY typNadwozia
    )                                      AS OdchylenieOdSredniej
FROM pojazdy
ORDER BY typNadwozia, przebieg DESC;
GO


-- ============================================================
-- CZESC 4: FUNKCJE DYSTRYBUCJI
-- (CUME_DIST, PERCENT_RANK)
-- ============================================================

-- [13] Pozycja kwoty wypozyczenia w rozkladzie klienta
--      CUME_DIST  - procent wypozyczen klienta z kwota <= biezacej (0..1]
--      PERCENT_RANK - relatywna pozycja (0 = najnizszy, 1 = najwyzszy)
SELECT
    k.imie + ' ' + k.nazwisko             AS Klient,
    w.wypozyczenie_id,
    w.kwotaCalkowita,
    CAST(CUME_DIST() OVER (
        PARTITION BY w.klient_id
        ORDER BY w.kwotaCalkowita
    ) AS DECIMAL(4,2))                     AS CUME_DIST,
    CAST(PERCENT_RANK() OVER (
        PARTITION BY w.klient_id
        ORDER BY w.kwotaCalkowita
    ) AS DECIMAL(4,2))                     AS PERCENT_RANK
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
ORDER BY k.klient_id, w.kwotaCalkowita;
GO

-- [14] Percentyl cenowy pojazdow w obrebie marki
--      Pokazuje na tle ktorego percentyla cen danej marki lezy dany pojazd
SELECT
    marka,
    model,
    nrRejestr,
    cenaZaDzien,
    NTILE(4) OVER (
        PARTITION BY marka
        ORDER BY cenaZaDzien
    )                                      AS KwartylCenowy,
    CAST(PERCENT_RANK() OVER (
        PARTITION BY marka
        ORDER BY cenaZaDzien
    ) * 100 AS DECIMAL(5,1))               AS PercentylWMarce
FROM pojazdy
ORDER BY marka, cenaZaDzien;
GO