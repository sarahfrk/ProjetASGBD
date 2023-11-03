/*
						FERKOUS                     
						SARAH                       
						191931043867                
						G2
						M1_SII_BDA_2023
*/

--*********************************************************************************************************************************
-----------------------------------------------------------------B.Création des TableSpaces et utilisateur---------------------------------------------------------
--*********************************************************************************************************************************

--1.
CREATE TABLESPACE SQL3_TBS DATAFILE 'C:\SQL3_TBS.dat'SIZE 100M AUTOEXTEND ON;
--2.
CREATE TEMPORARY TABLESPACE SQL3_TempTBS TEMPFILE 'C:\SQL3_TempTBS.dat' SIZE 100M AUTOEXTEND on;
--3.
Alter session set "_oracle_script"=true; 
CREATE USER projetSql IDENTIFIED BY sql3
DEFAULT TABLESPACE SQL3_TBS
TEMPORARY TABLESPACE SQL3_TempTBS
QUOTA UNLIMITED ON SQL3_TBS;
--4.
GRANT ALL PRIVILEGES TO projetSql;

--*********************************************************************************************************************************
-----------------------------------------------------------------C.Langage de définition de données---------------------------------------------------------
--*********************************************************************************************************************************

--5.
--créer les types incomplets
create type Hotel_Type;
/
create type Chambre_Type;
/
create type Client_Type;
/
create type Reservation_Type;
/
create type Evaluation_Type;
/
--------------------------------------------------Les types -----------------------------------------------------------------------

-- création des types nécessaires aux associations "les tables imbriquées des références"

create type t_set_ref_Hotel as table of ref  Hotel_Type;
/
create type t_set_ref_Chambre as table of ref Chambre_Type;
/
create type t_set_ref_Client as table of ref Client_Type;
/
create type t_set_ref_Reservation as table of ref Reservation_Type;
/
create type t_set_ref_Evaluation as table of ref Evaluation_Type;
/


---------Creation du type Hotel**
CREATE OR REPLACE Type Hotel_Type AS OBJECT (
    NumHotel INTEGER,
    NomHotel VARCHAR(50),
    Ville VARCHAR(50),
    Etoiles INTEGER,
    SiteWeb VARCHAR(100),
	HotelChambre t_set_ref_Chambre,
	HotelClient t_set_ref_Client,
	HotelEvaluation t_set_ref_Evaluation
);
/

--------Creation du type Chambre**
CREATE OR REPLACE Type Chambre_Type AS OBJECT (
    NumChambre INTEGER,
	NumHotel INTEGER,
    Etage INTEGER,
    TypeChambre VARCHAR(50),
    PrixNuit INTEGER,
	ChambreHotel ref Hotel_Type , -- pour referencier la clé etrangere numHotel dans chambre
	ChambreReservation t_set_ref_Reservation
);
/

--------Creation du type client**
CREATE OR REPLACE Type Client_Type AS OBJECT (
    NumClient INTEGER,
    NomClient varchar2(50),
	PrenomClient varchar2(50),
    Email VARCHAR(100),
	ClientReservation t_set_ref_Reservation ,
	ClientEvaluation t_set_ref_Evaluation ,
	ClientHotel t_set_ref_Hotel	
);
/
---------Creation du type Reservation**
CREATE OR REPLACE Type Reservation_Type AS OBJECT (
    NumClient INTEGER,
	NUMCHAMBRE INTEGER,
	NumHotel INTEGER,
	DateArrivee DATE,
    DateDepart DATE,
	ReservationClient ref Client_Type,
	ReservationChambre ref Chambre_Type,
	ReservationHotel ref Hotel_Type
);
/
-------- création de type tevaluation**
create or replace type Evaluation_Type as object (
	NumHotel INTEGER,
	NumClient INTEGER,
	DateEvaluation date,
	note INTEGER,
	EvaluationClient ref Client_Type,
	EvaluationHotel ref Hotel_Type
 );
/

--7.
--------------------------------------------------------------Creation des tables----------------------------------------------------------------
--------Creation de la table Hotel**
CREATE TABLE Hotel OF Hotel_Type (
   CONSTRAINT pk_Hotel primary key(NumHotel),
   CONSTRAINT CHK_ETOILES CHECK (Etoiles >= 1 AND Etoiles <= 5)
)
nested table HotelClient store as table_HotelClient,
nested table HotelEvaluation store as table_HotelEvaluation,
nested table HotelChambre store as table_HotelChambre;

--------Creation de la table Chambre**
CREATE TABLE Chambre OF Chambre_Type (
    constraint pk_Chambre primary key(NumChambre, NumHotel),
	constraint fk_Chambre1 foreign key(ChambreHotel) references Hotel,
    CONSTRAINT CHK_TypeCHAMBRE CHECK (TypeChambre IN ('simple', 'double', 'triple', 'suite', 'autre'))
)
nested table ChambreReservation store as table_ChambreReservation;

--------Creation de la table Client**
CREATE TABLE CLIENT OF Client_Type (
    constraint pk_Client primary key(NumClient)
)
nested table ClientReservation store as table_ClientReservation,
nested table ClientEvaluation  store as table_ClientEvaluation,
nested table ClientHotel store as table_ClientHotel;

--------Creation de la table Reservation**
CREATE TABLE RESERVATION OF Reservation_Type (
    constraint pk_Reservation PRIMARY KEY (NumClient, NumHotel, DateArrivee ),
	CONSTRAINT fk_Reservation FOREIGN KEY (NumHotel) REFERENCES HOTEL,
	CONSTRAINT fk_Reservation1 FOREIGN KEY (ReservationClient) REFERENCES CLIENT ,
    CONSTRAINT fk_Reservation3 FOREIGN KEY (ReservationChambre) REFERENCES Chambre,
    CONSTRAINT CHK_DATE CHECK (DateArrivee > DateDepart)
);

--Creation de la table Evaluation**
CREATE TABLE EVALUATION OF Evaluation_Type (
    CONSTRAINT pk_Evaluation PRIMARY KEY (NumHotel, NumClient, DateEvaluation),
	CONSTRAINT fk_Evaluation3 FOREIGN KEY ( EvaluationClient) REFERENCES CLIENT,
	CONSTRAINT fk_Evaluation4 FOREIGN KEY ( EvaluationHotel) REFERENCES Hotel,
	CONSTRAINT CHK_Note CHECK (Note >= 1 AND Note  <= 10)
);

---------------------------------------------Définir les méthodes permettant de :-------------------------------------------------------

--1.Calculer pour chaque client, le nombre de réservations effectuées :
--la signature
alter type Client_Type
add member function resClient return numeric
cascade;
--le corps
create or replace type body Client_Type
as member function resClient return numeric
is
nbrRes number;
Begin
Select cardinality(self.ClientReservation) into nbrRes
From CLIENT ;
Return nbrRes ;
End ;
End;
/

select c.NUMCLIENT, c.resClient() from CLIENT c;

--2.Calculer pour chaque hôtel, le nombre de chambres.
--la signature
alter type Hotel_Type
add member function nbCham return numeric
cascade;
--le corps
create or replace type body Hotel_Type
as member function nbCham return numeric
is
    nbrchambre number;
begin
    select cardinality(self.HotelChambre) into nbrchambre 
    from HOTEL;
    return nbrchambre;
end;
end;
/

--3.Calculer pour chaque chambre, son chiffre d’affaire.
--la signature
alter type Chambre_Type
add MEMBER FUNCTION ChiffreAffaire RETURN numeric
cascade;
--le corps
CREATE OR REPLACE TYPE BODY Chambre_Type AS
MEMBER FUNCTION ChiffreAffaire RETURN numeric
AS
v_chiffre_affaire number;
BEGIN
SELECT SUM(PrixNuit * (r.DateDepart - r.DateArrivee)) INTO v_chiffre_affaire
FROM Reservation r, Chambre c
WHERE r.NumChambre = c.NumChambre AND c.NumChambre = self.NumChambre;
RETURN v_chiffre_affaire;
END;
END;
/

--4.methodes pour Calculer pour chaque hôtel, le nombre d’évaluations reçues à une date donnée (01-01-2022)
--la signature
alter type Hotel_Type
add member function nbEval(p_dateEvaluation DATE) return numeric
cascade;
--le corps
CREATE OR REPLACE TYPE BODY Hotel_Type AS
  MEMBER FUNCTION nbCham RETURN NUMERIC
  IS
    nbrchambre NUMBER;
  BEGIN
    SELECT COUNT(*) INTO nbrchambre
    FROM Chambre
    WHERE NumHotel = self.NumHotel;
    RETURN nbrchambre;
  END;
 
  MEMBER FUNCTION nbEval(p_dateEvaluation DATE) RETURN NUMERIC
  IS
    NbEvaluations NUMBER;
  BEGIN
    SELECT COUNT(*) INTO NbEvaluations
    FROM Evaluation e
    WHERE e.NumHotel = self.NumHotel AND e.DateEvaluation = p_dateEvaluation;
    RETURN NbEvaluations;
  END;
END;
/
--Remarque 
--Pour faire l'appel a cette fonction en utilisant la date qu'il precise on utilise ce qui suit apres avoir effectuer les insertion bien sur 
SELECT NumHotel, NomHotel, nbEval(DATE '2022-01-01') as nbeval FROM Hotel;


--*********************************************************************************************************************************************
-------------------------------------------------------------D.Langage de manipulation de données--------------------------------------------------------------------
--*********************************************************************************************************************************************

--1.Hotel---------------------------------------------------------------
   
INSERT INTO Hotel values (Hotel_Type (1, 'Renaissance ', 'Tlemcen', 5,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel  values (Hotel_Type (2, 'Seybouse ', 'Annaba', 3,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel values (Hotel_Type (3, 'Hôtel Novotel ', 'Constantine', 4,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel  values (Hotel_Type (4, 'Saint George d''Alger', 'Alger', 5,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel values (Hotel_Type (5, 'Ibis Alger Aéroport', 'Alger', 2,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel values (Hotel_Type (6, 'El Mountazah Annaba', 'Annaba', 3,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel  values (Hotel_Type (7, 'Hôtel Albert 1er', 'Alger', 3,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel values (Hotel_Type (8, 'Chems ', 'Oran', 2,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel values (Hotel_Type (9, 'Colombe ', 'Oran', 3,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel values (Hotel_Type (10, 'Mercure ', 'Alger', 4,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel values (Hotel_Type (11, 'Le Méridien ', 'Oran', 5,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));
INSERT INTO Hotel values (Hotel_Type (12, 'Hôtel Sofitel ', 'Alger', 5,null,t_set_ref_Chambre(),t_set_ref_Client(),t_set_ref_Evaluation()));


--2.Client-----------------------------------------------------------------

INSERT INTO CLIENT VALUES (Client_Type (1, 'BOUROUBI', 'Taous', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (2, 'BOUZIDI', 'AMEL', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (3, 'LACHEMI', 'Bouzid',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (4, 'BOUCHEMLA', 'Elias',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (5, 'HADJ', 'Zouhir',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (6, 'OUSSEDIK', 'Hakim',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (7, 'AAKOUB', 'Fatiha',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (8, 'ABAD', 'Abdelhamid', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (9, 'ABADA', 'Mohamed',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (10, 'ABAYAHIA', 'Abdelkader',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (11, 'ABBACI', 'Abdelmadjid', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (12, 'ABBAS', 'Samira',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (13, 'ABBOU', 'Mohamed',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (14, 'ABDELAZIZ', 'Ahmed',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (15, 'ABDELMOUMEN', 'Nassima',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (16, 'ABDELOUAHAB', 'OUAHIBA', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (17, 'ABDEMEZIANE', 'Madjid',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (18, 'ABERKANE', 'Aicha',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (19, 'AZOUG', 'Dalila',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (20, 'BENOUADAH', 'Mohammed',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (21, 'ACHAIBOU', 'Rachid',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (22, 'ADDAD', 'Fadila',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (23, 'AGGOUN', 'Khadidja', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (24, 'AISSAT', 'Salima',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (25, 'AMARA', 'Dahbia',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (26, 'AROUEL', 'Leila',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (27, 'BAALI', 'Souad',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (28, 'BABACI', 'Mourad',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (29, 'BACHA', 'Nadia',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (30, 'BAHBOUH', 'Naima',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (31, 'BADI', 'Hatem',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (32, 'BAKIR', 'ADEL',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (33, 'BALI', 'Malika', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (34, 'BASSI', 'Fatima',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (35, 'BEHADI', 'Youcef',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (36, 'BEKKAT', 'Hadia',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES(Client_Type (37, 'BELABES', 'Abdelkader',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES(Client_Type (38, 'BELAKERMI', 'Mohammed',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES(Client_Type (39, 'BELGHALI', 'Mohammed',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES(Client_Type (40, 'BELHAMIDI', 'Mustapha',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (41, 'BELKACEMI', 'Hocine',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (42, 'BELKOUT', 'Tayeb',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (43, 'RAHALI', 'Ahcene',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (44, 'FERAOUN', 'Houria',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (45, 'TERKI', 'Amina',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (46, 'CHAOUI', 'Farid',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (47, 'BENDALI', 'Hacine',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (48, 'CHAKER', 'Nadia',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (49, 'BELHAMIDI', 'Mustapha',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (50, 'BELKACEMI', 'Hocine',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (51, 'BELKOUT', 'Tayeb',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (52, 'RAHALI', 'Ahcene',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (53, 'FERAOUN', 'Houria',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (54, 'TERKI', 'Amina', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES(Client_Type (55, 'CHAOUI', 'Farid',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES(Client_Type (56, 'BENDALI', 'Hacine', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (57, 'CHAKER', 'Nadia',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (58, 'BOULARAS', 'Fatima', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (59, 'IGOUDJIL', 'Redouane', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (60, 'GHEZALI', 'Lakhdar',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (61, 'KOULA', 'Brahim',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (62, 'BELAID', 'Layachi', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (63, 'CHALABI', 'Mourad',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT VALUES (Client_Type (64, 'MOHAMMEDI', 'Mustapha',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (65, 'FEKAR', 'Abdelaziz',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (66, 'SAIDOUNI', 'Wafa',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (67, 'YALAOUI', 'Lamia',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (68, 'AYATA', 'Samia',  null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));
INSERT INTO CLIENT  VALUES (Client_Type (69, 'TEBIBEL', 'Nabila', null,t_set_ref_Reservation(),t_set_ref_Evaluation(),t_set_ref_Hotel()));

--3.Chambre------------------------------------------------------------------------------------------

INSERT INTO chambre  VALUES (Chambre_Type(1, 4, 0, 'autre', 13000,(select ref(a) from HOTEL a where NumHotel=4),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(1, 2, 1, 'simple', 4500 ,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES(Chambre_Type (1, 5, 0, 'triple', 7000,(select ref(a) from HOTEL a where NumHotel=5),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(1, 6, 1, 'double', 6000,(select ref(a) from HOTEL a where NumHotel=6),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type (1, 9, 1, 'simple', 3100,(select ref(a) from HOTEL a where NumHotel=9),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(1, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type (2, 5, 1, 'simple', 4000,(select ref(a) from HOTEL a where NumHotel=5),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(2, 2, 1, 'simple', 4800,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type (2, 6, 1, 'double', 6000,(select ref(a) from HOTEL a where NumHotel=6),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(2, 9, 1, 'simple', 3100,(select ref(a) from HOTEL a where NumHotel=9),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(2, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(3, 2, 1, 'double', 7100,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(3, 5, 1, 'double', 5500,(select ref(a) from HOTEL a where NumHotel=5),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(3, 6, 1, 'double', 6000,(select ref(a) from HOTEL a where NumHotel=6),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(3, 9, 1, 'simple', 3200,(select ref(a) from HOTEL a where NumHotel=9),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type (3, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(4, 2, 1, 'simple', 5400,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(4, 6, 2, 'double', 6200,(select ref(a) from HOTEL a where NumHotel=6),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(4, 9, 2, 'simple', 3200,(select ref(a) from HOTEL a where NumHotel=9),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(4, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(5, 2, 2, 'double', 8600,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(5, 6, 2, 'double', 6200,(select ref(a) from HOTEL a where NumHotel=6),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(5, 9, 2, 'simple', 3200,(select ref(a) from HOTEL a where NumHotel=9),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(5, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(6, 2, 2, 'simple', 5800,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(6, 6, 2, 'double', 6200,(select ref(a) from HOTEL a where NumHotel=6),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(6, 9, 2, 'double', 4800,(select ref(a) from HOTEL a where NumHotel=9),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(6, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(7, 2, 2, 'simple', 5800,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type (7, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(8, 2, 2, 'double', 8600,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(8, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(9, 2, 3, 'suite', 16000,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(9, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(10, 1, 1, 'simple', 7100,(select ref(a) from HOTEL a where NumHotel=1),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(10, 2, 3, 'suite', 16500,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(10, 7, 1, 'simple', 3100,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(10, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(11, 1, 1, 'simple', 7100,(select ref(a) from HOTEL a where NumHotel=1),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(11, 4, 1, 'simple', 8400,(select ref(a) from HOTEL a where NumHotel=4),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(11, 7, 1, 'simple', 3100,(select ref(a) from HOTEL a where NumHotel=2),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(11, 11, 0, 'simple', 7800,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(12, 1, 1, 'double', 8800,(select ref(a) from HOTEL a where NumHotel=1),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(12, 4, 1, 'simple', 8400,(select ref(a) from HOTEL a where NumHotel=4),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(12, 7, 1, 'double', 4200,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(12, 11, 0, 'double', 9100,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(13, 1, 1, 'simple', 6200,(select ref(a) from HOTEL a where NumHotel=1),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(13, 4, 1, 'simple', 8600,(select ref(a) from HOTEL a where NumHotel=4),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(13, 11, 0, 'double', 9100,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(14, 4, 1, 'simple', 9000,(select ref(a) from HOTEL a where NumHotel=4),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(14, 11, 1, 'double', 9100,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(15, 11, 1, 'double', 9100,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(16, 11, 1, 'simple', 7700,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(17, 11, 1, 'simple', 7700,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(18, 11, 1, 'simple', 7700,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(19, 11, 1, 'simple', 7700,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(20, 1, 2, 'double', 9000,(select ref(a) from HOTEL a where NumHotel=1),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(20, 7, 2, 'simple', 3100,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(20, 11, 1, 'simple', 7700,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(21, 1, 2, 'simple', 6800,(select ref(a) from HOTEL a where NumHotel=1),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(21, 4, 2, 'double', 12000,(select ref(a) from HOTEL a where NumHotel=4),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(21, 7, 2, 'simple', 3100,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(21, 11, 1, 'simple', 7500,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(22, 1, 2, 'simple', 6800,(select ref(a) from HOTEL a where NumHotel=1),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(22, 4, 2, 'double', 13000,(select ref(a) from HOTEL a where NumHotel=4),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(22, 7, 2, 'double', 4200,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(22, 11, 1, 'simple', 7500,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(23, 1, 2, 'double', 8900,(select ref(a) from HOTEL a where NumHotel=1),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(23, 11, 1, 'simple', 7500,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(24, 11, 1, 'double', 8000,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(25, 11, 1, 'double', 8000,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(26, 11, 1, 'double', 8000,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(27, 11, 2, 'triple', 10900,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(28, 11, 2, 'triple', 10900,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(29, 11, 2, 'simple', 7200,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(30, 7, 3, 'simple', 3100,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(30, 11, 2, 'simple', 7200,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(31, 4, 3, 'triple', 14500,(select ref(a) from HOTEL a where NumHotel=4),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(31, 7, 3, 'simple', 3100,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(31, 11, 2, 'simple', 7200,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(32, 4, 3, 'simple', 9000,(select ref(a) from HOTEL a where NumHotel=4),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(32, 7, 3, 'double', 4200,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(32, 11, 2, 'simple', 7200,(select ref(a) from HOTEL a where NumHotel=11),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(33, 13, 3, 'simple', 5000,(select ref(a) from HOTEL a where NumHotel=13),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(40, 7, 4, 'simple', 2000,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(41, 7, 4, 'simple', 2000,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(42, 7, 4, 'simple', 2000,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(43, 7, 4, 'simple', 1800,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(44, 7, 4, 'simple', 1800,(select ref(a) from HOTEL a where NumHotel=7),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(100, 8, 1, 'simple', 2900,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(100, 10, 1, 'double', 9700,(select ref(a) from HOTEL a where NumHotel=10),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(101, 3, 1, 'simple', 3200,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(101, 8, 1, 'simple', 2900,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(101, 10, 1, 'double', 11000,(select ref(a) from HOTEL a where NumHotel=10),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(101, 12, 1, 'double', 13000,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(102, 3, 1, 'simple', 3200,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(102, 8, 1, 'simple', 2800,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(102, 12, 1, 'double', 13000,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(103, 3, 1, 'simple', 3300,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(103, 12, 1, 'double', 13000,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(104, 12, 1, 'double', 13000,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(105, 12, 1, 'double', 13000,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(106, 12, 1, 'double', 14500,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(107, 12, 1, 'double', 14500,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(200, 8, 2, 'simple', 2800,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(200, 10, 2, 'double', 9700,(select ref(a) from HOTEL a where NumHotel=10),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(201, 3, 2, 'simple', 3200,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(201, 8, 2, 'simple', 2900,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(201, 10, 2, 'double', 9700,(select ref(a) from HOTEL a where NumHotel=10),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(201, 12, 2, 'double', 14500,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(202, 3, 2, 'simple', 3200,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(202, 8, 2, 'simple', 2900,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(202, 10, 2, 'triple', 14100,(select ref(a) from HOTEL a where NumHotel=10),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(202, 12, 2, 'double', 14500,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(203, 3, 2, 'simple', 3300,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(203, 12, 2, 'double', 11800,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(204, 12, 2, 'double', 11800,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(205, 12, 2, 'double', 13000,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(206, 12, 2, 'double', 14500,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(207, 12, 2, 'double', 14500,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre  VALUES (Chambre_Type(208, 14, 1, 'simple', 4500,(select ref(a) from HOTEL a where NumHotel=14),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(300, 8, 3, 'simple', 3000,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(301, 3, 3, 'simple', 3400,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(301, 8, 3, 'simple', 3100,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(301, 12, 3, 'suite', 19500,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(302, 3, 3, 'simple', 3400,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(302, 8, 3, 'double', 3700,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(302, 12, 3, 'suite', 19500,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(303, 3, 3, 'simple', 3400,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(303, 12, 3, 'suite', 19500,(select ref(a) from HOTEL a where NumHotel=12),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(401, 3, 4, 'double', 4200,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(401, 8, 4, 'double', 3700,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(402, 3, 4, 'double', 4200,(select ref(a) from HOTEL a where NumHotel=3),t_set_ref_Reservation()));
INSERT INTO chambre VALUES (Chambre_Type(402, 8, 4, 'simple', 2000,(select ref(a) from HOTEL a where NumHotel=8),t_set_ref_Reservation()));


--4.Reservation----------------------------------------------------------------

alter session set nls_date_format='RRRR-MM-DD HH24:MI:SS';

INSERT INTO reservation VALUES (Reservation_Type(1, 1, 5, '2022-05-15', '2022-05-11', (select ref(a) from Client a where NumClient=1 and rownum = 1),(select ref(a) from Chambre a where NumChambre=1 and rownum = 1),(select ref(a) from Hotel a where NumHotel=5 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(2, 2, 5, '2022-04-18', '2022-04-11', (select ref(a) from Client a where NumClient=2 and rownum = 1),(select ref(a) from Chambre a where NumChambre=2 and rownum = 1),(select ref(a) from Hotel a where NumHotel=5 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(6, 2, 5, '2022-04-06', '2022-04-05',(select ref(a) from Client a where NumClient=6 and rownum = 1),(select ref(a) from Chambre a where NumChambre=2 and rownum = 1),(select ref(a) from Hotel a where NumHotel=5 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(6, 30, 7, '2022-05-01', '2022-04-27',(select ref(a) from Client a where NumClient=6 and rownum = 1),(select ref(a) from Chambre a where NumChambre=30 and rownum = 1),(select ref(a) from Hotel a where NumHotel=7 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(6, 100, 10, '2022-06-14', '2022-06-11',(select ref(a) from Client a where NumClient=6 and rownum = 1),(select ref(a) from Chambre a where NumChambre=100 and rownum = 1),(select ref(a) from Hotel a where NumHotel=10 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(13, 2, 6, '2022-05-10', '2022-05-02',(select ref(a) from Client a where NumClient=13 and rownum = 1),(select ref(a) from Chambre a where NumChambre=2 and rownum = 1),(select ref(a) from Hotel a where NumHotel=6 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(14, 2, 6, '2022-05-01', '2022-04-28',(select ref(a) from Client a where NumClient=14 and rownum = 1),(select ref(a) from Chambre a where NumChambre=2 and rownum = 1),(select ref(a) from Hotel a where NumHotel=6 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(14, 21, 4, '2022-05-13', '2022-05-12',(select ref(a) from Client a where NumClient=14 and rownum = 1),(select ref(a) from Chambre a where NumChambre=21 and rownum = 1),(select ref(a) from Hotel a where NumHotel=4 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(23, 1, 6, '2022-05-09', '2022-05-04',(select ref(a) from Client a where NumClient=23 and rownum = 1),(select ref(a) from Chambre a where NumChambre=1 and rownum = 1),(select ref(a) from Hotel a where NumHotel=6 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(28, 100, 8, '2022-05-03', '2022-04-30',(select ref(a) from Client a where NumClient=28 and rownum = 1),(select ref(a) from Chambre a where NumChambre=100 and rownum = 1),(select ref(a) from Hotel a where NumHotel=8 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(28, 3, 9, '2022-04-14', '2022-04-13',(select ref(a) from Client a where NumClient=28 and rownum = 1),(select ref(a) from Chambre a where NumChambre=3 and rownum = 1),(select ref(a) from Hotel a where NumHotel=9 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(16, 301, 8, '2022-05-03', '2022-05-01',(select ref(a) from Client a where NumClient=16 and rownum = 1),(select ref(a) from Chambre a where NumChambre=301 and rownum = 1),(select ref(a) from Hotel a where NumHotel=8 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(20, 2, 9, '2022-05-20', '2022-05-03',(select ref(a) from Client a where NumClient=20 and rownum = 1),(select ref(a) from Chambre a where NumChambre=2 and rownum = 1),(select ref(a) from Hotel a where NumHotel=9 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(15, 3, 9, '2022-04-20', '2022-04-15',(select ref(a) from Client a where NumClient=15 and rownum = 1),(select ref(a) from Chambre a where NumChambre=3 and rownum = 1),(select ref(a) from Hotel a where NumHotel=9)));
INSERT INTO reservation VALUES (Reservation_Type(12, 8, 11, '2022-05-10', '2022-05-09',(select ref(a) from Client a where NumClient=12 and rownum = 1),(select ref(a) from Chambre a where NumChambre=8 and rownum = 1),(select ref(a) from Hotel a where NumHotel=11 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(3, 9, 11, '2022-04-08', '2022-04-06',(select ref(a) from Client a where NumClient=3 and rownum = 1),(select ref(a) from Chambre a where NumChambre=9 and rownum = 1),(select ref(a) from Hotel a where NumHotel=11 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(7, 7, 11, '2022-05-12', '2006-05-07',(select ref(a) from Client a where NumClient=7 and rownum = 1),(select ref(a) from Chambre a where NumChambre=7 and rownum = 1),(select ref(a) from Hotel a where NumHotel=11 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(47, 20, 11, '2022-04-08', '2022-04-04',(select ref(a) from Client a where NumClient=47 and rownum = 1),(select ref(a) from Chambre a where NumChambre=20 and rownum = 1),(select ref(a) from Hotel a where NumHotel=11 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(44, 5, 11, '2022-05-07', '2022-04-07',(select ref(a) from Client a where NumClient=44 and rownum = 1),(select ref(a) from Chambre a where NumChambre=5 and rownum = 1),(select ref(a) from Hotel a where NumHotel=11and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(80, 302, 13, '2022-05-12', '2022-05-07',(select ref(a) from Client a where NumClient=80 and rownum = 1),(select ref(a) from Chambre a where NumChambre=302 and rownum = 1),(select ref(a) from Hotel a where NumHotel=13 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(40, 9, 11, '2022-04-14', '2022-04-11',(select ref(a) from Client a where NumClient=40 and rownum = 1),(select ref(a) from Chambre a where NumChambre=9 and rownum = 1),(select ref(a) from Hotel a where NumHotel=11 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(40, 8, 2, '2022-05-05', '2022-05-01',(select ref(a) from Client a where NumClient=40 and rownum = 1),(select ref(a) from Chambre a where NumChambre=8 and rownum = 1),(select ref(a) from Hotel a where NumHotel=2 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(40, 23, 1, '2022-05-13', '2022-05-09',(select ref(a) from Client a where NumClient=40 and rownum = 1),(select ref(a) from Chambre a where NumChambre=23 and rownum = 1),(select ref(a) from Hotel a where NumHotel=1 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(22, 25, 11, '2022-04-05', '2022-04-04',(select ref(a) from Client a where NumClient=22 and rownum = 1),(select ref(a) from Chambre a where NumChambre=25 and rownum = 1),(select ref(a) from Hotel a where NumHotel=11 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(112, 1, 5, '2022-06-10', '2022-06-07',(select ref(a) from Client a where NumClient=112 and rownum = 1),(select ref(a) from Chambre a where NumChambre=1 and rownum = 1),(select ref(a) from Hotel a where NumHotel=5 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(26, 25, 11, '2022-04-26', '2022-04-22',(select ref(a) from Client a where NumClient=26 and rownum = 1),(select ref(a) from Chambre a where NumChambre=25 and rownum = 1),(select ref(a) from Hotel a where NumHotel=11 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(29, 1, 11, '2022-04-08', '2022-04-04',(select ref(a) from Client a where NumClient=29 and rownum = 1),(select ref(a) from Chambre a where NumChambre=1 and rownum = 1),(select ref(a) from Hotel a where NumHotel=11 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(37, 302, 8, '2022-05-10', '2022-05-12',(select ref(a) from Client a where NumClient=37 and rownum = 1),(select ref(a) from Chambre a where NumChambre=302 and rownum = 1),(select ref(a) from Hotel a where NumHotel=8 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(29, 205, 12, '2022-05-09', '2022-05-04',(select ref(a) from Client a where NumClient=29 and rownum = 1),(select ref(a) from Chambre a where NumChambre=205 and rownum = 1),(select ref(a) from Hotel a where NumHotel=12 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(35, 101, 12, '2022-05-06', '2022-04-04',(select ref(a) from Client a where NumClient=35 and rownum = 1),(select ref(a) from Chambre a where NumChambre=101 and rownum = 1),(select ref(a) from Hotel a where NumHotel=12 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(35, 2, 5, '2022-05-23', '2022-05-17',(select ref(a) from Client a where NumClient=35 and rownum = 1),(select ref(a) from Chambre a where NumChambre=2 and rownum = 1),(select ref(a) from Hotel a where NumHotel=5 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(35, 2, 6, '2022-06-02', '2022-05-27',(select ref(a) from Client a where NumClient=35 and rownum = 1),(select ref(a) from Chambre a where NumChambre=2 and rownum = 1),(select ref(a) from Hotel a where NumHotel=6 and rownum = 1)));
INSERT INTO reservation VALUES (Reservation_Type(37, 202, 12, '2022-05-18', '2022-05-11',(select ref(a) from Client a where NumClient=37 and rownum = 1),(select ref(a) from Chambre a where NumChambre=202 and rownum = 1),(select ref(a) from Hotel a where NumHotel=12 and rownum = 1)));


--5.Evaluation-------------------------------------------------

INSERT INTO Evaluation VALUES (Evaluation_Type(5, 1, '2022-05-15', 4,(select ref(a) from Client a where NumClient=1),(select ref(b) from Hotel b where NumHotel=5)));
INSERT INTO Evaluation values  (Evaluation_Type(5, 2, '2022-04-18', 3,(select ref(a) from Client a where NumClient=2),(select ref(b) from Hotel b where NumHotel=5)));
INSERT INTO Evaluation VALUES (Evaluation_Type(5, 6, '2022-04-06', 2,(select ref(a) from Client a where NumClient=6),(select ref(b) from Hotel b where NumHotel=5)));
INSERT INTO Evaluation VALUES (Evaluation_Type(7, 6, '2022-05-01', 5,(select ref(a) from Client a where NumClient=6),(select ref(b) from Hotel b where NumHotel=7)));
INSERT INTO Evaluation VALUES (Evaluation_Type(10, 6, '2022-06-14', 4,(select ref(a) from Client a where NumClient=6),(select ref(b) from Hotel b where NumHotel=10)));
INSERT INTO Evaluation VALUES (Evaluation_Type(6, 13, '2022-05-10', 3,(select ref(a) from Client a where NumClient=13),(select ref(b) from Hotel b where NumHotel=6)));
INSERT INTO Evaluation VALUES (Evaluation_Type(6, 14, '2022-05-01', 4,(select ref(a) from Client a where NumClient=14),(select ref(b) from Hotel b where NumHotel=6)));
INSERT INTO Evaluation VALUES (Evaluation_Type(4, 14, '2022-05-13', 5,(select ref(a) from Client a where NumClient=14),(select ref(b) from Hotel b where NumHotel=4)));
INSERT INTO Evaluation VALUES (Evaluation_Type(6, 23, '2022-05-09', 2,(select ref(a) from Client a where NumClient=23),(select ref(b) from Hotel b where NumHotel=6)));
INSERT INTO Evaluation VALUES (Evaluation_Type(8, 28, '2022-05-03', 4,(select ref(a) from Client a where NumClient=28),(select ref(b) from Hotel b where NumHotel=8)));
INSERT INTO Evaluation VALUES (Evaluation_Type(9, 28, '2022-04-14', 3,(select ref(a) from Client a where NumClient=28),(select ref(b) from Hotel b where NumHotel=9)));
INSERT INTO Evaluation VALUES (Evaluation_Type(8, 16, '2022-05-03', 5,(select ref(a) from Client a where NumClient=16),(select ref(b) from Hotel b where NumHotel=8)));
INSERT INTO Evaluation VALUES (Evaluation_Type(9, 20, '2022-05-20', 4,(select ref(a) from Client a where NumClient=20),(select ref(b) from Hotel b where NumHotel=9)));
INSERT INTO Evaluation VALUES (Evaluation_Type(9, 15, '2022-04-20', 2,(select ref(a) from Client a where NumClient=15),(select ref(b) from Hotel b where NumHotel=9)));
INSERT INTO Evaluation VALUES (Evaluation_Type(11, 12, '2022-05-10', 3,(select ref(a) from Client a where NumClient=12),(select ref(b) from Hotel b where NumHotel=11)));
INSERT INTO Evaluation VALUES (Evaluation_Type(11, 3, '2022-04-08', 4,(select ref(a) from Client a where NumClient=3),(select ref(b) from Hotel b where NumHotel=11)));
INSERT INTO Evaluation VALUES (Evaluation_Type(11, 7, '2022-05-12', 5,(select ref(a) from Client a where NumClient=7),(select ref(b) from Hotel b where NumHotel=11)));
INSERT INTO Evaluation VALUES (Evaluation_Type(11, 47, '2022-04-08', 3,(select ref(a) from Client a where NumClient=47),(select ref(b) from Hotel b where NumHotel=11)));
INSERT INTO Evaluation VALUES (Evaluation_Type(11, 44, '2022-05-07', 2,(select ref(a) from Client a where NumClient=44),(select ref(b) from Hotel b where NumHotel=11)));
INSERT INTO Evaluation VALUES (Evaluation_Type(11, 40, '2022-04-14', 3,(select ref(a) from Client a where NumClient=40),(select ref(b) from Hotel b where NumHotel=11)));
INSERT INTO Evaluation VALUES (Evaluation_Type(2, 40, '2022-05-05', 5,(select ref(a) from Client a where NumClient=40),(select ref(b) from Hotel b where NumHotel=2)));
INSERT INTO Evaluation VALUES (Evaluation_Type(1, 40, '2022-05-13', 2,(select ref(a) from Client a where NumClient=40),(select ref(b) from Hotel b where NumHotel=1)));
INSERT INTO Evaluation VALUES (Evaluation_Type(11, 22, '2022-04-05', 4,(select ref(a) from Client a where NumClient=22),(select ref(b) from Hotel b where NumHotel=11)));
INSERT INTO Evaluation VALUES (Evaluation_Type(11, 26, '2022-04-26', 5,(select ref(a) from Client a where NumClient=26),(select ref(b) from Hotel b where NumHotel=11)));
INSERT INTO Evaluation VALUES (Evaluation_Type(11, 29, '2022-04-08', 2,(select ref(a) from Client a where NumClient=29),(select ref(b) from Hotel b where NumHotel=11)));
INSERT INTO Evaluation VALUES (Evaluation_Type(8, 37, '2022-05-10', 4,(select ref(a) from Client a where NumClient=37),(select ref(b) from Hotel b where NumHotel=8)));
INSERT INTO Evaluation VALUES (Evaluation_Type(12, 29, '2022-05-09', 3,(select ref(a) from Client a where NumClient=29),(select ref(b) from Hotel b where NumHotel=12)));
INSERT INTO Evaluation VALUES (Evaluation_Type(12, 35, '2022-05-06', 5,(select ref(a) from Client a where NumClient=35),(select ref(b) from Hotel b where NumHotel=12)));
INSERT INTO Evaluation VALUES (Evaluation_Type(5, 35, '2022-05-23', 4,(select ref(a) from Client a where NumClient=35),(select ref(b) from Hotel b where NumHotel=5)));
INSERT INTO Evaluation VALUES (Evaluation_Type(6, 35, '2022-06-02', 2,(select ref(a) from Client a where NumClient=35),(select ref(b) from Hotel b where NumHotel=6)));
INSERT INTO Evaluation VALUES (Evaluation_Type(12, 37, '2022-05-18', 3,(select ref(a) from Client a where NumClient=37),(select ref(b) from Hotel b where NumHotel=12)));


--*********************************************************************************************************************************
-----------------------------------------------------Maj des tables imbriquées ------------------------------------------
--*********************************************************************************************************************************

-------------insertion dans la table imbr HotelClient:

insert into table (select l.HotelClient from Hotel l where NUMHOTEL=5)
(select ref(c) from CLIENT c where NUMCLIENT=1);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=5)
(select ref(c) from CLIENT c where NUMCLIENT=2);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=5)
(select ref(c) from CLIENT c where NUMCLIENT=6);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=7)
(select ref(c) from CLIENT c where NUMCLIENT=6);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=10)
(select ref(c) from CLIENT c where NUMCLIENT=6);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=6)
(select ref(c) from CLIENT c where NUMCLIENT=13);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=6)
(select ref(c) from CLIENT c where NUMCLIENT=14);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=4)
(select ref(c) from CLIENT c where NUMCLIENT=14);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=6)
(select ref(c) from CLIENT c where NUMCLIENT=23);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=8)
(select ref(c) from CLIENT c where NUMCLIENT=28);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=9)
(select ref(c) from CLIENT c where NUMCLIENT=28);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=8)
(select ref(c) from CLIENT c where NUMCLIENT=16);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=9)
(select ref(c) from CLIENT c where NUMCLIENT=20);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=9)
(select ref(c) from CLIENT c where NUMCLIENT=15);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=11)
(select ref(c) from CLIENT c where NUMCLIENT=12);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=11)
(select ref(c) from CLIENT c where NUMCLIENT=3);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=11)
(select ref(c) from CLIENT c where NUMCLIENT=7);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=11)
(select ref(c) from CLIENT c where NUMCLIENT=47);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=11)
(select ref(c) from CLIENT c where NUMCLIENT=44);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=13)
(select ref(c) from CLIENT c where NUMCLIENT=80);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=11)
(select ref(c) from CLIENT c where NUMCLIENT=40);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=2)
(select ref(c) from CLIENT c where NUMCLIENT=40);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=1)
(select ref(c) from CLIENT c where NUMCLIENT=40);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=11)
(select ref(c) from CLIENT c where NUMCLIENT=22);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=5)
(select ref(c) from CLIENT c where NUMCLIENT=112);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=11)
(select ref(c) from CLIENT c where NUMCLIENT=26);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=11)
(select ref(c) from CLIENT c where NUMCLIENT=29);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=8)
(select ref(c) from CLIENT c where NUMCLIENT=37);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=12)
(select ref(c) from CLIENT c where NUMCLIENT=29);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=12)
(select ref(c) from CLIENT c where NUMCLIENT=35);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=5)
(select ref(c) from CLIENT c where NUMCLIENT=35);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=6)
(select ref(c) from CLIENT c where NUMCLIENT=35);
insert into table (select l.HotelClient from Hotel l where NUMHOTEL=12)
(select ref(c) from CLIENT c where NUMCLIENT=37);


------------------------------insertion dans ClientReservation on utilise la table client

insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=1)
(select ref(c) from RESERVATION c where NUMCLIENT=1);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=2)
(select ref(c) from RESERVATION c where NUMCLIENT=2);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=3)
(select ref(c) from RESERVATION c where NUMCLIENT=3);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=4)
(select ref(c) from RESERVATION c where NUMCLIENT=4);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=5)
(select ref(c) from RESERVATION c where NUMCLIENT=5);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=6)
(select ref(c) from RESERVATION c where NUMCLIENT=6);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=7)
(select ref(c) from RESERVATION c where NUMCLIENT=7);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=8)
(select ref(c) from RESERVATION c where NUMCLIENT=8);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=9)
(select ref(c) from RESERVATION c where NUMCLIENT=9);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=10)
(select ref(c) from RESERVATION c where NUMCLIENT=10);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=11)
(select ref(c) from RESERVATION c where NUMCLIENT=11);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=12)
(select ref(c) from RESERVATION c where NUMCLIENT=12);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=13)
(select ref(c) from RESERVATION c where NUMCLIENT=13);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=14)
(select ref(c) from RESERVATION c where NUMCLIENT=14);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=15)
(select ref(c) from RESERVATION c where NUMCLIENT=15);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=16)
(select ref(c) from RESERVATION c where NUMCLIENT=16);
insert into table (select l.ClientReservation from CLIENT l where NUMCLIENT=17)
(select ref(c) from RESERVATION c where NUMCLIENT=17);

select count(*) from client c, table(c.ClientReservation) v;


-----------------------------insertion dans HotelChambre  on utilise la table chambre 

insert into table (select l.HotelChambre from hotel l where NUMHOTEL=2)
(select ref(c) from chambre c where NUMCHAMBRE=1);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=4)
(select ref(c) from chambre c where NUMCHAMBRE=1);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=5)
(select ref(c) from chambre c where NUMCHAMBRE=1);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=6)
(select ref(c) from chambre c where NUMCHAMBRE=1);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=9)
(select ref(c) from chambre c where NUMCHAMBRE=1);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=11)
(select ref(c) from chambre c where NUMCHAMBRE=1);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=2)
(select ref(c) from chambre c where NUMCHAMBRE=2);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=5)
(select ref(c) from chambre c where NUMCHAMBRE=2);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=6)
(select ref(c) from chambre c where NUMCHAMBRE=2);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=9)
(select ref(c) from chambre c where NUMCHAMBRE=2);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=11)
(select ref(c) from chambre c where NUMCHAMBRE=2);
insert into table (select l.HotelChambre from hotel l where NUMHOTEL=12)
(select ref(c) from chambre c where NUMCHAMBRE=303);

select count(*) from hotel c, table(c.HotelChambre) v;

-------------------------------insertion dans HotelEvaluation  on utilise la table hotal  RMQ: on a pas des hot avec une moy>=6 mais avec 5 si

insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=1)
(select ref(c) from Evaluation c where NUMHOTEL=1);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=2)
(select ref(c) from Evaluation c where NUMHOTEL=2);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=3)
(select ref(c) from Evaluation c where NUMHOTEL=3);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=4)
(select ref(c) from Evaluation c where NUMHOTEL=4);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=5)
(select ref(c) from Evaluation c where NUMHOTEL=5);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=6)
(select ref(c) from Evaluation c where NUMHOTEL=6);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=7)
(select ref(c) from Evaluation c where NUMHOTEL=7);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=8)
(select ref(c) from Evaluation c where NUMHOTEL=8);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=9)
(select ref(c) from Evaluation c where NUMHOTEL=9);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=10)
(select ref(c) from Evaluation c where NUMHOTEL=10);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=11)
(select ref(c) from Evaluation c where NUMHOTEL=11);
insert into table (select l.HotelEvaluation from hotel l where NUMHOTEL=12)
(select ref(c) from Evaluation c where NUMHOTEL=12);


--*********************************************************************************************************************************
-----------------------------------------------------------------E.Interogation de la base de donnée---------------------------------------------------------
--*********************************************************************************************************************************

--9.
--Lister les noms d’hôtels et leurs villes respectives.

SELECT CONCAT (NomHotel, Ville) FROM Hotel;

--10.
--Lister les hôtels sur lesquels porte au moins une réservation.
select H.NOMHOTEL
from hotel H, table(H.HotelClient) c
group by H.NOMHOTEL;

--11.
--Quels sont les clients qui ont toujours séjourné au premier étage ?
select CONCAT(c.NOMCLIENT, c.PRENOMCLIENT)
from client c, table(c.ClientReservation) r
where deref(deref(value(r)).ReservationChambre).etage=1;

SELECT C.NumClient, C.NomClient, C.PrenomClient
FROM Client C
WHERE NOT EXISTS (
    SELECT *
    FROM Reservation R
    INNER JOIN Chambre CH ON R.ReservationChambre = REF(CH)
    WHERE R.ReservationClient = REF(C) AND CH.Etage != 1
);

--12.
--Quels sont les hôtels (nom, ville) qui offrent des suites ? et donner le prix pour chaque suite
select h.NOMHOTEL, h.VILLE, deref(value(ch)).PrixNuit
from hotel h, table(h.HotelChambre) ch
where deref(value(ch)).TYPECHAMBRE='suite';

--13.
--Quel est le type de chambre le plus réservé habituellement, pour chaque hôtel d’Alger ?
SELECT h.NomHotel, c.TypeChambre, COUNT(*) AS Nombre_de_reservations
FROM Reservation r
JOIN Chambre c ON r.ReservationChambre = REF(c)
JOIN Hotel h ON r.ReservationHotel = REF(h)
WHERE h.Ville = 'Alger'
GROUP BY h.NomHotel, c.TypeChambre
ORDER BY h.NomHotel, Nombre_de_reservations DESC;

--14.
--Quels sont les hôtels (nom, ville) ayant obtenu une moyenne de notes >=6, durant l’année 2022
SELECT h.NOMHOTEL, h.VILLE
FROM hotel h, TABLE(h.HotelEvaluation) he
where EXTRACT(YEAR FROM deref(VALUE(he)).DateEvaluation) = 2022
GROUP BY h.NOMHOTEL, h.VILLE
HAVING AVG(deref(VALUE(he)).note) >= 6;

SELECT h.NOMHOTEL, h.VILLE
FROM hotel h, TABLE(h.HotelEvaluation) he
where EXTRACT(YEAR FROM deref(VALUE(he)).DateEvaluation) = 2022
GROUP BY h.NOMHOTEL, h.VILLE
HAVING AVG(deref(VALUE(he)).note) >= 5;

--15.
--Quel est l’hôtel ayant réalisé le meilleur chiffre d’affaire durant l’été 2022
SELECT h.NomHotel, SUM(c.PrixNuit * (r.DateDepart -r. DateArrivee)) AS Chiffre_daffaire
FROM Reservation r
JOIN Chambre c ON r.ReservationChambre = REF(c)
JOIN Hotel h ON r.ReservationHotel = REF(h)
WHERE EXTRACT(MONTH FROM r.DateArrivee) IN (6, 7, 8)
GROUP BY h.NomHotel
ORDER BY Chiffre_daffaire DESC;


