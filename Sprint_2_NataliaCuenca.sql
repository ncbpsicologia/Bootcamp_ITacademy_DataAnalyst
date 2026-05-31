#NIVELL 1

USE transactions;

#Exercici 2: Utilitzant JOIN realitzaràs les següents consultes:
#Exercici 2.1: Llistat dels països que estan generant vendes.
SELECT DISTINCT c.country 
FROM company AS c
JOIN transaction AS t
	ON c.id = t.company_id
ORDER BY c.country;

#Exercici 2.2: Des de quants països es generen les vendes.
SELECT COUNT(DISTINCT c.country) AS num_paisos
FROM company AS c
JOIN transaction AS t 
	ON c.id = t.company_id;

#Exercici 2.3: Identifica la companyia amb la mitjana més gran de vendes.
SELECT c.company_name, ROUND(AVG(t.amount),2) AS mitjana_vendes
FROM company AS c
JOIN transaction AS t 
	ON c.id = t.company_id
GROUP BY c.company_name
ORDER BY mitjana_vendes DESC
LIMIT 1;

#Exercici 3: Utilitzant només subconsultes (sense utilitzar JOIN):
#Exercici 3.1: Mostra totes les transaccions realitzades per empreses d'Alemanya.
SELECT t.id
FROM transaction AS t
WHERE t.company_id IN (
    SELECT c.id
    FROM company AS c
    WHERE c.country = "Germany"
);

#Exercici 3.2: Llista les empreses que han realitzat transaccions per un amount superior a la mitjana de 
# totes les transaccions.
SELECT co.id, co.company_name
FROM company AS co
WHERE EXISTS (
	SELECT 1
    FROM transaction AS tr
    WHERE tr.company_id = co.id
		AND tr.amount > (
			SELECT AVG(amount)
            FROM transaction AS tr1)
	);

#Exercici 3.3: Eliminaran del sistema les empreses que no tenen transaccions registrades, entrega el llistat d'aquestes empreses.
SELECT c.company_name
FROM company AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM transaction AS t2
    WHERE t2.company_id = c.id
);
# Totes les empreses han registrat transaccions

#Exercici 4: La teva tasca és dissenyar i crear una taula anomenada "credit_card" 
# que emmagatzemi detalls crucials sobre les targetes de crèdit. La nova taula ha de ser capaç 
# d'identificar de manera única cada targeta i establir una relació adequada amb les altres dues taules 
# ("transaction" i "company"). Després de crear la taula serà necessari que ingressis la informació del document 
# denominat "dades_introduir_credit". Recorda mostrar el diagrama i realitzar una breu descripció d'aquest.

 CREATE TABLE credit_card (
	  id VARCHAR(15), 
      iban VARCHAR(40), 
      pan VARCHAR(20), 
      pin VARCHAR(4), 
      cvv VARCHAR(3), 
      expiring_date VARCHAR(8), 
      PRIMARY KEY (id)
 );

SET SQL_SAFE_UPDATES = 0;

ALTER TABLE credit_card 
ADD COLUMN new_date DATE;

UPDATE credit_card
SET new_date = STR_TO_DATE(TRIM(expiring_date), '%m/%d/%y')
WHERE TRIM(expiring_date) LIKE '__/__/__';

SET SQL_SAFE_UPDATES = 1;

ALTER TABLE transaction
ADD CONSTRAINT fk_cc_transaction
FOREIGN KEY (credit_card_id) REFERENCES credit_card(id);

# Exercici 5:
# El departament de Recursos Humans ha identificat un error en el número de compte associat a la targeta de crèdit 
# amb ID CcU-2938. La informació que ha de mostrar-se per a aquest registre és: TR323456312213576817699999. 
# Recorda mostrar que el canvi es va realitzar.
SELECT * 
FROM credit_card
WHERE id = 'CcU-2938';

UPDATE credit_card
SET iban = 'TR323456312213576817699999'
WHERE id = 'CcU-2938';

SELECT * 
FROM credit_card
WHERE id = 'CcU-2938';

# Exercici 6:
# En la taula "transaction" ingressa una nova transacció amb la següent informació:

#INSERT INTO company (id)
#VALUES ('b-9999');

INSERT INTO credit_card (id)
VALUES ('CcU-9999');

INSERT INTO transaction (id, credit_card_id, company_id, user_id, lat, longitude, amount, declined)
VALUES ('108B1D1D-5B23-A76C-55EF-C568E49A99DD', 'CcU-9999', 'b-9999', 9999, 829.999, -117.999, 111.11, 0);

SELECT * 
FROM transaction
WHERE credit_card_id = 'CcU-9999'; #RETORNA 0 ROWS Y AL BUSCAR NO SALE..

# Exercici 7:
# Des de recursos humans et sol·liciten eliminar la columna "pan" de la taula credit_card. 
# Recorda mostrar el canvi realitzat.

ALTER TABLE credit_card
DROP COLUMN pan;

SELECT *
FROM credit_card;

# Exercici 8 
# Descarrega els arxius CSV que trobaràs a l'apartat de recursos:
# Estudia'ls i dissenya una base de dades amb un esquema d'estrella que contingui, almenys 4 taules 
# de les quals puguis realitzar les següents consultes: La taula de products.csv l'utilitzarem més endavant.

CREATE DATABASE users_transactions;

USE users_transactions;

 CREATE TABLE users (id VARCHAR(10) PRIMARY KEY, name VARCHAR(15), surname VARCHAR(15), phone VARCHAR(15), 
	 email VARCHAR(40), birth_date VARCHAR(15), country VARCHAR(20), city VARCHAR(20), postal_code VARCHAR(5), 
     adress VARCHAR(50), signup_date VARCHAR(10), user_segment VARCHAR(30), income_band VARCHAR(10), region VARCHAR(10));

 LOAD DATA LOCAL INFILE 'C:/Users/naatc/OneDrive/Escritorio/ex8/N1-Ex.8__american_users.csv'
 INTO TABLE users_transactions.users
 FIELDS TERMINATED BY ',' 
 OPTIONALLY ENCLOSED BY '"' 
 LINES TERMINATED BY '\n' 
 IGNORE 1 LINES
 SET region = 'American';

 LOAD DATA LOCAL INFILE 'C:/Users/naatc/OneDrive/Escritorio/ex8/N1-Ex.8__european_users.csv'
 INTO TABLE users_transactions.users
 FIELDS TERMINATED BY ',' 
 OPTIONALLY ENCLOSED BY '"' 
 LINES TERMINATED BY '\n' 
 IGNORE 1 LINES
 SET region = 'European';

CREATE TABLE companies (company_id VARCHAR(10) PRIMARY KEY, company_name VARCHAR(50), phone VARCHAR(15), email VARCHAR(40), 
	 country VARCHAR(20), website VARCHAR(40), merchant_category VARCHAR(15), merchant_price VARCHAR(15), 
     merchant_price_position VARCHAR(15));

 LOAD DATA LOCAL INFILE 'C:/Users/naatc/OneDrive/Escritorio/ex8/N1-Ex.8__companies.csv'
 INTO TABLE users_transactions.companies
 FIELDS TERMINATED BY ',' 
 OPTIONALLY ENCLOSED BY '"' 
 LINES TERMINATED BY '\n' 
 IGNORE 1 LINES;

CREATE TABLE credit_cards (id VARCHAR(10) PRIMARY KEY, user_id VARCHAR(50), iban VARCHAR(30), pan VARCHAR(20), 
	pin VARCHAR(5), cvv VARCHAR(3), track1 VARCHAR(50), track2 VARCHAR(50), expiring_date VARCHAR(15),
    card_type VARCHAR(15), card_renewal_flag VARCHAR(1));

LOAD DATA LOCAL INFILE 'C:/Users/naatc/OneDrive/Escritorio/ex8/N1-Ex.8__credit_cards.csv'
INTO TABLE users_transactions.credit_cards
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 LINES;
    
CREATE TABLE transaction1 (id VARCHAR(40) PRIMARY KEY, card_id VARCHAR(10), bussines_id VARCHAR(10), timestamp VARCHAR(20), 
	amount VARCHAR(10), declined VARCHAR(1), product_id VARCHAR(5), user_id VARCHAR(10), lat VARCHAR(20),
    longitude VARCHAR(20), discount_amount VARCHAR(10), tax_amount VARCHAR(10), shipping_amount VARCHAR(10),
    channel VARCHAR(20), campaign_id VARCHAR(20), device_type VARCHAR(10), is_international VARCHAR(1),
    decline_reason VARCHAR(20), distance_km VARCHAR(10));

LOAD DATA LOCAL INFILE 'C:/Users/naatc/OneDrive/Escritorio/ex8/N1-Ex.8__transactions.csv'
INTO TABLE users_transactions.transaction1
FIELDS TERMINATED BY ';' 
OPTIONALLY ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 LINES;

ALTER TABLE transaction1
ADD CONSTRAINT fk_transactions_companies
	FOREIGN KEY (bussines_id) REFERENCES companies(company_id),
ADD CONSTRAINT fk_transactions_users
	FOREIGN KEY (user_id) REFERENCES users(id),
ADD CONSTRAINT fk_transactions_cards
	FOREIGN KEY (card_id) REFERENCES credit_cards(id);

# Exercici 9 Realitza una subconsulta que mostri tots els usuaris amb més de 80 transaccions utilitzant almenys 2 taules.
USE users_transactions;

SELECT id, name, surname
FROM users
WHERE EXISTS (
    SELECT user_id
    FROM transaction1
    WHERE transaction1.user_id = users.id
    GROUP BY user_id
    HAVING COUNT(id) > 80
);

# Exercici 10 Mostra la mitjana d'amount per IBAN de les targetes de crèdit a la companyia Donec Ltd, utilitza almenys 2 taules.
SELECT co.company_id, co.company_name, cc.iban, ROUND(AVG(tr.amount), 2) AS mitjana_amount
FROM companies AS co
JOIN transaction1 AS tr on co.company_id = tr.bussines_id
JOIN credit_cards AS cc on tr.card_id = cc.id
WHERE co.company_name LIKE 'Donec Ltd'
GROUP BY co.company_id, co.company_name, cc.iban
ORDER BY mitjana_amount DESC;

# NIVELL 2
# Exercici 1: Identifica els cinc dies que es va generar la quantitat més gran d'ingressos a l'empresa per vendes. 
# Mostra la data de cada transacció juntament amb el total de les vendes.

SELECT DATE(tr.timestamp) AS data_venda, ROUND(SUM(tr.amount),2) AS total_vendes
FROM transaction1 AS tr
GROUP BY DATE(tr.timestamp)
ORDER BY total_vendes DESC
LIMIT 5;

# Exercici 2
# Presenta el nom, telèfon, país, data i amount, d'aquelles empreses que van realitzar transaccions amb un 
# valor comprès entre 350 i 400 euros i en alguna d'aquestes dates: 29 d'abril del 2015, 20 de juliol del 2018 
# i 13 de març del 2024. Ordena els resultats de major a menor quantitat.

SELECT co.company_name, co.phone, co.country, DATE(tr.timestamp), tr.amount
FROM companies AS co
JOIN transaction1 AS tr ON co.company_id = tr.bussines_id
WHERE tr.amount > 350 AND tr.amount < 400
	AND DATE(tr.timestamp) IN ("2015-04-19", "2018-07-20", "2024-03-13")
ORDER BY tr.amount DESC;

#Exercici 3
#Necessitem optimitzar l'assignació dels recursos i dependrà de la capacitat operativa que es requereixi, 
#per la qual cosa et demanen la informació sobre la quantitat de transaccions que realitzen les empreses, 
#però el departament de recursos humans és exigent i vol un llistat de les empreses on especifiquis si tenen 
#igual o més de 400 transaccions o menys.

SELECT co.company_id, COUNT(tr.id) AS total_transaccions,
	CASE WHEN COUNT(tr.id) >= 400 THEN 'Igual o més de 400'
		ELSE 'Menys de 400'
	END AS classificacio
FROM transaction1 AS tr
JOIN companies AS co ON tr.bussines_id = co.company_id
GROUP BY co.company_id
ORDER BY total_transaccions DESC;

#Exercici 4
#Elimina de la taula transaction el registre amb ID 000447FE-B650-4DCF-85DE-C7ED0EE1CAAD de la base de dades.

SELECT COUNT(id)
FROM transaction1;
# Salen 100000 registros

SELECT id 
FROM transaction1 
WHERE id LIKE '%C7ED0EE1CAAD%';

SET SQL_SAFE_UPDATES = 0;

DELETE FROM transaction1 
WHERE id LIKE '000447FE-B650-4DCF-85DE-C7ED0EE1CAAD';

SET SQL_SAFE_UPDATES = 1;

SELECT COUNT(id)
FROM transaction1;

#Exercici 5
#La secció de màrqueting desitja tenir accés a informació específica per a realitzar anàlisi i estratègies 
#efectives. S'ha sol·licitat crear una vista que proporcioni detalls clau sobre les companyies i les seves 
#transaccions. Serà necessària que creïs una vista anomenada VistaMarketing que contingui la següent informació: 
#Nom de la companyia. Telèfon de contacte. País de residència. Mitjana de compra realitzat per cada companyia. 
#Presenta la vista creada, ordenant les dades de major a menor mitjana de compra.

CREATE OR REPLACE VIEW VistaMarketing AS 
SELECT co.company_id, co.company_name, co.phone, co.country, AVG(tr.amount) AS mitjana_compra
FROM companies AS co
JOIN transaction1 AS tr ON co.company_id = tr.bussines_id
GROUP BY co.company_id;

SELECT * 
FROM VistaMarketing
ORDER BY mitjana_compra DESC;