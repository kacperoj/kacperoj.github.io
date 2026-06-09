CREATE Database ProjektWypo

CREATE TABLE pojazdy (
pojazd_id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
nrRejestr nvarchar(15) NOT NULL UNIQUE,
nrVIN nchar(17) NOT NULL UNIQUE,
marka nvarchar(40) NOT NULL,
model nvarchar(40) NOT NULL,
rokProdukcji int CHECK(rokProdukcji BETWEEN 1950 AND YEAR(GETDATE())),
[status] NVARCHAR(20) NOT NULL CHECK (status IN ('dostepny', 'wypozyczony', 'zarezerwowany', 'serwis')) DEFAULT 'dostepny',
data_dodania date DEFAULT GETDATE(),
typNadwozia nvarchar(30),
przebieg bigint DEFAULT 0 CHECK(przebieg >= 0),
cenaZaDzien decimal(10,2) NOT NULL CHECK(cenaZaDzien >=0) 
)

CREATE TABLE klienci(
klient_id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
imie nvarchar(40) NOT NULL,
nazwisko nvarchar(40) NOT NULL,
pesel nchar(11) NOT NULL UNIQUE,
telefon nvarchar(15) NOT NULL,
email NVARCHAR(50) UNIQUE,
adres nvarchar(200) NOT NULL,
prywatny BIT NOT NULL
)

CREATE TABLE pracownicy(
pracownik_id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
imie nvarchar(40) NOT NULL,
nazwisko nvarchar(40) NOT NULL,
telefon nvarchar(15) NOT NULL,
email nvarchar(50),
stanowisko nvarchar(50) NOT NULL
)


CREATE TABLE wypozyczenia(
wypozyczenie_id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
dataWypozyczenia date NOT NULL,
dataPlanowanegoZwrotu date NOT NULL,
dataRzeczywistegoZwrotu date NULL,
kwotaCalkowita decimal(10,2) DEFAULT 0 CHECK(kwotaCalkowita >= 0),
klient_id int NOT NULL FOREIGN KEY REFERENCES klienci(klient_id),
pojazd_id int NOT NULL FOREIGN KEY REFERENCES pojazdy(pojazd_id),
pracownik_id int NULL FOREIGN KEY REFERENCES pracownicy(pracownik_id),
CONSTRAINT chk_wypozyczenia_rzeczywisty CHECK (dataRzeczywistegoZwrotu IS NULL OR dataRzeczywistegoZwrotu >= dataWypozyczenia)
)

CREATE TABLE platnosci (
platnosc_id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
kwota decimal(10,2) NOT NULL check(kwota >= 0),
dataPlatnosci datetime2 DEFAULT SYSDATETIME(),
metodaPlatnosci nvarchar(30) NOT NULL CHECK (metodaPlatnosci IN ('gotowka','karta','przelew','blik')),
wypozyczenie_id int NOT NULL FOREIGN KEY REFERENCES wypozyczenia(wypozyczenie_id)
)

CREATE TABLE uszkodzenia (
uszkodzenie_id int IDENTITY(1,1) PRIMARY KEY,
opis nvarchar(500) NOT NULL,
koszt DECIMAL(10,2) NOT NULL CHECK (koszt >= 0),
data_zgloszenia date DEFAULT GETDATE(),
wypozyczenie_id int NOT NULL FOREIGN KEY REFERENCES wypozyczenia(wypozyczenie_id)
)

CREATE TABLE premiePracownikow(
premia_id int IDENTITY(1,1) PRIMARY KEY,
miesiac DATE NOT NULL,
kwota DECIMAL(7,2) NOT NULL check(kwota >= 0),
opis nvarchar(200),
pracownik_id int NOT NULL FOREIGN KEY REFERENCES pracownicy(pracownik_id)
)

CREATE TABLE rezerwacje (
    rezerwacja_id INT IDENTITY(1,1) PRIMARY KEY,
    klient_id int NOT NULL FOREIGN KEY REFERENCES klienci(klient_id),
    pojazd_id int NOT NULL FOREIGN KEY REFERENCES pojazdy(pojazd_id),
	data_utworzenia DATE DEFAULT GETDATE(),
    data_od DATE NOT NULL,
    data_do DATE NOT NULL,
    [status] NVARCHAR(20) DEFAULT 'oczekuje' CHECK (status IN ('oczekuje', 'potwierdzona', 'anulowana')),   
	CONSTRAINT chk_rezerwacje_daty CHECK (data_do >= data_od)
)

CREATE TABLE Ubezpieczenie_wypozyczenia (
    ubezpieczenie_id INT IDENTITY(1,1) PRIMARY KEY,
    wypozyczenie_id INT NOT NULL FOREIGN KEY REFERENCES wypozyczenia(wypozyczenie_id),
    typ_ubezpieczenia VARCHAR(100) NOT NULL,
    koszt DECIMAL(10,2) NOT NULL,
    suma_gwarancyjna DECIMAL(12,2) NOT NULL,
    warunki NVARCHAR(2000),
)