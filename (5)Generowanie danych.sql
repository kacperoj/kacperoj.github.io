-- ============================================================
--  SKRYPT GENERATORA DANYCH  -  Wypozyczalnia Samochodow
--  Uruchom w NOWYM oknie SSMS (Ctrl+N), wklej i wykonaj F5
--  REGULA T-SQL: DECLARE tylko przed petla, w petli wylacznie SET
-- ============================================================
USE ProjektWypo;
GO

-- ============================================================
-- 1. POJAZDY
-- ============================================================
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

    DECLARE @i   INT           = 1;
    DECLARE @mid INT           = 0;
    DECLARE @ma  NVARCHAR(40)  = '';
    DECLARE @mo  NVARCHAR(40)  = '';
    DECLARE @ty  NVARCHAR(30)  = '';
    DECLARE @nr  NVARCHAR(15)  = '';
    DECLARE @vin NCHAR(17)     = '';
    DECLARE @dd  DATE          = NULL;
    DECLARE @rok INT           = 0;
    DECLARE @prz BIGINT        = 0;
    DECLARE @cen DECIMAL(10,2) = 0;
    DECLARE @st  NVARCHAR(20)  = '';

    WHILE @i <= @n
    BEGIN
        SET @mid = (SELECT TOP 1 id FROM @M ORDER BY NEWID());
        SELECT @ma=ma, @mo=mo, @ty=ty FROM @M WHERE id=@mid;
        SET @nr  = CHAR(65+ABS(CHECKSUM(NEWID()))%26)+CHAR(65+ABS(CHECKSUM(NEWID()))%26)
                   +CAST(ABS(CHECKSUM(NEWID()))%90000+10000 AS NVARCHAR(5));
        SET @vin = UPPER(LEFT(REPLACE(REPLACE(CAST(NEWID() AS NVARCHAR(36)),'-',''),' ',''),17));
        SET @dd  = DATEADD(DAY,-(ABS(CHECKSUM(NEWID()))%730),GETDATE());
        SET @rok = ABS(CHECKSUM(NEWID()))%(YEAR(@dd)-2010+1)+2010;
        SET @prz = ABS(CHECKSUM(NEWID()))%250000;
        SET @cen = CAST(ABS(CHECKSUM(NEWID()))%350+60 AS DECIMAL(10,2));
        SET @st  = (SELECT TOP 1 s FROM @S ORDER BY NEWID());
        INSERT INTO pojazdy(nrRejestr,nrVIN,marka,model,rokProdukcji,[status],data_dodania,typNadwozia,przebieg,cenaZaDzien)
        VALUES(@nr,@vin,@ma,@mo,@rok,@st,@dd,@ty,@prz,@cen);
        SET @i += 1;
    END
    PRINT 'pojazdy: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO
EXEC dbo.Gen_Pojazdy 300;
GO

-- ============================================================
-- 2. KLIENCI
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.Gen_Klienci @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Im TABLE (id INT IDENTITY(1,1), v NVARCHAR(20));
    INSERT INTO @Im VALUES
        ('Anna'),('Jan'),('Marek'),('Katarzyna'),('Piotr'),('Zofia'),('Pawel'),('Monika'),
        ('Tomasz'),('Ewa'),('Michal'),('Agnieszka'),('Krzysztof'),('Barbara'),('Andrzej'),
        ('Malgorzata'),('Robert'),('Joanna'),('Marcin'),('Dorota'),('Lukasz'),('Elzbieta'),
        ('Kamil'),('Natalia'),('Jakub'),('Karolina'),('Mateusz'),('Patrycja'),('Grzegorz'),
        ('Sylwia'),('Bartosz'),('Renata'),('Sebastian'),('Iwona'),('Adrian'),('Halina');

    DECLARE @Na TABLE (id INT IDENTITY(1,1), v NVARCHAR(20));
    INSERT INTO @Na VALUES
        ('Nowak'),('Kowalski'),('Wisniewski'),('Wojcik'),('Kowalczyk'),('Kaminski'),
        ('Lewandowski'),('Zielinski'),('Szymanski'),('Wozniak'),('Dabrowski'),('Kozlowski'),
        ('Mazur'),('Jankowski'),('Kwiatkowski'),('Krawczyk'),('Kaczmarek'),('Piotrowski'),
        ('Grabowski'),('Zajac'),('Pawlowski'),('Michalski'),('Krol'),('Wieczorek'),
        ('Jablonski'),('Wrobel'),('Majewski'),('Olszewski'),('Stepien'),('Baran');

    DECLARE @Do TABLE (id INT IDENTITY(1,1), v NVARCHAR(15));
    INSERT INTO @Do VALUES ('gmail.com'),('wp.pl'),('outlook.com'),('onet.pl'),
                           ('interia.pl'),('o2.pl'),('yahoo.com'),('proton.me');

    DECLARE @Mi TABLE (id INT IDENTITY(1,1), v NVARCHAR(30));
    INSERT INTO @Mi VALUES ('Warszawa'),('Krakow'),('Wroclaw'),('Poznan'),('Gdansk'),
                           ('Szczecin'),('Bydgoszcz'),('Lublin'),('Katowice'),('Bialystok');

    DECLARE @Ul TABLE (id INT IDENTITY(1,1), v NVARCHAR(20));
    INSERT INTO @Ul VALUES ('Dluga'),('Krotka'),('Szeroka'),('Jasna'),('Cicha'),
                           ('Zielona'),('Lipowa'),('Klonowa'),('Polna'),('Lesna');

    DECLARE @wst   INT           = 0;
    DECLARE @iter  INT           = 1;
    DECLARE @kimie NVARCHAR(20)  = '';
    DECLARE @knazw NVARCHAR(20)  = '';
    DECLARE @kdoma NVARCHAR(15)  = '';
    DECLARE @kmias NVARCHAR(30)  = '';
    DECLARE @kulic NVARCHAR(20)  = '';
    DECLARE @kpes  NCHAR(11)     = '';
    DECLARE @kguid NCHAR(4)      = '';
    DECLARE @kemai NVARCHAR(48)  = '';
    DECLARE @ktel  NVARCHAR(15)  = '';
    DECLARE @kadre NVARCHAR(200) = '';

    WHILE @wst < @n
    BEGIN
        SET @kimie = (SELECT TOP 1 v FROM @Im ORDER BY NEWID());
        SET @knazw = (SELECT TOP 1 v FROM @Na ORDER BY NEWID());
        SET @kdoma = (SELECT TOP 1 v FROM @Do ORDER BY NEWID());
        SET @kmias = (SELECT TOP 1 v FROM @Mi ORDER BY NEWID());
        SET @kulic = (SELECT TOP 1 v FROM @Ul ORDER BY NEWID());
        SET @kpes  = '900101'+REPLACE(STR(@iter,5),' ','0');
        SET @kguid = LEFT(REPLACE(CAST(NEWID() AS VARCHAR(36)),'-',''),4);
        SET @kemai = LOWER(LEFT(@kimie,6))+'.'+LOWER(LEFT(@knazw,8))+'_'+@kguid+'@'+@kdoma;
        IF LEN(@kemai)>48 SET @kemai=LEFT(@kemai,44)+'@gm.co';
        SET @ktel  = '5'+REPLACE(STR(FLOOR(RAND()*89999999+10000000),8),' ','0');
        SET @kadre = 'ul. '+@kulic+' '+CAST(@iter AS VARCHAR)+', '+@kmias;
        BEGIN TRY
            INSERT INTO klienci(imie,nazwisko,pesel,telefon,email,adres,prywatny)
            VALUES(@kimie,@knazw,@kpes,@ktel,@kemai,@kadre,CAST(ABS(CHECKSUM(NEWID()))%2 AS BIT));
            SET @wst += 1;
        END TRY
        BEGIN CATCH END CATCH
        SET @iter += 1;
        IF @iter > @n*10 BREAK;
    END
    PRINT 'klienci: '+CAST(@wst AS VARCHAR)+' rekordow';
END;
GO
EXEC dbo.Gen_Klienci 200;
GO

-- ============================================================
-- 3. PRACOWNICY
-- ============================================================
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
    INSERT INTO @Na VALUES
        ('Nowak'),('Kowalski'),('Wisniewski'),('Wojcik'),('Kowalczyk'),('Kaminski'),
        ('Lewandowski'),('Zielinski'),('Szymanski'),('Wozniak'),('Dabrowski'),('Kozlowski'),
        ('Mazur'),('Jankowski'),('Kwiatkowski'),('Wojciechowski'),('Krawczyk'),('Kaczmarek'),
        ('Piotrowski'),('Grabowski'),('Pawlowski'),('Michalski'),('Jablonski'),('Wrobel');

    DECLARE @St TABLE (v NVARCHAR(50));
    INSERT INTO @St VALUES ('Serwisant'),('Obsluga klienta'),('Kierownik'),('Sprzedawca'),
                           ('Logistyk'),('Mechanik'),('Recepcjonista'),('Koordynator floty');

    DECLARE @pi    INT          = 1;
    DECLARE @pimie NVARCHAR(20) = '';
    DECLARE @pplec CHAR(1)      = 'M';
    DECLARE @pnazw NVARCHAR(20) = '';
    DECLARE @pstan NVARCHAR(50) = '';
    DECLARE @ptel  NVARCHAR(15) = '';
    DECLARE @pemai NVARCHAR(50) = '';

    WHILE @pi <= @n
    BEGIN
        SELECT TOP 1 @pimie=v, @pplec=plec FROM @Im ORDER BY NEWID();
        SET @pnazw = (SELECT TOP 1 v FROM @Na ORDER BY NEWID());
        IF @pplec='K'
        BEGIN
            IF   @pnazw LIKE '%ski'  SET @pnazw=LEFT(@pnazw,LEN(@pnazw)-3)+'ska';
            ELSE IF @pnazw LIKE '%cki'  SET @pnazw=LEFT(@pnazw,LEN(@pnazw)-3)+'cka';
            ELSE IF @pnazw LIKE '%dzki' SET @pnazw=LEFT(@pnazw,LEN(@pnazw)-4)+'dzka';
        END
        SET @pstan = (SELECT TOP 1 v FROM @St ORDER BY NEWID());
        SET @ptel  = CAST(FLOOR(RAND()*900+100) AS VARCHAR(3))+'-'
                    +CAST(FLOOR(RAND()*900+100) AS VARCHAR(3))+'-'
                    +CAST(FLOOR(RAND()*900+100) AS VARCHAR(3));
        SET @pemai = LOWER(LEFT(@pimie,8))+'.'+LOWER(LEFT(@pnazw,10))
                    +CAST(@pi AS VARCHAR(4))+'@firma.pl';
        INSERT INTO pracownicy(imie,nazwisko,telefon,email,stanowisko)
        VALUES(@pimie,@pnazw,@ptel,@pemai,@pstan);
        SET @pi += 1;
    END
    PRINT 'pracownicy: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO
EXEC dbo.Gen_Pracownicy 50;
GO

-- ============================================================
-- 4. WYPOZYCZENIA
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.Gen_Wypozyczenia @n INT AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS(SELECT 1 FROM klienci)    RAISERROR('klienci sa puste!',16,1);
    IF NOT EXISTS(SELECT 1 FROM pojazdy)    RAISERROR('pojazdy sa puste!',16,1);
    IF NOT EXISTS(SELECT 1 FROM pracownicy) RAISERROR('pracownicy sa pusti!',16,1);

    DECLARE @wi  INT           = 0;
    DECLARE @dw  DATE          = NULL;
    DECLARE @dp  DATE          = NULL;
    DECLARE @dr  DATE          = NULL;
    DECLARE @pid INT           = 0;
    DECLARE @kid INT           = 0;
    DECLARE @rid INT           = 0;
    DECLARE @ce  DECIMAL(10,2) = 0;
    DECLARE @dn  INT           = 0;
    DECLARE @kw  DECIMAL(10,2) = 0;

    WHILE @wi < @n
    BEGIN
        SET @dw = DATEADD(DAY,-(ABS(CHECKSUM(NEWID()))%365),GETDATE());
        SET @dp = DATEADD(DAY,ABS(CHECKSUM(NEWID()))%14+2,@dw);
        SET @dr = NULL;
        IF ABS(CHECKSUM(NEWID()))%100 < 75
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
        SET @wi += 1;
    END
    PRINT 'wypozyczenia: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO
EXEC dbo.Gen_Wypozyczenia 400;
GO

-- ============================================================
-- 5. REZERWACJE
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.Gen_Rezerwacje @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Ss TABLE (s NVARCHAR(20));
    INSERT INTO @Ss VALUES ('oczekuje'),('potwierdzona'),('anulowana');

    DECLARE @ri  INT          = 1;
    DECLARE @rki INT          = 0;
    DECLARE @rpi INT          = 0;
    DECLARE @rod DATE         = NULL;
    DECLARE @rdo DATE         = NULL;
    DECLARE @rst NVARCHAR(20) = '';

    WHILE @ri <= @n
    BEGIN
        SET @rki=(SELECT TOP 1 klient_id FROM klienci ORDER BY NEWID());
        SET @rpi=(SELECT TOP 1 pojazd_id FROM pojazdy  ORDER BY NEWID());
        SET @rod=DATEADD(DAY,ABS(CHECKSUM(NEWID()))%90,GETDATE());
        SET @rdo=DATEADD(DAY,ABS(CHECKSUM(NEWID()))%21+1,@rod);
        SET @rst=(SELECT TOP 1 s FROM @Ss ORDER BY NEWID());
        INSERT INTO rezerwacje(klient_id,pojazd_id,data_utworzenia,data_od,data_do,[status])
        VALUES(@rki,@rpi,GETDATE(),@rod,@rdo,@rst);
        SET @ri += 1;
    END
    PRINT 'rezerwacje: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO
EXEC dbo.Gen_Rezerwacje 100;
GO

-- ============================================================
-- 6. PLATNOSCI
-- ============================================================
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
    PRINT 'platnosci: wstawiono dla zalegajacych wypozyczen';
END;
GO
EXEC dbo.Gen_Platnosci;
GO

-- ============================================================
-- 7. USZKODZENIA
-- ============================================================
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

    DECLARE @ui  INT  = 1;
    DECLARE @uid INT  = 0;
    DECLARE @udw DATE = NULL;

    WHILE @ui <= @n
    BEGIN
        SELECT TOP 1 @uid=wypozyczenie_id, @udw=dataWypozyczenia FROM wypozyczenia ORDER BY NEWID();
        INSERT INTO uszkodzenia(opis,koszt,data_zgloszenia,wypozyczenie_id)
        SELECT TOP 1 v,
            CAST(ABS(CHECKSUM(NEWID()))%4800+200 AS DECIMAL(10,2)),
            DATEADD(DAY,ABS(CHECKSUM(NEWID()))%10,@udw),
            @uid
        FROM @Op ORDER BY NEWID();
        SET @ui += 1;
    END
    PRINT 'uszkodzenia: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO
EXEC dbo.Gen_Uszkodzenia 50;
GO

-- ============================================================
-- 8. PREMIE PRACOWNIKOW
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.Gen_Premie @n INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Op TABLE (id INT IDENTITY(1,1), v NVARCHAR(100));
    INSERT INTO @Op VALUES ('Premia uznaniowa'),('Wysoka efektywnosc sprzedazy'),
        ('Premia swiateczna'),('Realizacja planu kwartalnego'),
        ('Nagroda za pozyskanie klienta korporacyjnego'),
        ('Premia roczna'),('Wyroznienie miesiaca'),('Premia za nadgodziny');

    DECLARE @prei  INT  = 1;
    DECLARE @prepid INT = 0;
    DECLARE @premi DATE = NULL;

    WHILE @prei <= @n
    BEGIN
        SET @prepid=(SELECT TOP 1 pracownik_id FROM pracownicy ORDER BY NEWID());
        SET @premi=DATEFROMPARTS(2022+CAST(RAND()*3 AS INT),CAST(RAND()*12+1 AS INT),1);
        INSERT INTO premiePracownikow(miesiac,kwota,opis,pracownik_id)
        SELECT TOP 1 @premi,CAST(RAND()*3000+300 AS DECIMAL(7,2)),v,@prepid
        FROM @Op ORDER BY NEWID();
        SET @prei += 1;
    END
    PRINT 'premiePracownikow: '+CAST(@n AS VARCHAR)+' rekordow';
END;
GO
EXEC dbo.Gen_Premie 150;
GO

-- ============================================================
-- 9. UBEZPIECZENIA
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.Gen_Ubezpieczenia AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ubwid INT = 0;
    DECLARE @ubt   INT = 0;
    DECLARE cur CURSOR FAST_FORWARD FOR
        SELECT w.wypozyczenie_id FROM wypozyczenia w
        WHERE NOT EXISTS(SELECT 1 FROM Ubezpieczenie_wypozyczenia u WHERE u.wypozyczenie_id=w.wypozyczenie_id);
    OPEN cur;
    FETCH NEXT FROM cur INTO @ubwid;
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
    PRINT 'Ubezpieczenie_wypozyczenia: przypisano do wszystkich wypozyczen';
END;
GO
EXEC dbo.Gen_Ubezpieczenia;
GO

-- ============================================================
-- PODSUMOWANIE
-- ============================================================
SELECT 'pojazdy'                    AS tabela, COUNT(*) AS rekordy FROM pojazdy                    UNION ALL
SELECT 'klienci',                              COUNT(*)            FROM klienci                    UNION ALL
SELECT 'pracownicy',                           COUNT(*)            FROM pracownicy                 UNION ALL
SELECT 'wypozyczenia',                         COUNT(*)            FROM wypozyczenia               UNION ALL
SELECT 'rezerwacje',                           COUNT(*)            FROM rezerwacje                 UNION ALL
SELECT 'platnosci',                            COUNT(*)            FROM platnosci                  UNION ALL
SELECT 'uszkodzenia',                          COUNT(*)            FROM uszkodzenia                UNION ALL
SELECT 'premiePracownikow',                    COUNT(*)            FROM premiePracownikow          UNION ALL
SELECT 'Ubezpieczenie_wypozyczenia',           COUNT(*)            FROM Ubezpieczenie_wypozyczenia;