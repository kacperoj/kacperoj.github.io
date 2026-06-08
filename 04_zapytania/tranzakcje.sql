----P1-----
BEGIN TRAN;
-- Dodanie głównego wpisu o rezerwacji
INSERT INTO rezerwacje (klient_id, pojazd_id, data_od, data_do, status)
VALUES (11, 1, GETDATE(), DATEADD(day, 3, GETDATE()), 'oczekuje');

SAVE TRAN PunktRezerwacji;

-- Próba dodania "wewnętrznej" operacji (np. dodatkowa notatka/log)
BEGIN TRAN;
INSERT INTO uszkodzenia (opis, koszt, wypozyczenie_id)
VALUES ('Dodatkowa kontrola techniczna przed rezerwacją', 0, 1);

-- Decyzja o wycofaniu tylko tej notatki
ROLLBACK TRAN PunktRezerwacji;

COMMIT;
PRINT 'Transakcja zakończona, notatka o kontroli wycofana.';

----P2-----
BEGIN TRY
    BEGIN TRAN;
    INSERT INTO wypozyczenia (dataWypozyczenia, dataPlanowanegoZwrotu, klient_id, pojazd_id)
    VALUES (GETDATE(), DATEADD(day, 7, GETDATE()), 11, 99999); -- 99999 nie istnieje
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    PRINT 'Wystąpił błąd: ' + ERROR_MESSAGE();
END CATCH;

----P3-----
BEGIN TRAN;
-- Blokujemy pojazd przed edycją
SELECT * FROM pojazdy WITH (XLOCK, ROWLOCK) WHERE pojazd_id = 1;
-- Czekaj...
COMMIT;

-- To zapytanie będzie czekać, aż Okno 1 wykona COMMIT
UPDATE pojazdy SET status = 'serwis' WHERE pojazd_id = 1;



--cofnięcie tranzakcji


BEGIN TRY
    BEGIN TRAN;

    -- 1. Dodanie nowego klienta
    INSERT INTO klienci (imie, nazwisko, pesel, telefon, adres, prywatny)
    VALUES ('Tomasz', 'Zalewski', '99999999999', '999-999-999', 'Warszawa', 1);
    DECLARE @NowyKlientID INT = SCOPE_IDENTITY();

    -- 2. Dodanie nowego pracownika
    INSERT INTO pracownicy (imie, nazwisko, telefon, stanowisko)
    VALUES ('Piotr', 'Obsluga', '888-888-888', 'Doradca');
    DECLARE @NowyPracownikID INT = SCOPE_IDENTITY();

    -- 3. Zarejestrowanie wypożyczenia dla tego klienta (wymaga istnienia rekordu w pojazdy z pojazd_id = 1)
    INSERT INTO wypozyczenia (dataWypozyczenia, dataPlanowanegoZwrotu, klient_id, pojazd_id, pracownik_id)
    VALUES (GETDATE(), DATEADD(DAY, 5, GETDATE()), @NowyKlientID, 1, @NowyPracownikID);

    -- 4. Symulacja błędu krytycznego (dzielenie przez zero)
    DECLARE @Zero INT = 0;
    DECLARE @Test INT = 1 / @Zero;

    -- Ten fragment nigdy się nie wykona
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK;

    PRINT 'Błąd: ' + ERROR_MESSAGE();
    PRINT 'Transakcja wycofana - klient, pracownik i wypożyczenie nie zostali dodani.';
END CATCH;

-- Weryfikacja (nie powinno zwrócić żadnych wyników)
SELECT * FROM klienci WHERE pesel = '99999999999';






GO 

CREATE OR ALTER PROCEDURE dbo.DodajPojazdTestowy
    @akcja VARCHAR(10)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO pojazdy (nrRejestr, nrVIN, marka, model, rokProdukcji, cenaZaDzien)
        VALUES ('TEST001', 'VINTEST0000000001', 'MarkaTest', 'ModelTest', 2023, 150.00);

        IF UPPER(@akcja) = 'COMMIT'
        BEGIN
            COMMIT;
            PRINT 'Zmiany zatwierdzone.';
        END
        ELSE
        BEGIN
            ROLLBACK;
            PRINT 'Zmiany wycofane.';
        END
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        PRINT 'Błąd: ' + ERROR_MESSAGE();
    END CATCH;
END;
GO -- <--- TO GO JEST RÓWNIEŻ POTRZEBNE (oddziela procedurę od jej wywołań)

-- Wywołania testowe:
EXEC dbo.DodajPojazdTestowy @akcja = 'COMMIT';
EXEC dbo.DodajPojazdTestowy @akcja = 'ROLLBACK';


GO

-- Deklarujemy zmienne pomocnicze dla czytelności skryptu
DECLARE @IdPojazdu INT = 1;      -- ID pojazdu, który wypożyczamy
DECLARE @IdKlienta INT = 1;      -- ID klienta, który wypożycza
DECLARE @IdPracownika INT = 1;   -- ID pracownika, który wydaje auto
DECLARE @CenaZaDzien DECIMAL(10,2);
DECLARE @IloscDni INT = 5;       -- Planowany okres wypożyczenia
DECLARE @KwotaCalkowita DECIMAL(10,2);

-- Pobieramy aktualną cenę za dzień dla wybranego pojazdu
SELECT @CenaZaDzien = cenaZaDzien FROM pojazdy WHERE pojazd_id = @IdPojazdu;
SET @KwotaCalkowita = @CenaZaDzien * @IloscDni;


BEGIN TRY
    -- Rozpoczynamy transakcję bezpiecznego "wysłania" auta w trasę
    BEGIN TRAN;

    -- KROK 1: Rejestrujemy wypożyczenie w systemie
    INSERT INTO wypozyczenia (
        dataWypozyczenia, 
        dataPlanowanegoZwrotu, 
        dataRzeczywistegoZwrotu, 
        kwotaCalkowita, 
        klient_id, 
        pojazd_id, 
        pracownik_id
    )
    VALUES (
        GETDATE(),                           -- dataWypozyczenia (dzisiaj)
        DATEADD(DAY, @IloscDni, GETDATE()),  -- dataPlanowanegoZwrotu
        NULL,                                -- brak rzeczywistego zwrotu w momencie wydania
        @KwotaCalkowita, 
        @IdKlienta, 
        @IdPojazdu, 
        @IdPracownika
    );

    -- KROK 2: Aktualizujemy status pojazdu, żeby nikt inny go nie wypożyczył
    UPDATE pojazdy
    SET status = 'wypozyczony'
    WHERE pojazd_id = @IdPojazdu;

    -- Jeśli oba kroki wykonały się poprawnie, trwale zapisujemy zmiany
    COMMIT TRAN;
    PRINT 'Transakcja zakończona sukcesem. Pojazd został pomyślnie wypożyczony.';

END TRY
BEGIN CATCH
    -- W przypadku jakiegokolwiek błędu (np. brak pojazdu o ID 1), cofamy wszystkie zmiany
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRAN;
        PRINT 'Wystąpił błąd! Transakcja została w całości wycofana.';
    END
    
    -- Wyświetlamy szczegóły błędu
    PRINT 'Treść błędu: ' + ERROR_MESSAGE();
END CATCH;

GO

-- Weryfikacja: Sprawdźmy, czy status pojazdu się zmienił oraz czy doszło wypożyczenie
SELECT pojazd_id, marka, model, status FROM pojazdy WHERE pojazd_id = 1;
SELECT TOP 1 * FROM wypozyczenia ORDER BY wypozyczenie_id DESC;