-- ============================================================
--  TRIGGERY - Wypozyczalnia Samochodow
--  Uruchom calosciowo jednym F5
--
--  Zawiera:
--    TABELE POMOCNICZE (audyt / archiwum / historia)
--    TRIGGERY DML na tabelach
--    TRIGGER DDL na bazie danych
--    TESTY kazdego triggera
-- ============================================================
USE ProjektWypo;
GO

-- ============================================================
-- CZESC 1: TABELE POMOCNICZE
-- ============================================================

-- Audyt zmian danych osobowych klientow
IF OBJECT_ID('dbo.KlientAudit','U') IS NULL
CREATE TABLE dbo.KlientAudit (
    AuditID     INT IDENTITY PRIMARY KEY,
    KlientID    INT NOT NULL,
    OpisZmiany  NVARCHAR(200) NOT NULL,
    DataZmiany  DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- Audyt zmian danych pracownikow
IF OBJECT_ID('dbo.PracownicyAudit','U') IS NULL
CREATE TABLE dbo.PracownicyAudit (
    AuditID          INT IDENTITY PRIMARY KEY,
    PracownikID      INT NOT NULL,
    ZmienioneKolumny NVARCHAR(200),
    DataZmiany       DATETIME DEFAULT GETDATE()
);
GO

-- Historia zmian ceny za dobe
IF OBJECT_ID('dbo.historia_cen_pojazdow','U') IS NULL
CREATE TABLE dbo.historia_cen_pojazdow (
    historia_id  INT IDENTITY(1,1) PRIMARY KEY,
    pojazd_id    INT NOT NULL,
    stara_cena   DECIMAL(10,2),
    nowa_cena    DECIMAL(10,2),
    data_zmiany  DATETIME     DEFAULT GETDATE(),
    uzytkownik   NVARCHAR(100) DEFAULT SUSER_SNAME()
);
GO

-- Archiwum usunietych pojazdow
IF OBJECT_ID('dbo.ArchiwumPojazdy','U') IS NULL
CREATE TABLE dbo.ArchiwumPojazdy (
    ArchiwumID     INT IDENTITY(1,1) PRIMARY KEY,
    pojazd_id      INT,
    nrRejestr      NVARCHAR(15),
    marka          NVARCHAR(40),
    model          NVARCHAR(40),
    DataUsuniecia  DATETIME      DEFAULT GETDATE(),
    UsunietePrzez  NVARCHAR(100) DEFAULT SUSER_SNAME()
);
GO

-- Archiwum usunietych klientow
IF OBJECT_ID('dbo.ArchiwumKlienci','U') IS NULL
CREATE TABLE dbo.ArchiwumKlienci (
    ArchiwumID     INT IDENTITY(1,1) PRIMARY KEY,
    klient_id      INT,
    imie           NVARCHAR(40),
    nazwisko       NVARCHAR(40),
    pesel          NCHAR(11),
    DataUsuniecia  DATETIME      DEFAULT GETDATE(),
    UsunietePrzez  NVARCHAR(100) DEFAULT SUSER_SNAME()
);
GO

-- Audyt operacji DDL (DROP TABLE)
IF OBJECT_ID('dbo.WypozyczalniaDDLAudit','U') IS NULL
CREATE TABLE dbo.WypozyczalniaDDLAudit (
    AuditID        INT IDENTITY PRIMARY KEY,
    TypZdarzenia   NVARCHAR(100)  NOT NULL,
    NazwaObiektu   NVARCHAR(256)  NULL,
    TrescPolecenia NVARCHAR(MAX)  NULL,
    DataZdarzenia  DATETIME       NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- CZESC 2: TRIGGERY
-- ============================================================

-- ------------------------------------------------------------
-- [1] AFTER UPDATE na klienci
--     Cel: rejestruje w tabeli audytu kazda zmiane danych
--     klienta, wskazujac ktore kolumny (imie, nazwisko, pesel,
--     email) zostaly zmodyfikowane.
--     Uzycie COLUMNS_UPDATED() pozwala wykryc konkretne
--     kolumny zamiast logowac kazda zmiane bez wyjatku.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_KlientDaneAudit
ON dbo.klienci
AFTER UPDATE
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    SET NOCOUNT ON;

    DECLARE @opis NVARCHAR(200) = '';

    -- Kolumna 1 = imie, 2 = nazwisko, 3 = pesel, 5 = email
    -- (numeracja wg kolejnosci w CREATE TABLE)
    IF UPDATE(imie)     SET @opis += 'imie; ';
    IF UPDATE(nazwisko) SET @opis += 'nazwisko; ';
    IF UPDATE(pesel)    SET @opis += 'pesel; ';
    IF UPDATE(email)    SET @opis += 'email; ';

    IF LEN(@opis) = 0 SET @opis = 'inne dane';

    INSERT INTO dbo.KlientAudit (KlientID, OpisZmiany)
    SELECT i.klient_id,
           'Zmienione kolumny: ' + @opis
    FROM inserted i;
END;
GO

-- ------------------------------------------------------------
-- [2] AFTER UPDATE na pracownicy
--     Cel: analogiczny do triggera na klientach - rejestruje
--     zmiany danych pracownika (imie, nazwisko, stanowisko,
--     email). Przydatne przy audycie HR i kontroli uprawnien.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_PracownikAudit
ON dbo.pracownicy
AFTER UPDATE
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    SET NOCOUNT ON;

    DECLARE @opis NVARCHAR(200) = '';
    IF UPDATE(imie)       SET @opis += 'imie; ';
    IF UPDATE(nazwisko)   SET @opis += 'nazwisko; ';
    IF UPDATE(stanowisko) SET @opis += 'stanowisko; ';
    IF UPDATE(email)      SET @opis += 'email; ';
    IF LEN(@opis) = 0 SET @opis = 'inne dane';

    INSERT INTO dbo.PracownicyAudit (PracownikID, ZmienioneKolumny)
    SELECT i.pracownik_id,
           'Zmienione kolumny: ' + @opis
    FROM inserted i;
END;
GO

-- ------------------------------------------------------------
-- [3] AFTER UPDATE na pojazdy (przebieg)
--     Cel: zapobiega cofaniu licznika przebiegu (np. blad
--     operatora lub proba fabrykowania danych). Jezeli nowa
--     wartosc jest nizsza od poprzedniej, trigger przywraca
--     stara wartosc.
--     TRIGGER_NESTLEVEL() > 1 chroni przed petla rekurencyjna
--     ktora powstalaby gdy ten sam trigger wywoluje siebie.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_PojazdPrzebiegKorekta
ON dbo.pojazdy
AFTER UPDATE
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    SET NOCOUNT ON;

    UPDATE p
    SET    p.przebieg = d.przebieg
    FROM   dbo.pojazdy p
    JOIN   inserted i ON p.pojazd_id = i.pojazd_id
    JOIN   deleted  d ON d.pojazd_id = i.pojazd_id
    WHERE  i.przebieg < d.przebieg;
END;
GO

-- ------------------------------------------------------------
-- [4] AFTER UPDATE na pojazdy (cena)
--     Cel: rejestruje kazda zmiane ceny za dobe wraz z osoba
--     ktora jej dokonala. Umozliwia analize polityki cenowej
--     i wykrycie nieprawidlowych zmian cen.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_loguj_zmiane_ceny
ON dbo.pojazdy
AFTER UPDATE
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    SET NOCOUNT ON;

    IF UPDATE(cenaZaDzien)
    BEGIN
        INSERT INTO dbo.historia_cen_pojazdow (pojazd_id, stara_cena, nowa_cena)
        SELECT d.pojazd_id,
               d.cenaZaDzien,
               i.cenaZaDzien
        FROM   inserted i
        JOIN   deleted  d ON i.pojazd_id = d.pojazd_id
        WHERE  i.cenaZaDzien <> d.cenaZaDzien;
    END
END;
GO

-- ------------------------------------------------------------
-- [5] AFTER UPDATE na pojazdy (VIN)
--     Cel: numer VIN jest unikalnym identyfikatorem pojazdu
--     nadawanym przez producenta i nie moze byc zmieniany
--     po rejestracji w systemie. Trigger blokuje kazda probe
--     modyfikacji tego pola.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_BlockVINChange
ON dbo.pojazdy
AFTER UPDATE
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    IF UPDATE(nrVIN)
        THROW 50003, 'Zmiana numeru VIN zarejestrowanego pojazdu jest zabroniona.', 1;
END;
GO

-- ------------------------------------------------------------
-- [6] INSTEAD OF INSERT na pojazdy
--     Cel: walidacja roku produkcji przed dodaniem pojazdu.
--     Wypozyczalnia nie przyjmuje aut starszych niz 2000 rok
--     (polityka floty). INSTEAD OF pozwala odrzucic caly
--     INSERT zanim rekord trafi do tabeli, bez koniecznosci
--     pozniejszego cofania transakcji.
--     UWAGA: kolumny opcjonalne (data_dodania, typNadwozia,
--     przebieg) sa przekazywane z inserted, dzieki czemu
--     trigger nie zaburza normalnego wstawiania rekordow.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_PojazdInsertValidation
ON dbo.pojazdy
INSTEAD OF INSERT
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted WHERE rokProdukcji < 2000)
        THROW 50001, 'Nie przyjmujemy pojazdow starszych niz rok 2000.', 1;

    INSERT INTO dbo.pojazdy
        (nrRejestr, nrVIN, marka, model, rokProdukcji,
         [status], data_dodania, typNadwozia, przebieg, cenaZaDzien)
    SELECT
        nrRejestr, nrVIN, marka, model, rokProdukcji,
        [status], data_dodania, typNadwozia, przebieg, cenaZaDzien
    FROM inserted;
END;
GO

-- ------------------------------------------------------------
-- [7] INSTEAD OF INSERT na platnosci
--     Cel: dwuetapowa walidacja przed zapisem platnosci:
--     (a) kwota musi byc dodatnia,
--     (b) powiazane wypozyczenie musi istniec w bazie.
--     INSTEAD OF gwarantuje ze nieprawidlowe dane nigdy nie
--     trafia do tabeli, w odroznieniu od AFTER ktory musi
--     cofac transakcje juz po bledzie.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_PlatnoscComplexControl
ON dbo.platnosci
INSTEAD OF INSERT
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted WHERE kwota <= 0)
        THROW 50004, 'Kwota platnosci musi byc dodatnia.', 1;

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        LEFT JOIN dbo.wypozyczenia w ON i.wypozyczenie_id = w.wypozyczenie_id
        WHERE  w.wypozyczenie_id IS NULL
    )
        THROW 50005, 'Blad: powiazane wypozyczenie nie istnieje w bazie.', 1;

    INSERT INTO dbo.platnosci (kwota, dataPlatnosci, metodaPlatnosci, wypozyczenie_id)
    SELECT kwota, dataPlatnosci, metodaPlatnosci, wypozyczenie_id
    FROM inserted;
END;
GO

-- ------------------------------------------------------------
-- [8] AFTER INSERT, UPDATE na rezerwacje
--     Cel: gdy rezerwacja zostaje potwierdzona, status pojazdu
--     automatycznie zmienia sie na 'zarezerwowany', dzieki
--     czemu pojazd nie moze zostac wypozyczony przez innego
--     pracownika. TRIGGER_NESTLEVEL() chroni przed rekurencja
--     gdyby zmiana statusu pojazdu wywolala inny trigger.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_rezerwacja_status_pojazdu
ON dbo.rezerwacje
AFTER INSERT, UPDATE
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    SET NOCOUNT ON;

    -- Pojazd zarezerwowany gdy rezerwacja jest potwierdzona
    UPDATE p
    SET    p.[status] = 'zarezerwowany'
    FROM   dbo.pojazdy p
    JOIN   inserted i ON p.pojazd_id = i.pojazd_id
    WHERE  i.[status] = 'potwierdzona';

    -- Pojazd dostepny gdy rezerwacja zostala anulowana
    UPDATE p
    SET    p.[status] = 'dostepny'
    FROM   dbo.pojazdy p
    JOIN   inserted i ON p.pojazd_id = i.pojazd_id
    WHERE  i.[status] = 'anulowana'
      AND  p.[status] = 'zarezerwowany';
END;
GO

-- ------------------------------------------------------------
-- [9] AFTER DELETE na pojazdy  (NOWY)
--     Cel: przed fizycznym usunieciem pojazdu z systemu jego
--     podstawowe dane trafiaja do tabeli archiwalnej. Dzieki
--     temu mozliwe jest pozniejsze odtworzenie historii floty
--     lub wyjasnienien ewentualnych roszczen prawnych.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Pojazdy_Archive_Delete
ON dbo.pojazdy
AFTER DELETE
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    SET NOCOUNT ON;

    INSERT INTO dbo.ArchiwumPojazdy (pojazd_id, nrRejestr, marka, model)
    SELECT pojazd_id, nrRejestr, marka, model
    FROM deleted;
END;
GO

-- ------------------------------------------------------------
-- [10] AFTER DELETE na klienci  (NOWY)
--      Cel: analogicznie do pojazdu - usuniecie klienta
--      (np. na jego zadanie, RODO) archiwizuje minimalne dane
--      potrzebne do weryfikacji historii wypozyczeń. PESEL
--      pozwala powiazac archive z ewentualnymi roszczeniami.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Klienci_Archive_Delete
ON dbo.klienci
AFTER DELETE
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    SET NOCOUNT ON;

    INSERT INTO dbo.ArchiwumKlienci (klient_id, imie, nazwisko, pesel)
    SELECT klient_id, imie, nazwisko, pesel
    FROM deleted;
END;
GO

-- ------------------------------------------------------------
-- [11] AFTER UPDATE na wypozyczenia  (NOWY - brakujacy)
--      Cel: gdy pracownik wpisuje date rzeczywistego zwrotu
--      (dataRzeczywistegoZwrotu), pojazd automatycznie zmienia
--      status z 'wypozyczony' na 'dostepny'. Bez tego triggera
--      pracownik musialby pamietac o recznej zmianie statusu,
--      co w praktyce prowadzi do bledow (pojazd zablokowany
--      w systemie mimo ze stoi na parkingu).
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Wypozyczenie_Zwrot_StatusPojazdu
ON dbo.wypozyczenia
AFTER UPDATE
AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    SET NOCOUNT ON;

    -- Jezeli dataRzeczywistegoZwrotu zostala wlasnie wypelniona
    -- (wczesniej NULL, teraz NOT NULL) - oznacza to zwrot auta
    UPDATE p
    SET    p.[status] = 'dostepny'
    FROM   dbo.pojazdy p
    JOIN   inserted i ON p.pojazd_id = i.pojazd_id
    JOIN   deleted  d ON d.pojazd_id = i.pojazd_id -- poprzedni stan
    WHERE  d.dataRzeczywistegoZwrotu IS NULL
      AND  i.dataRzeczywistegoZwrotu IS NOT NULL
      AND  p.[status] = 'wypozyczony';
END;
GO

-- ------------------------------------------------------------
-- [12] DDL TRIGGER na bazie danych  (DATABASE scope)
--      Cel: loguje kazda operacje DROP TABLE wykonana w bazie.
--      W srodowisku produkcyjnym pozwala wykryc przypadkowe
--      lub zlosliwe usuniecie tabeli i zidentyfikowac sprawce.
--      EVENTDATA() zwraca XML z pelnym kontekstem zdarzenia.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_DDL_DropTable_Audit
ON DATABASE
AFTER DROP_TABLE
AS
BEGIN
    DECLARE @data XML = EVENTDATA();
    INSERT INTO dbo.WypozyczalniaDDLAudit
        (TypZdarzenia, NazwaObiektu, TrescPolecenia)
    VALUES (
        @data.value('(/EVENT_INSTANCE/EventType)[1]',              'NVARCHAR(100)'),
        @data.value('(/EVENT_INSTANCE/ObjectName)[1]',             'NVARCHAR(256)'),
        @data.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]','NVARCHAR(MAX)')
    );
END;
GO

-- ============================================================
-- CZESC 3: TESTY
-- ============================================================
PRINT '=== TESTY TRIGGEROW ===';
GO

-- [1] Test trg_KlientDaneAudit - zmiana nazwiska klienta
PRINT '--- Test 1: Audyt zmiany danych klienta ---';
UPDATE dbo.klienci SET nazwisko = 'Testowy' WHERE klient_id = 1;
SELECT * FROM dbo.KlientAudit WHERE KlientID = 1;
GO

-- [2] Test trg_PracownikAudit - zmiana stanowiska pracownika
PRINT '--- Test 2: Audyt zmiany danych pracownika ---';
UPDATE dbo.pracownicy SET stanowisko = 'Kierownik' WHERE pracownik_id = 1;
SELECT * FROM dbo.PracownicyAudit WHERE PracownikID = 1;
GO

-- [3] Test trg_PojazdPrzebiegKorekta - proba cofniecia licznika
PRINT '--- Test 3: Ochrona przed cofnieciem przebiegu ---';
DECLARE @stary_przebieg BIGINT;
SELECT @stary_przebieg = przebieg FROM pojazdy WHERE pojazd_id = 1;
PRINT 'Przebieg przed: ' + CAST(@stary_przebieg AS VARCHAR);
UPDATE dbo.pojazdy SET przebieg = 0 WHERE pojazd_id = 1;
SELECT pojazd_id, przebieg AS 'Przebieg po (powinien byc niezmieniony)' FROM pojazdy WHERE pojazd_id = 1;
GO

-- [4] Test trg_loguj_zmiane_ceny - zmiana ceny za dobe
PRINT '--- Test 4: Historia zmian ceny ---';
UPDATE dbo.pojazdy SET cenaZaDzien = cenaZaDzien + 10 WHERE pojazd_id = 1;
SELECT * FROM dbo.historia_cen_pojazdow WHERE pojazd_id = 1;
GO

-- [5] Test trg_BlockVINChange - proba zmiany numeru VIN
PRINT '--- Test 5: Blokada zmiany VIN (oczekiwany blad) ---';
BEGIN TRY
    UPDATE dbo.pojazdy SET nrVIN = N'00000000000000000' WHERE pojazd_id = 1;
END TRY
BEGIN CATCH
    PRINT 'Oczekiwany blad: ' + ERROR_MESSAGE();
END CATCH;
GO

-- [6] Test trg_PojazdInsertValidation - pojazd sprzed 2000 roku
PRINT '--- Test 6: Blokada dodania starego pojazdu (oczekiwany blad) ---';
BEGIN TRY
    INSERT INTO dbo.pojazdy (nrRejestr, nrVIN, marka, model, rokProdukcji, cenaZaDzien)
    VALUES ('TST9999', N'TESTVIN99999999999', 'Fiat', '126p', 1985, 50.00);
END TRY
BEGIN CATCH
    PRINT 'Oczekiwany blad: ' + ERROR_MESSAGE();
END CATCH;
GO

-- [7] Test trg_PlatnoscComplexControl - platnosc z ujemna kwota
PRINT '--- Test 7: Blokada ujemnej platnosci (oczekiwany blad) ---';
BEGIN TRY
    INSERT INTO dbo.platnosci (kwota, metodaPlatnosci, wypozyczenie_id)
    VALUES (-100.00, 'karta', 1);
END TRY
BEGIN CATCH
    PRINT 'Oczekiwany blad: ' + ERROR_MESSAGE();
END CATCH;
GO

-- [8] Test trg_rezerwacja_status_pojazdu - potwierdzenie rezerwacji
PRINT '--- Test 8: Automatyczna zmiana statusu pojazdu po potwierdzeniu rezerwacji ---';
UPDATE dbo.rezerwacje SET [status] = 'potwierdzona' WHERE rezerwacja_id = 1;
SELECT p.pojazd_id, p.[status] AS 'Status pojazdu (oczekiwany: zarezerwowany)'
FROM pojazdy p
JOIN rezerwacje r ON p.pojazd_id = r.pojazd_id
WHERE r.rezerwacja_id = 1;
GO

-- [9] Test trg_Wypozyczenie_Zwrot_StatusPojazdu - zwrot pojazdu
PRINT '--- Test 9: Automatyczny status dostepny po zwrocie ---';
-- Znajdz aktywne wypozyczenie bez daty zwrotu
DECLARE @wid INT, @pid INT;
SELECT TOP 1 @wid = wypozyczenie_id, @pid = pojazd_id
FROM wypozyczenia WHERE dataRzeczywistegoZwrotu IS NULL;
-- Najpierw ustaw pojazd jako wypozyczony
UPDATE pojazdy SET [status] = 'wypozyczony' WHERE pojazd_id = @pid;
-- Teraz wpisz date zwrotu
UPDATE wypozyczenia SET dataRzeczywistegoZwrotu = GETDATE() WHERE wypozyczenie_id = @wid;
SELECT pojazd_id, [status] AS 'Status (oczekiwany: dostepny)'
FROM pojazdy WHERE pojazd_id = @pid;
GO

-- [10] Test trg_Pojazdy_Archive_Delete / trg_Klienci_Archive_Delete
PRINT '--- Test 10: Archiwizacja usunietych rekordow ---';
-- Wstawiamy tymczasowy pojazd i klienta, potem usuwamy
INSERT INTO dbo.pojazdy(nrRejestr,nrVIN,marka,model,rokProdukcji,cenaZaDzien)
VALUES('DEL0001',N'DELVIN00000000001','Test','Delete',2020,99.00);

INSERT INTO dbo.klienci(imie,nazwisko,pesel,telefon,adres,prywatny)
VALUES('Testowy','DoUsuniecia','99999999999','500000000','ul. Testowa 1, Warszawa',1);

DECLARE @del_pid INT = (SELECT pojazd_id FROM pojazdy WHERE nrRejestr='DEL0001');
DECLARE @del_kid INT = (SELECT klient_id FROM klienci WHERE pesel='99999999999');

DELETE FROM pojazdy WHERE pojazd_id = @del_pid;
DELETE FROM klienci WHERE klient_id = @del_kid;

SELECT * FROM dbo.ArchiwumPojazdy  WHERE nrRejestr = 'DEL0001';
SELECT * FROM dbo.ArchiwumKlienci  WHERE pesel     = '99999999999';
GO

PRINT '=== WSZYSTKIE TESTY ZAKONCZONE ===';
GO