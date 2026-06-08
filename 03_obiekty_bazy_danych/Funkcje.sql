CREATE FUNCTION dbo.AktywneWypozyczenia()
RETURNS TABLE
AS
RETURN
(
    SELECT
        w.wypozyczenie_id,
        k.imie,
        k.nazwisko,
        p.marka,
        p.model,
        w.dataWypozyczenia,
        w.dataPlanowanegoZwrotu
    FROM wypozyczenia w
    JOIN klienci k ON w.klient_id = k.klient_id
    JOIN pojazdy p ON w.pojazd_id = p.pojazd_id
    WHERE w.dataRzeczywistegoZwrotu IS NULL
)


CREATE FUNCTION dbo.LiczbaDniWypozyczenia
(
    @dataOd DATE,
    @dataDo DATE
)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(DAY, @dataOd, @dataDo) + 1
END



CREATE FUNCTION dbo.KosztWypozyczenia
(
    @pojazd_id INT,
    @dataOd DATE,
    @dataDo DATE
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @cenaZaDzien DECIMAL(10,2)

    SELECT @cenaZaDzien = cenaZaDzien
    FROM pojazdy
    WHERE pojazd_id = @pojazd_id

    RETURN @cenaZaDzien * (DATEDIFF(DAY, @dataOd, @dataDo) + 1)
END



CREATE FUNCTION dbo.CzyStalyKlient
(
    @klient_id INT
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @liczba INT

    SELECT @liczba = COUNT(*)
    FROM wypozyczenia
    WHERE klient_id = @klient_id

    IF @liczba >= 5
        RETURN 'Stały klient'

    RETURN 'Niestały klient'
END


CREATE FUNCTION dbo.ObliczKareZaSpoznienie
(
    @dataPlanowanegoZwrotu DATE,
    @dataRzeczywistegoZwrotu DATE,
    @karaZaDzien DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @dni INT

    SET @dni = DATEDIFF(DAY,
                        @dataPlanowanegoZwrotu,
                        @dataRzeczywistegoZwrotu)

    IF @dni <= 0
        RETURN 0

    RETURN @dni * @karaZaDzien
END 


CREATE FUNCTION dbo.WartoscKlienta
(
    @klient_id INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @suma DECIMAL(12,2)

    SELECT @suma = ISNULL(SUM(kwotaCalkowita),0)
    FROM wypozyczenia
    WHERE klient_id = @klient_id

    RETURN @suma
END