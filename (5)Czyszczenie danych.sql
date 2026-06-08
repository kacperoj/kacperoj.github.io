-- ============================================================
--  CZYSZCZENIE WSZYSTKICH TABEL - Wypozyczalnia Samochodow
--  Uzywa DELETE (dziala zawsze, niezaleznie od FK)
--  Kolejnosc: dzieci przed rodzicami
-- ============================================================
USE ProjektWypo;
GO
	
DELETE FROM Ubezpieczenie_wypozyczenia;
DELETE FROM premiePracownikow;
DELETE FROM uszkodzenia;
DELETE FROM platnosci;
DELETE FROM rezerwacje;
DELETE FROM wypozyczenia;
DELETE FROM pracownicy;
DELETE FROM klienci;
DELETE FROM pojazdy;

-- Reset licznikow IDENTITY we wszystkich tabelach
DBCC CHECKIDENT ('Ubezpieczenie_wypozyczenia', RESEED, 0);
DBCC CHECKIDENT ('premiePracownikow',          RESEED, 0);
DBCC CHECKIDENT ('uszkodzenia',                RESEED, 0);
DBCC CHECKIDENT ('platnosci',                  RESEED, 0);
DBCC CHECKIDENT ('rezerwacje',                 RESEED, 0);
DBCC CHECKIDENT ('wypozyczenia',               RESEED, 0);
DBCC CHECKIDENT ('pracownicy',                 RESEED, 0);
DBCC CHECKIDENT ('klienci',                    RESEED, 0);
DBCC CHECKIDENT ('pojazdy',                    RESEED, 0);

-- Podsumowanie - wszystkie tabele powinny miec 0 rekordow
SELECT 'pojazdy'                    AS tabela, COUNT(*) AS rekordy FROM pojazdy                    UNION ALL
SELECT 'klienci',                              COUNT(*)            FROM klienci                    UNION ALL
SELECT 'pracownicy',                           COUNT(*)            FROM pracownicy                 UNION ALL
SELECT 'wypozyczenia',                         COUNT(*)            FROM wypozyczenia               UNION ALL
SELECT 'rezerwacje',                           COUNT(*)            FROM rezerwacje                 UNION ALL
SELECT 'platnosci',                            COUNT(*)            FROM platnosci                  UNION ALL
SELECT 'uszkodzenia',                          COUNT(*)            FROM uszkodzenia                UNION ALL
SELECT 'premiePracownikow',                    COUNT(*)            FROM premiePracownikow          UNION ALL
SELECT 'Ubezpieczenie_wypozyczenia',           COUNT(*)            FROM Ubezpieczenie_wypozyczenia;

PRINT 'Czyszczenie zakonczone. Mozna uruchomic skrypt generatora.';

