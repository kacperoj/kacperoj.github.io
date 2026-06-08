
CREATE VIEW vw_NajbardziejEfektywnyPracownik AS
SELECT TOP 3 pr.pracownik_id, pr.imie, pr.nazwisko, COUNT(w.wypozyczenie_id) AS liczba_wypozyczen
FROM pracownicy pr
JOIN wypozyczenia w ON pr.pracownik_id = w.pracownik_id
GROUP BY pr.pracownik_id, pr.imie, pr.nazwisko
ORDER BY liczba_wypozyczen DESC;

CREATE VIEW vw_NajchetniejWybieranyTypNadwoazia AS
SELECT TOP 1
    p.typNadwozia,
    COUNT(*) AS liczba_wypozyczen
FROM Wypozyczenia w
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
GROUP BY p.typNadwozia
ORDER BY COUNT(*) DESC;

CREATE VIEW vw_HistoriaKlientow AS
SELECT
    k.klient_id,
    k.imie,
    k.nazwisko,
    COUNT(w.wypozyczenie_id) AS liczba_wypozyczen,
    SUM(w.kwotaCalkowita) AS laczna_wartosc_wypozyczen,
    MAX(w.dataWypozyczenia) AS ostatnie_wypozyczenie
FROM klienci k
LEFT JOIN wypozyczenia w ON k.klient_id = w.klient_id
GROUP BY
    k.klient_id,
    k.imie,
    k.nazwisko;




CREATE VIEW vw_PojazdyDoKontroli AS
SELECT
    pojazd_id,
    nrRejestr,
    marka,
    model,
    przebieg,
    status
FROM pojazdy
WHERE przebieg >= 200000
   OR status = 'serwis';



CREATE VIEW vw_MiesiecznePrzychody AS
SELECT
    YEAR(dataPlatnosci) AS rok,
    MONTH(dataPlatnosci) AS miesiac,
    COUNT(*) AS liczba_transakcji,
    SUM(kwota) AS przychod
FROM platnosci
GROUP BY
    YEAR(dataPlatnosci),
    MONTH(dataPlatnosci);


CREATE VIEW vw_SzczegolyWypozyczen AS
SELECT
    w.wypozyczenie_id,
    k.imie + ' ' + k.nazwisko AS klient,
    p.marka + ' ' + p.model AS pojazd,
    p.nrRejestr,
    pr.imie + ' ' + pr.nazwisko AS pracownik,
    w.dataWypozyczenia,
    w.dataPlanowanegoZwrotu,
    w.dataRzeczywistegoZwrotu,
    w.kwotaCalkowita
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
LEFT JOIN pracownicy pr ON w.pracownik_id = pr.pracownik_id;



CREATE VIEW vw_UszkodzeniaWypozyczen AS
SELECT
    w.wypozyczenie_id,
    k.imie + ' ' + k.nazwisko AS klient,
    p.marka + ' ' + p.model AS pojazd,
    COUNT(u.uszkodzenie_id) AS liczba_uszkodzen,
    SUM(u.koszt) AS laczny_koszt_uszkodzen
FROM wypozyczenia w
JOIN klienci k ON w.klient_id = k.klient_id
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
LEFT JOIN uszkodzenia u ON w.wypozyczenie_id = u.wypozyczenie_id
GROUP BY
    w.wypozyczenie_id,
    k.imie,
    k.nazwisko,
    p.marka,
    p.model;


CREATE VIEW vw_NajlepsiKlienci AS
SELECT
    k.klient_id,
    k.imie,
    k.nazwisko,
    COUNT(w.wypozyczenie_id) AS liczba_wypozyczen,
    SUM(w.kwotaCalkowita) AS laczna_kwota
FROM klienci k
JOIN wypozyczenia w ON k.klient_id = w.klient_id
GROUP BY
    k.klient_id,
    k.imie,
    k.nazwisko;