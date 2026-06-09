
-- 1. BAZA DANYCH
IF DB_ID('ProjektWypo') IS NOT NULL
BEGIN
    ALTER DATABASE ProjektWypo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ProjektWypo;
END
GO

CREATE DATABASE ProjektWypo;
GO

USE ProjektWypo;
GO


-- 2. TABELE GLOWNE

CREATE TABLE pojazdy (
    pojazd_id    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    nrRejestr    NVARCHAR(15)      NOT NULL UNIQUE,
    nrVIN        NCHAR(17)         NOT NULL UNIQUE,
    marka        NVARCHAR(40)      NOT NULL,
    model        NVARCHAR(40)      NOT NULL,
    rokProdukcji INT               CHECK(rokProdukcji BETWEEN 1950 AND 2100),
    [status]     NVARCHAR(20)      NOT NULL CHECK(status IN ('dostepny','wypozyczony','zarezerwowany','serwis')) DEFAULT 'dostepny',
    data_dodania DATE              DEFAULT GETDATE(),
    typNadwozia  NVARCHAR(30),
    przebieg     BIGINT            DEFAULT 0 CHECK(przebieg >= 0),
    cenaZaDzien  DECIMAL(10,2)     NOT NULL CHECK(cenaZaDzien >= 0)
);
GO

CREATE TABLE klienci (
    klient_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    imie      NVARCHAR(40)      NOT NULL,
    nazwisko  NVARCHAR(40)      NOT NULL,
    pesel     NCHAR(11)         NOT NULL UNIQUE,
    telefon   NVARCHAR(15)      NOT NULL,
    email     NVARCHAR(50)      UNIQUE,
    adres     NVARCHAR(200)     NOT NULL,
    prywatny  BIT               NOT NULL
);
GO

CREATE TABLE pracownicy (
    pracownik_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    imie         NVARCHAR(40)      NOT NULL,
    nazwisko     NVARCHAR(40)      NOT NULL,
    telefon      NVARCHAR(15)      NOT NULL,
    email        NVARCHAR(50),
    stanowisko   NVARCHAR(50)      NOT NULL
);
GO

CREATE TABLE wypozyczenia (
    wypozyczenie_id          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    dataWypozyczenia         DATE              NOT NULL,
    dataPlanowanegoZwrotu    DATE              NOT NULL,
    dataRzeczywistegoZwrotu  DATE              NULL,
    kwotaCalkowita           DECIMAL(10,2)     DEFAULT 0 CHECK(kwotaCalkowita >= 0),
    klient_id                INT               NOT NULL FOREIGN KEY REFERENCES klienci(klient_id),
    pojazd_id                INT               NOT NULL FOREIGN KEY REFERENCES pojazdy(pojazd_id),
    pracownik_id             INT               NULL     FOREIGN KEY REFERENCES pracownicy(pracownik_id),
    CONSTRAINT chk_wypozyczenia_rzeczywisty
        CHECK(dataRzeczywistegoZwrotu IS NULL OR dataRzeczywistegoZwrotu >= dataWypozyczenia)
);
GO

CREATE TABLE platnosci (
    platnosc_id      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    kwota            DECIMAL(10,2)     NOT NULL CHECK(kwota >= 0),
    dataPlatnosci    DATETIME2         DEFAULT SYSDATETIME(),
    metodaPlatnosci  NVARCHAR(30)      NOT NULL CHECK(metodaPlatnosci IN ('gotowka','karta','przelew','blik')),
    wypozyczenie_id  INT               NOT NULL FOREIGN KEY REFERENCES wypozyczenia(wypozyczenie_id)
);
GO

CREATE TABLE uszkodzenia (
    uszkodzenie_id  INT IDENTITY(1,1) PRIMARY KEY,
    opis            NVARCHAR(500)     NOT NULL,
    koszt           DECIMAL(10,2)     NOT NULL CHECK(koszt >= 0),
    data_zgloszenia DATE              DEFAULT GETDATE(),
    wypozyczenie_id INT               NOT NULL FOREIGN KEY REFERENCES wypozyczenia(wypozyczenie_id)
);
GO

CREATE TABLE premiePracownikow (
    premia_id    INT IDENTITY(1,1) PRIMARY KEY,
    miesiac      DATE              NOT NULL,
    kwota        DECIMAL(7,2)      NOT NULL CHECK(kwota >= 0),
    opis         NVARCHAR(200),
    pracownik_id INT               NOT NULL FOREIGN KEY REFERENCES pracownicy(pracownik_id)
);
GO

CREATE TABLE rezerwacje (
    rezerwacja_id  INT IDENTITY(1,1) PRIMARY KEY,
    klient_id      INT               NOT NULL FOREIGN KEY REFERENCES klienci(klient_id),
    pojazd_id      INT               NOT NULL FOREIGN KEY REFERENCES pojazdy(pojazd_id),
    data_utworzenia DATE             DEFAULT GETDATE(),
    data_od        DATE              NOT NULL,
    data_do        DATE              NOT NULL,
    [status]       NVARCHAR(20)      DEFAULT 'oczekuje' CHECK(status IN ('oczekuje','potwierdzona','anulowana')),
    CONSTRAINT chk_rezerwacje_daty CHECK(data_do >= data_od)
);
GO

CREATE TABLE Ubezpieczenie_wypozyczenia (
    ubezpieczenie_id  INT IDENTITY(1,1) PRIMARY KEY,
    wypozyczenie_id   INT               NOT NULL FOREIGN KEY REFERENCES wypozyczenia(wypozyczenie_id),
    typ_ubezpieczenia VARCHAR(100)       NOT NULL,
    koszt             DECIMAL(10,2)     NOT NULL,
    suma_gwarancyjna  DECIMAL(12,2)     NOT NULL,
    warunki           NVARCHAR(2000)
);
GO


-- 3. TABELE POMOCNICZE (audyt, archiwum, historia)

CREATE TABLE dbo.KlientAudit (
    AuditID    INT IDENTITY PRIMARY KEY,
    KlientID   INT          NOT NULL,
    OpisZmiany NVARCHAR(200) NOT NULL,
    DataZmiany DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.PracownicyAudit (
    AuditID          INT IDENTITY PRIMARY KEY,
    PracownikID      INT          NOT NULL,
    ZmienioneKolumny NVARCHAR(200),
    DataZmiany       DATETIME     DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.historia_cen_pojazdow (
    historia_id INT IDENTITY(1,1) PRIMARY KEY,
    pojazd_id   INT           NOT NULL,
    stara_cena  DECIMAL(10,2),
    nowa_cena   DECIMAL(10,2),
    data_zmiany DATETIME      DEFAULT GETDATE(),
    uzytkownik  NVARCHAR(100) DEFAULT SUSER_SNAME()
);
GO

CREATE TABLE dbo.ArchiwumPojazdy (
    ArchiwumID    INT IDENTITY(1,1) PRIMARY KEY,
    pojazd_id     INT,
    nrRejestr     NVARCHAR(15),
    marka         NVARCHAR(40),
    model         NVARCHAR(40),
    DataUsuniecia DATETIME      DEFAULT GETDATE(),
    UsunietePrzez NVARCHAR(100) DEFAULT SUSER_SNAME()
);
GO

CREATE TABLE dbo.ArchiwumKlienci (
    ArchiwumID    INT IDENTITY(1,1) PRIMARY KEY,
    klient_id     INT,
    imie          NVARCHAR(40),
    nazwisko      NVARCHAR(40),
    pesel         NCHAR(11),
    DataUsuniecia DATETIME      DEFAULT GETDATE(),
    UsunietePrzez NVARCHAR(100) DEFAULT SUSER_SNAME()
);
GO

CREATE TABLE dbo.WypozyczalniaDDLAudit (
    AuditID        INT IDENTITY PRIMARY KEY,
    TypZdarzenia   NVARCHAR(100) NOT NULL,
    NazwaObiektu   NVARCHAR(256) NULL,
    TrescPolecenia NVARCHAR(MAX) NULL,
    DataZdarzenia  DATETIME      NOT NULL DEFAULT GETDATE()
);
GO


-- 4. FUNKCJE UZYTKOWNIKA

-- [F1] Aktywne wypozyczenia (inline TVF)
CREATE FUNCTION dbo.AktywneWypozyczenia()
RETURNS TABLE AS
RETURN (
    SELECT w.wypozyczenie_id, k.imie, k.nazwisko,
           p.marka, p.model,
           w.dataWypozyczenia, w.dataPlanowanegoZwrotu
    FROM wypozyczenia w
    JOIN klienci k ON w.klient_id = k.klient_id
    JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
    WHERE w.dataRzeczywistegoZwrotu IS NULL
);
GO

-- [F2] Liczba dni wypozyczenia (skalarna)
CREATE FUNCTION dbo.LiczbaDniWypozyczenia(@dataOd DATE, @dataDo DATE)
RETURNS INT AS
BEGIN
    RETURN DATEDIFF(DAY, @dataOd, @dataDo) + 1
END
GO

-- [F3] Koszt wypozyczenia (skalarna)
CREATE FUNCTION dbo.KosztWypozyczenia(@pojazd_id INT, @dataOd DATE, @dataDo DATE)
RETURNS DECIMAL(10,2) AS
BEGIN
    DECLARE @cena DECIMAL(10,2)
    SELECT @cena = cenaZaDzien FROM pojazdy WHERE pojazd_id = @pojazd_id
    RETURN @cena * (DATEDIFF(DAY, @dataOd, @dataDo) + 1)
END
GO

-- [F4] Czy staly klient (skalarna)
CREATE FUNCTION dbo.CzyStalyKlient(@klient_id INT)
RETURNS VARCHAR(20) AS
BEGIN
    DECLARE @liczba INT
    SELECT @liczba = COUNT(*) FROM wypozyczenia WHERE klient_id = @klient_id
    IF @liczba >= 5 RETURN 'Staly klient'
    RETURN 'Niestaly klient'
END
GO

-- [F5] Oblicz kare za spoznienie (skalarna)
CREATE FUNCTION dbo.ObliczKareZaSpoznienie(
    @dataPlanowanegoZwrotu   DATE,
    @dataRzeczywistegoZwrotu DATE,
    @karaZaDzien             DECIMAL(10,2))
RETURNS DECIMAL(10,2) AS
BEGIN
    DECLARE @dni INT
    SET @dni = DATEDIFF(DAY, @dataPlanowanegoZwrotu, @dataRzeczywistegoZwrotu)
    IF @dni <= 0 RETURN 0
    RETURN @dni * @karaZaDzien
END
GO

-- [F6] Wartosc klienta (skalarna)
CREATE FUNCTION dbo.WartoscKlienta(@klient_id INT)
RETURNS DECIMAL(12,2) AS
BEGIN
    DECLARE @suma DECIMAL(12,2)
    SELECT @suma = ISNULL(SUM(kwotaCalkowita), 0)
    FROM wypozyczenia WHERE klient_id = @klient_id
    RETURN @suma
END
GO


-- 5. WIDOKI

CREATE VIEW vw_SzczegolyWypozyczen AS
SELECT w.wypozyczenie_id,
       k.imie + ' ' + k.nazwisko  AS klient,
       p.marka + ' ' + p.model    AS pojazd,
       p.nrRejestr,
       pr.imie + ' ' + pr.nazwisko AS pracownik,
       w.dataWypozyczenia,
       w.dataPlanowanegoZwrotu,
       w.dataRzeczywistegoZwrotu,
       w.kwotaCalkowita
FROM wypozyczenia w
JOIN klienci k    ON w.klient_id    = k.klient_id
JOIN pojazdy p    ON w.pojazd_id    = p.pojazd_id
LEFT JOIN pracownicy pr ON w.pracownik_id = pr.pracownik_id;
GO

CREATE VIEW vw_HistoriaKlientow AS
SELECT k.klient_id, k.imie, k.nazwisko,
       COUNT(w.wypozyczenie_id)  AS liczba_wypozyczen,
       SUM(w.kwotaCalkowita)     AS laczna_wartosc_wypozyczen,
       MAX(w.dataWypozyczenia)   AS ostatnie_wypozyczenie
FROM klienci k
LEFT JOIN wypozyczenia w ON k.klient_id = w.klient_id
GROUP BY k.klient_id, k.imie, k.nazwisko;
GO

CREATE VIEW vw_NajlepsiKlienci AS
SELECT k.klient_id, k.imie, k.nazwisko,
       COUNT(w.wypozyczenie_id) AS liczba_wypozyczen,
       SUM(w.kwotaCalkowita)    AS laczna_kwota
FROM klienci k
JOIN wypozyczenia w ON k.klient_id = w.klient_id
GROUP BY k.klient_id, k.imie, k.nazwisko;
GO

CREATE VIEW vw_NajbardziejEfektywnyPracownik AS
SELECT TOP 3
    pr.pracownik_id, pr.imie, pr.nazwisko,
    COUNT(w.wypozyczenie_id) AS liczba_wypozyczen
FROM pracownicy pr
JOIN wypozyczenia w ON pr.pracownik_id = w.pracownik_id
GROUP BY pr.pracownik_id, pr.imie, pr.nazwisko
ORDER BY liczba_wypozyczen DESC;
GO

CREATE VIEW vw_NajchetniejWybieranyTypNadwoazia AS
SELECT TOP 1
    p.typNadwozia,
    COUNT(*) AS liczba_wypozyczen
FROM wypozyczenia w
JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
GROUP BY p.typNadwozia
ORDER BY COUNT(*) DESC;
GO

CREATE VIEW vw_PojazdyDoKontroli AS
SELECT pojazd_id, nrRejestr, marka, model, przebieg, [status]
FROM pojazdy
WHERE przebieg >= 200000 OR [status] = 'serwis';
GO

CREATE VIEW vw_MiesiecznePrzychody AS
SELECT YEAR(dataPlatnosci)  AS rok,
       MONTH(dataPlatnosci) AS miesiac,
       COUNT(*)             AS liczba_transakcji,
       SUM(kwota)           AS przychod
FROM platnosci
GROUP BY YEAR(dataPlatnosci), MONTH(dataPlatnosci);
GO

CREATE VIEW vw_UszkodzeniaWypozyczen AS
SELECT w.wypozyczenie_id,
       k.imie + ' ' + k.nazwisko AS klient,
       p.marka + ' ' + p.model   AS pojazd,
       COUNT(u.uszkodzenie_id)   AS liczba_uszkodzen,
       SUM(u.koszt)              AS laczny_koszt_uszkodzen
FROM wypozyczenia w
JOIN klienci k    ON w.klient_id       = k.klient_id
JOIN pojazdy p    ON w.pojazd_id       = p.pojazd_id
LEFT JOIN uszkodzenia u ON w.wypozyczenie_id = u.wypozyczenie_id
GROUP BY w.wypozyczenie_id, k.imie, k.nazwisko, p.marka, p.model;
GO


-- 6. TRIGGERY

-- [T1] Audyt zmian danych klienta
CREATE OR ALTER TRIGGER trg_KlientDaneAudit ON dbo.klienci AFTER UPDATE AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN; SET NOCOUNT ON;
    DECLARE @opis NVARCHAR(200) = '';
    IF UPDATE(imie)     SET @opis += 'imie; ';
    IF UPDATE(nazwisko) SET @opis += 'nazwisko; ';
    IF UPDATE(pesel)    SET @opis += 'pesel; ';
    IF UPDATE(email)    SET @opis += 'email; ';
    IF LEN(@opis) = 0 SET @opis = 'inne dane';
    INSERT INTO dbo.KlientAudit (KlientID, OpisZmiany)
    SELECT i.klient_id, 'Zmienione kolumny: ' + @opis FROM inserted i;
END;
GO

-- [T2] Audyt zmian danych pracownika
CREATE OR ALTER TRIGGER trg_PracownikAudit ON dbo.pracownicy AFTER UPDATE AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN; SET NOCOUNT ON;
    DECLARE @opis NVARCHAR(200) = '';
    IF UPDATE(imie)       SET @opis += 'imie; ';
    IF UPDATE(nazwisko)   SET @opis += 'nazwisko; ';
    IF UPDATE(stanowisko) SET @opis += 'stanowisko; ';
    IF UPDATE(email)      SET @opis += 'email; ';
    IF LEN(@opis) = 0 SET @opis = 'inne dane';
    INSERT INTO dbo.PracownicyAudit (PracownikID, ZmienioneKolumny)
    SELECT i.pracownik_id, 'Zmienione kolumny: ' + @opis FROM inserted i;
END;
GO

-- [T3] Ochrona przed cofaniem przebiegu
CREATE OR ALTER TRIGGER trg_PojazdPrzebiegKorekta ON dbo.pojazdy AFTER UPDATE AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    SET NOCOUNT ON;
    UPDATE p SET p.przebieg = d.przebieg
    FROM dbo.pojazdy p
    JOIN inserted i ON p.pojazd_id = i.pojazd_id
    JOIN deleted  d ON d.pojazd_id = i.pojazd_id
    WHERE i.przebieg < d.przebieg;
END;
GO

-- [T4] Historia zmian ceny za dobe
CREATE OR ALTER TRIGGER trg_loguj_zmiane_ceny ON dbo.pojazdy AFTER UPDATE AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN; SET NOCOUNT ON;
    IF UPDATE(cenaZaDzien)
        INSERT INTO dbo.historia_cen_pojazdow (pojazd_id, stara_cena, nowa_cena)
        SELECT d.pojazd_id, d.cenaZaDzien, i.cenaZaDzien
        FROM inserted i JOIN deleted d ON i.pojazd_id = d.pojazd_id
        WHERE i.cenaZaDzien <> d.cenaZaDzien;
END;
GO

-- [T5] Blokada zmiany VIN
CREATE OR ALTER TRIGGER trg_BlockVINChange ON dbo.pojazdy AFTER UPDATE AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    IF UPDATE(nrVIN)
        THROW 50003, 'Zmiana numeru VIN zarejestrowanego pojazdu jest zabroniona.', 1;
END;
GO

-- [T6] Walidacja roku produkcji (INSTEAD OF INSERT)
CREATE OR ALTER TRIGGER trg_PojazdInsertValidation ON dbo.pojazdy INSTEAD OF INSERT AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN; SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE rokProdukcji < 2000)
        THROW 50001, 'Nie przyjmujemy pojazdow starszych niz rok 2000.', 1;
    INSERT INTO dbo.pojazdy
        (nrRejestr,nrVIN,marka,model,rokProdukcji,[status],data_dodania,typNadwozia,przebieg,cenaZaDzien)
    SELECT nrRejestr,nrVIN,marka,model,rokProdukcji,[status],data_dodania,typNadwozia,przebieg,cenaZaDzien
    FROM inserted;
END;
GO

-- [T7] Walidacja platnosci (INSTEAD OF INSERT)
CREATE OR ALTER TRIGGER trg_PlatnoscComplexControl ON dbo.platnosci INSTEAD OF INSERT AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN; SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE kwota <= 0)
        THROW 50004, 'Kwota platnosci musi byc dodatnia.', 1;
    IF EXISTS (
        SELECT 1 FROM inserted i
        LEFT JOIN dbo.wypozyczenia w ON i.wypozyczenie_id = w.wypozyczenie_id
        WHERE w.wypozyczenie_id IS NULL)
        THROW 50005, 'Blad: powiazane wypozyczenie nie istnieje w bazie.', 1;
    INSERT INTO dbo.platnosci (kwota,dataPlatnosci,metodaPlatnosci,wypozyczenie_id)
    SELECT kwota,dataPlatnosci,metodaPlatnosci,wypozyczenie_id FROM inserted;
END;
GO

-- [T8] Automatyczna zmiana statusu pojazdu przy rezerwacji
CREATE OR ALTER TRIGGER trg_rezerwacja_status_pojazdu ON dbo.rezerwacje AFTER INSERT, UPDATE AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    SET NOCOUNT ON;
    UPDATE p SET p.[status] = 'zarezerwowany'
    FROM dbo.pojazdy p JOIN inserted i ON p.pojazd_id = i.pojazd_id
    WHERE i.[status] = 'potwierdzona';
    UPDATE p SET p.[status] = 'dostepny'
    FROM dbo.pojazdy p JOIN inserted i ON p.pojazd_id = i.pojazd_id
    WHERE i.[status] = 'anulowana' AND p.[status] = 'zarezerwowany';
END;
GO

-- [T9] Automatyczny status dostepny po zwrocie pojazdu
CREATE OR ALTER TRIGGER trg_Wypozyczenie_Zwrot_StatusPojazdu ON dbo.wypozyczenia AFTER UPDATE AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN;
    IF TRIGGER_NESTLEVEL() > 1 RETURN;
    SET NOCOUNT ON;
    UPDATE p SET p.[status] = 'dostepny'
    FROM dbo.pojazdy p
    JOIN inserted i ON p.pojazd_id = i.pojazd_id
    JOIN deleted  d ON d.pojazd_id = i.pojazd_id
    WHERE d.dataRzeczywistegoZwrotu IS NULL
      AND i.dataRzeczywistegoZwrotu IS NOT NULL
      AND p.[status] = 'wypozyczony';
END;
GO

-- [T10] Archiwizacja usunietych pojazdow
CREATE OR ALTER TRIGGER trg_Pojazdy_Archive_Delete ON dbo.pojazdy AFTER DELETE AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN; SET NOCOUNT ON;
    INSERT INTO dbo.ArchiwumPojazdy (pojazd_id,nrRejestr,marka,model)
    SELECT pojazd_id,nrRejestr,marka,model FROM deleted;
END;
GO

-- [T11] Archiwizacja usunietych klientow
CREATE OR ALTER TRIGGER trg_Klienci_Archive_Delete ON dbo.klienci AFTER DELETE AS
BEGIN
    IF (ROWCOUNT_BIG() = 0) RETURN; SET NOCOUNT ON;
    INSERT INTO dbo.ArchiwumKlienci (klient_id,imie,nazwisko,pesel)
    SELECT klient_id,imie,nazwisko,pesel FROM deleted;
END;
GO

-- [T12] DDL - logowanie DROP TABLE
CREATE OR ALTER TRIGGER trg_DDL_DropTable_Audit ON DATABASE AFTER DROP_TABLE AS
BEGIN
    DECLARE @data XML = EVENTDATA();
    INSERT INTO dbo.WypozyczalniaDDLAudit (TypZdarzenia,NazwaObiektu,TrescPolecenia)
    VALUES (
        @data.value('(/EVENT_INSTANCE/EventType)[1]',              'NVARCHAR(100)'),
        @data.value('(/EVENT_INSTANCE/ObjectName)[1]',             'NVARCHAR(256)'),
        @data.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]','NVARCHAR(MAX)')
    );
END;
GO


-- 7. PROCEDURY GENERUJACE DANE

CREATE OR ALTER PROCEDURE dbo.Gen_Pojazdy @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @M TABLE (id INT IDENTITY(1,1), ma NVARCHAR(40), mo NVARCHAR(40), ty NVARCHAR(30));
    INSERT INTO @M VALUES
        ('Toyota','Corolla','Sedan'),('Toyota','RAV4','SUV'),('Toyota','Yaris','Hatchback'),
        ('Toyota','Camry','Sedan'),('Toyota','Land Cruiser','SUV'),
        ('Volkswagen','Golf','Hatchback'),('Volkswagen','Passat','Kombi'),
        ('Volkswagen','Tiguan','SUV'),('Volkswagen','Polo','Hatchback'),
        ('BMW','320i','Sedan'),('BMW','X5','SUV'),('BMW','520d','Sedan'),('BMW','X3','SUV'),
        ('Audi','A4','Sedan'),('Audi','Q7','SUV'),('Audi','A6','Sedan'),('Audi','A3','Hatchback'),
        ('Ford','Focus','Hatchback'),('Ford','Mustang','Coupe'),('Ford','Kuga','SUV'),
        ('Skoda','Octavia','Kombi'),('Skoda','Fabia','Hatchback'),('Skoda','Superb','Sedan'),
        ('Mercedes','C 200','Sedan'),('Mercedes','GLC 300','SUV'),('Mercedes','E 220d','Kombi'),
        ('Renault','Megane','Hatchback'),('Renault','Captur','SUV'),('Renault','Clio','Hatchback'),
        ('Peugeot','308','Hatchback'),('Peugeot','3008','SUV'),
        ('Hyundai','i30','Hatchback'),('Hyundai','Tucson','SUV'),
        ('Kia','Sportage','SUV'),('Kia','Ceed','Hatchback'),
        ('Mazda','CX-5','SUV'),('Mazda','3','Sedan'),
        ('Volvo','XC60','SUV'),('Volvo','V60','Kombi');

    DECLARE @S TABLE (s NVARCHAR(20));
    INSERT INTO @S VALUES ('dostepny'),('wypozyczony'),('zarezerwowany'),('serwis');

    DECLARE @i   INT=1, @mid INT=0, @ma NVARCHAR(40)='', @mo NVARCHAR(40)='', @ty NVARCHAR(30)='';
    DECLARE @nr  NVARCHAR(15)='', @vin NCHAR(17)='', @dd DATE=NULL;
    DECLARE @rok INT=0, @prz BIGINT=0, @cen DECIMAL(10,2)=0, @st NVARCHAR(20)='';

    WHILE @i <= @n
    BEGIN
        SET @mid=(SELECT TOP 1 id FROM @M ORDER BY NEWID());
        SELECT @ma=ma,@mo=mo,@ty=ty FROM @M WHERE id=@mid;
        SET @nr=CHAR(65+ABS(CHECKSUM(NEWID()))%26)+CHAR(65+ABS(CHECKSUM(NEWID()))%26)
               +CAST(ABS(CHECKSUM(NEWID()))%90000+10000 AS NVARCHAR(5));
        SET @vin=UPPER(LEFT(REPLACE(REPLACE(CAST(NEWID() AS NVARCHAR(36)),'-',''),' ',''),17));
        SET @dd=DATEADD(DAY,-(ABS(CHECKSUM(NEWID()))%730),GETDATE());
        SET @rok=ABS(CHECKSUM(NEWID()))%(YEAR(@dd)-2010+1)+2010;
        SET @prz=ABS(CHECKSUM(NEWID()))%250000;
        SET @cen=CAST(ABS(CHECKSUM(NEWID()))%350+60 AS DECIMAL(10,2));
        SET @st=(SELECT TOP 1 s FROM @S ORDER BY NEWID());
        INSERT INTO pojazdy(nrRejestr,nrVIN,marka,model,rokProdukcji,[status],data_dodania,typNadwozia,przebieg,cenaZaDzien)
        VALUES(@nr,@vin,@ma,@mo,@rok,@st,@dd,@ty,@prz,@cen);
        SET @i+=1;
    END
    PRINT 'pojazdy: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO

CREATE OR ALTER PROCEDURE dbo.Gen_Klienci @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Im TABLE (id INT IDENTITY(1,1), v NVARCHAR(20));
    INSERT INTO @Im VALUES ('Anna'),('Jan'),('Marek'),('Katarzyna'),('Piotr'),('Zofia'),
        ('Pawel'),('Monika'),('Tomasz'),('Ewa'),('Michal'),('Agnieszka'),('Krzysztof'),
        ('Barbara'),('Andrzej'),('Malgorzata'),('Robert'),('Joanna'),('Marcin'),('Dorota'),
        ('Lukasz'),('Elzbieta'),('Kamil'),('Natalia'),('Jakub'),('Karolina'),('Mateusz'),
        ('Patrycja'),('Grzegorz'),('Sylwia'),('Bartosz'),('Renata'),('Sebastian'),('Iwona'),
        ('Adrian'),('Halina');

    DECLARE @Na TABLE (id INT IDENTITY(1,1), v NVARCHAR(20));
    INSERT INTO @Na VALUES ('Nowak'),('Kowalski'),('Wisniewski'),('Wojcik'),('Kowalczyk'),
        ('Kaminski'),('Lewandowski'),('Zielinski'),('Szymanski'),('Wozniak'),('Dabrowski'),
        ('Kozlowski'),('Mazur'),('Jankowski'),('Kwiatkowski'),('Krawczyk'),('Kaczmarek'),
        ('Piotrowski'),('Grabowski'),('Zajac'),('Pawlowski'),('Michalski'),('Krol'),
        ('Wieczorek'),('Jablonski'),('Wrobel'),('Majewski'),('Olszewski'),('Stepien'),('Baran');

    DECLARE @Do TABLE (id INT IDENTITY(1,1), v NVARCHAR(15));
    INSERT INTO @Do VALUES ('gmail.com'),('wp.pl'),('outlook.com'),('onet.pl'),
                           ('interia.pl'),('o2.pl'),('yahoo.com'),('proton.me');

    DECLARE @Mi TABLE (id INT IDENTITY(1,1), v NVARCHAR(30));
    INSERT INTO @Mi VALUES ('Warszawa'),('Krakow'),('Wroclaw'),('Poznan'),('Gdansk'),
                           ('Szczecin'),('Bydgoszcz'),('Lublin'),('Katowice'),('Bialystok');

    DECLARE @Ul TABLE (id INT IDENTITY(1,1), v NVARCHAR(20));
    INSERT INTO @Ul VALUES ('Dluga'),('Krotka'),('Szeroka'),('Jasna'),('Cicha'),
                           ('Zielona'),('Lipowa'),('Klonowa'),('Polna'),('Lesna');

    DECLARE @wst INT=0, @iter INT=1;
    DECLARE @kimie NVARCHAR(20)='', @knazw NVARCHAR(20)='', @kdoma NVARCHAR(15)='';
    DECLARE @kmias NVARCHAR(30)='', @kulic NVARCHAR(20)='', @kpes NCHAR(11)='';
    DECLARE @kguid NCHAR(4)='', @kemai NVARCHAR(48)='', @ktel NVARCHAR(15)='', @kadre NVARCHAR(200)='';

    WHILE @wst < @n
    BEGIN
        SET @kimie=(SELECT TOP 1 v FROM @Im ORDER BY NEWID());
        SET @knazw=(SELECT TOP 1 v FROM @Na ORDER BY NEWID());
        SET @kdoma=(SELECT TOP 1 v FROM @Do ORDER BY NEWID());
        SET @kmias=(SELECT TOP 1 v FROM @Mi ORDER BY NEWID());
        SET @kulic=(SELECT TOP 1 v FROM @Ul ORDER BY NEWID());
        SET @kpes='900101'+REPLACE(STR(@iter,5),' ','0');
        SET @kguid=LEFT(REPLACE(CAST(NEWID() AS VARCHAR(36)),'-',''),4);
        SET @kemai=LOWER(LEFT(@kimie,6))+'.'+LOWER(LEFT(@knazw,8))+'_'+@kguid+'@'+@kdoma;
        IF LEN(@kemai)>48 SET @kemai=LEFT(@kemai,44)+'@gm.co';
        SET @ktel='5'+REPLACE(STR(FLOOR(RAND()*89999999+10000000),8),' ','0');
        SET @kadre='ul. '+@kulic+' '+CAST(@iter AS VARCHAR)+', '+@kmias;
        BEGIN TRY
            INSERT INTO klienci(imie,nazwisko,pesel,telefon,email,adres,prywatny)
            VALUES(@kimie,@knazw,@kpes,@ktel,@kemai,@kadre,CAST(ABS(CHECKSUM(NEWID()))%2 AS BIT));
            SET @wst+=1;
        END TRY
        BEGIN CATCH END CATCH
        SET @iter+=1;
        IF @iter>@n*10 BREAK;
    END
    PRINT 'klienci: '+CAST(@wst AS VARCHAR)+' rekordow';
END;
GO

CREATE OR ALTER PROCEDURE dbo.Gen_Pracownicy @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Im TABLE (v NVARCHAR(20), plec CHAR(1));
    INSERT INTO @Im VALUES
        ('Adam','M'),('Piotr','M'),('Marek','M'),('Jan','M'),('Krzysztof','M'),
        ('Andrzej','M'),('Tomasz','M'),('Pawel','M'),('Michal','M'),('Marcin','M'),
        ('Jakub','M'),('Mateusz','M'),('Lukasz','M'),('Robert','M'),('Grzegorz','M'),
        ('Anna','K'),('Maria','K'),('Katarzyna','K'),('Malgorzata','K'),('Agnieszka','K'),
        ('Barbara','K'),('Ewa','K'),('Magdalena','K'),('Elzbieta','K'),('Joanna','K'),
        ('Aleksandra','K'),('Zofia','K'),('Monika','K'),('Natalia','K'),('Karolina','K');

    DECLARE @Na TABLE (v NVARCHAR(20));
    INSERT INTO @Na VALUES ('Nowak'),('Kowalski'),('Wisniewski'),('Wojcik'),('Kowalczyk'),
        ('Kaminski'),('Lewandowski'),('Zielinski'),('Szymanski'),('Wozniak'),('Dabrowski'),
        ('Kozlowski'),('Mazur'),('Jankowski'),('Kwiatkowski'),('Wojciechowski'),('Krawczyk'),
        ('Kaczmarek'),('Piotrowski'),('Grabowski'),('Pawlowski'),('Michalski'),('Jablonski'),('Wrobel');

    DECLARE @St TABLE (v NVARCHAR(50));
    INSERT INTO @St VALUES ('Serwisant'),('Obsluga klienta'),('Kierownik'),('Sprzedawca'),
                           ('Logistyk'),('Mechanik'),('Recepcjonista'),('Koordynator floty');

    DECLARE @pi INT=1, @pimie NVARCHAR(20)='', @pplec CHAR(1)='M';
    DECLARE @pnazw NVARCHAR(20)='', @pstan NVARCHAR(50)='', @ptel NVARCHAR(15)='', @pemai NVARCHAR(50)='';

    WHILE @pi <= @n
    BEGIN
        SELECT TOP 1 @pimie=v,@pplec=plec FROM @Im ORDER BY NEWID();
        SET @pnazw=(SELECT TOP 1 v FROM @Na ORDER BY NEWID());
        IF @pplec='K'
        BEGIN
            IF   @pnazw LIKE '%ski'  SET @pnazw=LEFT(@pnazw,LEN(@pnazw)-3)+'ska';
            ELSE IF @pnazw LIKE '%cki'  SET @pnazw=LEFT(@pnazw,LEN(@pnazw)-3)+'cka';
            ELSE IF @pnazw LIKE '%dzki' SET @pnazw=LEFT(@pnazw,LEN(@pnazw)-4)+'dzka';
        END
        SET @pstan=(SELECT TOP 1 v FROM @St ORDER BY NEWID());
        SET @ptel=CAST(FLOOR(RAND()*900+100) AS VARCHAR(3))+'-'
                 +CAST(FLOOR(RAND()*900+100) AS VARCHAR(3))+'-'
                 +CAST(FLOOR(RAND()*900+100) AS VARCHAR(3));
        SET @pemai=LOWER(LEFT(@pimie,8))+'.'+LOWER(LEFT(@pnazw,10))+CAST(@pi AS VARCHAR(4))+'@firma.pl';
        INSERT INTO pracownicy(imie,nazwisko,telefon,email,stanowisko)
        VALUES(@pimie,@pnazw,@ptel,@pemai,@pstan);
        SET @pi+=1;
    END
    PRINT 'pracownicy: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO

CREATE OR ALTER PROCEDURE dbo.Gen_Wypozyczenia @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @i INT=0, @dw DATE=NULL, @dp DATE=NULL, @dr DATE=NULL;
    DECLARE @pid INT=0, @kid INT=0, @rid INT=0;
    DECLARE @ce DECIMAL(10,2)=0, @dn INT=0, @kw DECIMAL(10,2)=0;
    WHILE @i < @n
    BEGIN
        SET @dw=DATEADD(DAY,-(ABS(CHECKSUM(NEWID()))%365),GETDATE());
        SET @dp=DATEADD(DAY,ABS(CHECKSUM(NEWID()))%14+2,@dw);
        SET @dr=NULL;
        IF ABS(CHECKSUM(NEWID()))%100<75
        BEGIN
            SET @dr=DATEADD(DAY,(ABS(CHECKSUM(NEWID()))%5)-2,@dp);
            IF @dr>CAST(GETDATE() AS DATE) SET @dr=CAST(GETDATE() AS DATE);
            IF @dr<@dw SET @dr=@dw;
        END
        SET @pid=(SELECT TOP 1 pojazd_id    FROM pojazdy    ORDER BY NEWID());
        SET @kid=(SELECT TOP 1 klient_id    FROM klienci    ORDER BY NEWID());
        SET @rid=(SELECT TOP 1 pracownik_id FROM pracownicy ORDER BY NEWID());
        SELECT @ce=cenaZaDzien FROM pojazdy WHERE pojazd_id=@pid;
        SET @dn=DATEDIFF(DAY,@dw,ISNULL(@dr,@dp));
        IF @dn<=0 SET @dn=1;
        SET @kw=@ce*@dn;
        INSERT INTO wypozyczenia(dataWypozyczenia,dataPlanowanegoZwrotu,dataRzeczywistegoZwrotu,
                                 kwotaCalkowita,klient_id,pojazd_id,pracownik_id)
        VALUES(@dw,@dp,@dr,@kw,@kid,@pid,@rid);
        SET @i+=1;
    END
    PRINT 'wypozyczenia: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO

CREATE OR ALTER PROCEDURE dbo.Gen_Rezerwacje @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Ss TABLE (s NVARCHAR(20));
    INSERT INTO @Ss VALUES ('oczekuje'),('potwierdzona'),('anulowana');
    DECLARE @ri INT=1, @rki INT=0, @rpi INT=0, @rod DATE=NULL, @rdo DATE=NULL, @rst NVARCHAR(20)='';
    WHILE @ri <= @n
    BEGIN
        SET @rki=(SELECT TOP 1 klient_id FROM klienci ORDER BY NEWID());
        SET @rpi=(SELECT TOP 1 pojazd_id FROM pojazdy  ORDER BY NEWID());
        SET @rod=DATEADD(DAY,ABS(CHECKSUM(NEWID()))%90,GETDATE());
        SET @rdo=DATEADD(DAY,ABS(CHECKSUM(NEWID()))%21+1,@rod);
        SET @rst=(SELECT TOP 1 s FROM @Ss ORDER BY NEWID());
        INSERT INTO rezerwacje(klient_id,pojazd_id,data_utworzenia,data_od,data_do,[status])
        VALUES(@rki,@rpi,GETDATE(),@rod,@rdo,@rst);
        SET @ri+=1;
    END
    PRINT 'rezerwacje: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO

CREATE OR ALTER PROCEDURE dbo.Gen_Platnosci AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO platnosci(kwota,dataPlatnosci,metodaPlatnosci,wypozyczenie_id)
    SELECT w.kwotaCalkowita,
           DATEADD(MINUTE,ABS(CHECKSUM(NEWID()))%4320,CAST(w.dataWypozyczenia AS DATETIME2)),
           CASE ABS(CHECKSUM(NEWID()))%4
               WHEN 0 THEN 'gotowka' WHEN 1 THEN 'karta' WHEN 2 THEN 'przelew' ELSE 'blik' END,
           w.wypozyczenie_id
    FROM wypozyczenia w
    WHERE NOT EXISTS(SELECT 1 FROM platnosci p WHERE p.wypozyczenie_id=w.wypozyczenie_id)
      AND w.kwotaCalkowita>0;
    PRINT 'platnosci: wstawiono';
END;
GO

CREATE OR ALTER PROCEDURE dbo.Gen_Uszkodzenia @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Op TABLE (id INT IDENTITY(1,1), v NVARCHAR(200));
    INSERT INTO @Op VALUES
        ('Zarysowanie powloki lakierniczej na drzwiach kierowcy'),
        ('Peknięta przednia szyba – odprysk kamienia'),
        ('Wgniecenie tylnego zderzaka – szkoda parkingowa'),
        ('Uszkodzenie felgi aluminiowej – najechanie na kraweznik'),
        ('Rozdarcie tapicerki fotela pasazera'),
        ('Uszkodzenie lusterka zewnetrznego lewego'),
        ('Peknięcie klosza tylnego swiatla'),
        ('Wgniecenie maski – stluczka parkingowa'),
        ('Zarysowanie klapy bagaznika'),
        ('Peknięcie zderzaka przedniego – uderzenie w slupek'),
        ('Ubytki lakieru na dachu – opad chemiczny');
    DECLARE @ui INT=1, @uid INT=0, @udw DATE=NULL;
    WHILE @ui <= @n
    BEGIN
        SELECT TOP 1 @uid=wypozyczenie_id,@udw=dataWypozyczenia FROM wypozyczenia ORDER BY NEWID();
        INSERT INTO uszkodzenia(opis,koszt,data_zgloszenia,wypozyczenie_id)
        SELECT TOP 1 v,CAST(ABS(CHECKSUM(NEWID()))%4800+200 AS DECIMAL(10,2)),
               DATEADD(DAY,ABS(CHECKSUM(NEWID()))%10,@udw),@uid
        FROM @Op ORDER BY NEWID();
        SET @ui+=1;
    END
    PRINT 'uszkodzenia: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO

CREATE OR ALTER PROCEDURE dbo.Gen_Premie @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Op TABLE (id INT IDENTITY(1,1), v NVARCHAR(100));
    INSERT INTO @Op VALUES ('Premia uznaniowa'),('Wysoka efektywnosc sprzedazy'),
        ('Premia swiateczna'),('Realizacja planu kwartalnego'),
        ('Nagroda za pozyskanie klienta korporacyjnego'),
        ('Premia roczna'),('Wyroznienie miesiaca'),('Premia za nadgodziny');
    DECLARE @prei INT=1, @prepid INT=0, @premi DATE=NULL;
    WHILE @prei <= @n
    BEGIN
        SET @prepid=(SELECT TOP 1 pracownik_id FROM pracownicy ORDER BY NEWID());
        SET @premi=DATEFROMPARTS(2022+CAST(RAND()*3 AS INT),CAST(RAND()*12+1 AS INT),1);
        INSERT INTO premiePracownikow(miesiac,kwota,opis,pracownik_id)
        SELECT TOP 1 @premi,CAST(RAND()*3000+300 AS DECIMAL(7,2)),v,@prepid
        FROM @Op ORDER BY NEWID();
        SET @prei+=1;
    END
    PRINT 'premiePracownikow: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO

CREATE OR ALTER PROCEDURE dbo.Gen_Ubezpieczenia AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ubwid INT=0, @ubt INT=0;
    DECLARE cur CURSOR FAST_FORWARD FOR
        SELECT w.wypozyczenie_id FROM wypozyczenia w
        WHERE NOT EXISTS(SELECT 1 FROM Ubezpieczenie_wypozyczenia u WHERE u.wypozyczenie_id=w.wypozyczenie_id);
    OPEN cur; FETCH NEXT FROM cur INTO @ubwid;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @ubt=ABS(CHECKSUM(NEWID()))%3+1;
        INSERT INTO Ubezpieczenie_wypozyczenia(wypozyczenie_id,typ_ubezpieczenia,koszt,suma_gwarancyjna,warunki)
        VALUES(@ubwid,
            CHOOSE(@ubt,'Podstawowe OC/AC','Pelne Premium','Szyby i Opony Plus'),
            CHOOSE(@ubt,49.00,149.00,29.00),
            CHOOSE(@ubt,50000.00,250000.00,5000.00),
            CHOOSE(@ubt,'Udzial wlasny w szkodzie do 2000 PLN.',
                        'Brak udzialu wlasnego, ochrona 24/7, auto zastępcze.',
                        'Ochrona elementow szklanych i ogumienia bez utraty znizek.'));
        FETCH NEXT FROM cur INTO @ubwid;
    END
    CLOSE cur; DEALLOCATE cur;
    PRINT 'Ubezpieczenia: przypisano do wszystkich wypozyczen';
END;
GO


-- 8. WYPELNIENIE DANYCH
EXEC dbo.Gen_Pojazdy      300;
EXEC dbo.Gen_Klienci      200;
EXEC dbo.Gen_Pracownicy    50;
EXEC dbo.Gen_Wypozyczenia 400;
EXEC dbo.Gen_Rezerwacje   100;
EXEC dbo.Gen_Platnosci;
EXEC dbo.Gen_Uszkodzenia   50;
EXEC dbo.Gen_Premie       150;
EXEC dbo.Gen_Ubezpieczenia;
GO


-- PODSUMOWANIE
SELECT 'pojazdy'                     AS tabela, COUNT(*) AS rekordy FROM pojazdy                    UNION ALL
SELECT 'klienci',                               COUNT(*)            FROM klienci                    UNION ALL
SELECT 'pracownicy',                            COUNT(*)            FROM pracownicy                 UNION ALL
SELECT 'wypozyczenia',                          COUNT(*)            FROM wypozyczenia               UNION ALL
SELECT 'rezerwacje',                            COUNT(*)            FROM rezerwacje                 UNION ALL
SELECT 'platnosci',                             COUNT(*)            FROM platnosci                  UNION ALL
SELECT 'uszkodzenia',                           COUNT(*)            FROM uszkodzenia                UNION ALL
SELECT 'premiePracownikow',                     COUNT(*)            FROM premiePracownikow          UNION ALL
SELECT 'Ubezpieczenie_wypozyczenia',            COUNT(*)            FROM Ubezpieczenie_wypozyczenia;

PRINT '=== INSTALACJA ZAKONCZONA POMYSLNIE ===';
