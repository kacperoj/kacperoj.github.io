
---
title: Projekt Wypożyczalnia Samochodów
---

# 🚗 ProjektWypozyczalnia2

Projekt bazy danych dla systemu wypożyczalni samochodów, zrealizowany w ramach przedmiotu **Programowanie Serwerów Baz Danych**.

| | |
|---|---|
| **Baza danych** | Microsoft SQL Server |
| **Narzędzie** | SSMS (SQL Server Management Studio) |
| **Autorzy** | Kacper [nick] · Tymon Korpiela |

---

## 📋 Spis treści

- [Opis projektu](#opis-projektu)
- [Diagram ERD](#diagram-erd)
- [Architectural Overview](#architectural-overview)
- [Struktura bazy danych](#struktura-bazy-danych)
- [Generowanie danych](#generowanie-danych)
- [Triggery](#triggery)
- [Transakcje](#transakcje)
- [Zapytania zaawansowane](#zapytania-zaawansowane)
- [Funkcje okna](#funkcje-okna)
- [Raportowanie XML i JSON](#raportowanie-xml-i-json)
- [Uruchomienie projektu](#uruchomienie-projektu)

---

## Opis projektu

System obsługuje pełen cykl życia wypożyczenia samochodu — od rejestracji pojazdu i klienta, przez rezerwacje i wypożyczenia, aż po płatności, ubezpieczenia i rozliczenie szkód. Baza zawiera mechanizmy audytu, archiwizacji i automatycznej zmiany statusów pojazdów.

### Tabele

| Tabela | Opis |
|--------|------|
| `pojazdy` | Flota pojazdów z danymi technicznymi i cennikiem |
| `klienci` | Dane klientów indywidualnych i firmowych |
| `pracownicy` | Personel obsługujący wypożyczenia |
| `wypozyczenia` | Rejestr wszystkich wypożyczeń |
| `rezerwacje` | Rezerwacje pojazdów z wyprzedzeniem |
| `platnosci` | Płatności powiązane z wypożyczeniami |
| `uszkodzenia` | Zgłoszone uszkodzenia pojazdów |
| `premiePracownikow` | Historia premii pracowniczych |
| `Ubezpieczenie_wypozyczenia` | Polisy ubezpieczeniowe do wypożyczeń |

---

## Diagram ERD

<!-- Wklej tutaj obrazek diagramu ERD -->
<!-- Przykład: ![Diagram ERD](docs/erd.png) -->

> ![Diagram ERD](images/Diagram%20erd.drawio.png)

---

## Architectural Overview

<!-- Wklej tutaj obrazek Architectural Overview Diagram -->
<!-- Przykład: ![Architectural Overview](docs/architecture.png) -->

> 📌 ![Diagram przypdaków użycia](images/UseCase1%201.jpg)

---

## Struktura bazy danych

Plik: [`01_struktura/create_tables.sql`](01_struktura/create_tables.sql)

Skrypt tworzy bazę danych `ProjektWypozyczalnia2` oraz wszystkie tabele z:
- kluczami głównymi (`IDENTITY`) i obcymi (`FOREIGN KEY`)
- ograniczeniami `CHECK` na statusy pojazdów, rezerwacji i metody płatności
- wartościami domyślnymi (`DEFAULT GETDATE()`, `DEFAULT 'dostepny'`)

---

## Generowanie danych

Pliki: [`02_dane/GenerujDaneProjekt_FINAL.sql`](02_dane/GenerujDaneProjekt_FINAL.sql) · [`02_dane/CzyszczenieBazy.sql`](02_dane/CzyszczenieBazy.sql)

Jeden skrypt generuje dane do wszystkich tabel w kolejności zgodnej z kluczami obcymi:

| Procedura | Tabela | Liczba rekordów |
|-----------|--------|-----------------|
| `Gen_Pojazdy` | `pojazdy` | 300 |
| `Gen_Klienci` | `klienci` | 200 |
| `Gen_Pracownicy` | `pracownicy` | 50 |
| `Gen_Wypozyczenia` | `wypozyczenia` | 400 |
| `Gen_Rezerwacje` | `rezerwacje` | 100 |
| `Gen_Platnosci` | `platnosci` | ~400 |
| `Gen_Uszkodzenia` | `uszkodzenia` | 50 |
| `Gen_Premie` | `premiePracownikow` | 150 |
| `Gen_Ubezpieczenia` | `Ubezpieczenie_wypozyczenia` | ~400 |

Skrypt `CzyszczenieBazy.sql` usuwa wszystkie rekordy i resetuje liczniki `IDENTITY`.

---

## Triggery

Plik: [`03_triggery/Triggery.sql`](03_triggery/Triggery.sql)

Zaimplementowano 12 triggerów w 4 kategoriach:

### Audyt zmian danych

| Trigger | Tabela | Zdarzenie | Opis |
|---------|--------|-----------|------|
| `trg_KlientDaneAudit` | `klienci` | `AFTER UPDATE` | Rejestruje zmienione kolumny (imię, nazwisko, PESEL, email) w tabeli `KlientAudit` |
| `trg_PracownikAudit` | `pracownicy` | `AFTER UPDATE` | Analogiczny audyt dla danych pracownika |
| `trg_DDL_DropTable_Audit` | DATABASE | `AFTER DROP_TABLE` | Loguje każdą operację `DROP TABLE` z pełnym kontekstem zdarzenia (`EVENTDATA()`) |

### Ochrona integralności danych

| Trigger | Tabela | Zdarzenie | Opis |
|---------|--------|-----------|------|
| `trg_BlockVINChange` | `pojazdy` | `AFTER UPDATE` | Blokuje zmianę numeru VIN zarejestrowanego pojazdu |
| `trg_PojazdPrzebiegKorekta` | `pojazdy` | `AFTER UPDATE` | Przywraca przebieg jeśli nowa wartość jest niższa od poprzedniej — ochrona przed cofaniem licznika |
| `trg_loguj_zmiane_ceny` | `pojazdy` | `AFTER UPDATE` | Zapisuje historię zmian ceny za dobę w tabeli `historia_cen_pojazdow` |

### Walidacja przed zapisem (INSTEAD OF)

| Trigger | Tabela | Zdarzenie | Opis |
|---------|--------|-----------|------|
| `trg_PojazdInsertValidation` | `pojazdy` | `INSTEAD OF INSERT` | Odrzuca pojazdy starsze niż rok 2000 zanim trafią do tabeli |
| `trg_PlatnoscComplexControl` | `platnosci` | `INSTEAD OF INSERT` | Waliduje kwotę (> 0) i istnienie powiązanego wypożyczenia |

### Automatyczna zmiana statusów

| Trigger | Tabela | Zdarzenie | Opis |
|---------|--------|-----------|------|
| `trg_rezerwacja_status_pojazdu` | `rezerwacje` | `AFTER INSERT, UPDATE` | Ustawia status pojazdu na `zarezerwowany` przy potwierdzeniu rezerwacji, wraca do `dostepny` przy anulowaniu |
| `trg_Wypozyczenie_Zwrot_StatusPojazdu` | `wypozyczenia` | `AFTER UPDATE` | Automatycznie zmienia status pojazdu na `dostepny` po wpisaniu daty rzeczywistego zwrotu |

### Archiwizacja usuniętych rekordów

| Trigger | Tabela | Zdarzenie | Opis |
|---------|--------|-----------|------|
| `trg_Pojazdy_Archive_Delete` | `pojazdy` | `AFTER DELETE` | Przenosi usunięty pojazd do tabeli `ArchiwumPojazdy` |
| `trg_Klienci_Archive_Delete` | `klienci` | `AFTER DELETE` | Przenosi usuniętego klienta do tabeli `ArchiwumKlienci` |

---

## Transakcje

Plik: [`04_transakcje/Transakcje.sql`](04_transakcje/Transakcje.sql)

*Autor: Tymon Korpiela*

Zaimplementowano kilka scenariuszy transakcyjnych demonstrujących mechanizmy kontroli spójności danych:

### Punkty zapisu (SAVE TRAN)
Rezerwacja z możliwością częściowego wycofania — główna rezerwacja zostaje, wewnętrzna notatka jest wycofana bez wpływu na zewnętrzną transakcję.

### Obsługa błędów (TRY/CATCH + XACT_STATE)
Próba dodania wypożyczenia dla nieistniejącego pojazdu — `XACT_STATE()` sprawdza stan transakcji przed `ROLLBACK`, zapobiegając błędom przy zagnieżdżonych transakcjach.

### Blokady wierszy (XLOCK, ROWLOCK)
Demonstracja blokowania wiersza pojazdu podczas edycji — drugie zapytanie czeka na `COMMIT` pierwszej sesji.

### Transakcja biznesowa — wypożyczenie pojazdu
Atomowa operacja łącząca dwa kroki:
1. Rejestracja wypożyczenia w tabeli `wypozyczenia`
2. Zmiana statusu pojazdu na `wypozyczony`

Oba kroki są zatwierdzane razem lub razem wycofywane — brak możliwości niespójnego stanu.

### Procedura z parametrem akcji
```sql
EXEC dbo.DodajPojazdTestowy @akcja = 'COMMIT';   -- zatwierdza
EXEC dbo.DodajPojazdTestowy @akcja = 'ROLLBACK'; -- wycofuje
```

---

## Zapytania zaawansowane

Plik: [`05_zapytania/ZaawansowaneZapytania.sql`](05_zapytania/ZaawansowaneZapytania.sql)

15 zapytań w 3 kategoriach:

### Agregacje (GROUP BY, ROLLUP, GROUPING SETS)
- Liczba wypożyczeń i przychód na pracownika
- Wartość ubezpieczeń wg typu nadwozia z sumami częściowymi (`ROLLUP`)
- Przychód miesięczny i roczny
- Najbardziej dochodowe marki (`HAVING`)
- Sezonowość wg kwartału i dnia tygodnia

### CTE (Common Table Expressions)
- TOP 3 klientów wg przychodu w każdym miesiącu (dwupoziomowe CTE + `DENSE_RANK`)
- Pojazdy które nigdy nie były wypożyczone (antyjoin)
- Historia kolejnych wypożyczeń pojazdu z numeracją (`ROW_NUMBER`)

### Raporty operacyjne
- Wypożyczenia przeterminowane z danymi kontaktowymi klientów
- Ryzykowni klienci — procent wypożyczeń zakończonych szkodą
- Analiza metod płatności i czasu do zapłaty
- Pojazdy wymagające serwisu z rekomendacją (`CASE`)
- Klienci nieaktywni bez żadnych wypożyczeń ani rezerwacji (`NOT EXISTS`)

---

## Funkcje okna

Plik: [`05_zapytania/FunkcjeOkna.sql`](05_zapytania/FunkcjeOkna.sql)

14 zapytań w 4 kategoriach:

### Funkcje rankingowe
- `RANK()` i `DENSE_RANK()` — ranking klientów wg wydatków z porównaniem obu funkcji
- `ROW_NUMBER()` — numerowanie wypożyczeń klienta chronologicznie
- `NTILE(4)` — podział pojazdów i wypożyczeń na 4 grupy cenowe z etykietami

### Funkcje przesunięcia
- `LAG()` — odstęp między kolejnymi wypożyczeniami klienta
- `LEAD()` — porównanie bieżącego wypożyczenia z następnym
- `FIRST_VALUE()` / `LAST_VALUE()` — pierwsze i ostatnie wypożyczenie klienta

### Funkcje agregujące w oknie
- Narastający przychód miesięczny (running total) z `ROWS UNBOUNDED PRECEDING`
- Średnia krocząca ceny za dobę po 3 wypożyczeniach (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`)
- Udział procentowy pracownika w przychodzie całkowitym (`SUM(SUM(...)) OVER ()`)
- Średni przebieg wg typu nadwozia z odchyleniem każdego pojazdu od średniej grupy

### Funkcje dystrybucji
- `CUME_DIST()` i `PERCENT_RANK()` — pozycja kwoty wypożyczenia w rozkładzie klienta
- `NTILE(4)` + `PERCENT_RANK()` — percentyl cenowy pojazdu w obrębie marki

---

## Raportowanie XML i JSON

Plik: [`06_raporty/RaportyXML_JSON.sql`](06_raporty/RaportyXML_JSON.sql)

*Autor: Tymon Korpiela*

### Raporty XML

| Zapytanie | Opis |
|-----------|------|
| `FOR XML AUTO, ELEMENTS, ROOT` | Automatyczny raport wypożyczeń — SQL Server sam buduje strukturę XML na podstawie nazw tabel i kolumn |
| `FOR XML PATH + podzapytanie TYPE` | Ręcznie zdefiniowana struktura XML z zagnieżdżonymi płatnościami dla każdego wypożyczenia |
| Raport usterek pojazdów | Hierarchiczny XML z listą uszkodzeń i sumą kosztów napraw dla każdego pojazdu |

### Raporty JSON

| Zapytanie | Opis |
|-----------|------|
| `FOR JSON PATH, ROOT` | Eksport danych klientów prywatnych do JSON z weryfikacją przez `ISJSON()` |
| `OPENJSON` + `WITH` | Parsowanie wygenerowanego JSON i filtrowanie danych po stronie T-SQL |
| Profil klienta z historią | Zagnieżdżona struktura JSON łącząca dane klienta z historią wypożyczeń — `CROSS APPLY OPENJSON` |
| Efektywność pracowników | JSON z listą premii pracowniczych, filtrowanie przez `JSON_VALUE` i `JSON_QUERY` |

---

## Uruchomienie projektu

### Wymagania
- Microsoft SQL Server 2019 lub nowszy
- SQL Server Management Studio (SSMS)

### Kolejność wykonania skryptów

```
1. 01_struktura/create_tables.sql       ← tworzy bazę i tabele
2. 02_dane/GenerujDaneProjekt_FINAL.sql ← wypełnia dane (ok. 1500 rekordów)
3. 03_triggery/Triggery.sql             ← tworzy triggery i tabele audytowe
4. 04_transakcje/Transakcje.sql         ← demonstracja transakcji
5. 05_zapytania/ZaawansowaneZapytania.sql
6. 05_zapytania/FunkcjeOkna.sql
7. 06_raporty/RaportyXML_JSON.sql
```

> ⚠️ Skrypt generatora danych uruchamiaj tylko raz. Jeśli chcesz zacząć od zera, najpierw wykonaj `02_dane/CzyszczenieBazy.sql`.
