-- NIVELL 1: ENTORN I INGESTA HÍBRIDA (CODE-FIRST)
-- EX 1.- ARQUITECCTURA DE DADES (Lògica vs. Física)

CREATE SCHEMA ‘sprint3_silver’
OPTIONS(
	location=”EU”
);

-- bronze y gold se creaban de otras maneras

--

-- EX 2.- INGESTA EN CAPA BRONZE (CONNEXIÓ DDL)

-- transactions
CREATE OR REPLACE EXTERNAL TABLE sprint3_bronze.transactions_raw
OPTIONS (
  format = 'CSV',
  field_delimiter = ';',
  uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv']
);

-- companies
CREATE OR REPLACE EXTERNAL TABLE sprint3_bronze.companies_raw
OPTIONS (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv']
);

-- american_users
CREATE OR REPLACE EXTERNAL TABLE sprint3_bronze.american_users_raw
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv']
);

-- european_users
CREATE OR REPLACE EXTERNAL TABLE sprint3_bronze.european_users_raw
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv']
);

-- credit_cards
CREATE OR REPLACE EXTERNAL TABLE sprint3_bronze.credit_cards_raw
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv']
);

--

-- EX 3.- CÀRREGA DE DADES LOCALS (UPLOAD)

-- no se realizaba mediante código

--

-- EX 4.- ARQUITETURA I RENDIMENT
-- materialització de dades (assistit per IA) 

CREATE OR REPLACE TABLE `sprint3-analytics-nataliacuenc.sprint3_bronze.transactions_raw_native`
AS
SELECT * FROM `sprint3-analytics-nataliacuenc.sprint3_bronze.transactions_raw`;


-- auditoria de costos

SELECT id 
FROM `sprint3_bronze.transactions_raw`;

SELECT transaction_id 
FROM `sprint3_bronze.transactions_raw_native`;


-- el perill del LIMIT

SELECT * 
FROM sprint3_bronze.transactions_raw_native 
LIMIT 10;

--

-- EX.- 5 ADAPTACIÓ DE SINTAXI (REPORTING)

SELECT 
  DATE(timestamp) AS data_transaccio,
  ROUND(SUM(amount), 2) AS total_ingressos
FROM `sprint3_bronze.transactions_raw_native`
WHERE EXTRACT(YEAR FROM timestamp) = 2021
	AND declined = 0
GROUP BY data_transaccio
ORDER BY total_ingressos DESC
LIMIT 5;

--

-- EX 6.- CONSULTES COMPLEXES

SELECT cr.string_field_1 AS nom, cr.string_field_4 AS pais, DATE(trn.timestamp) AS data

FROM sprint3_bronze.companies_raw AS cr
  JOIN sprint3_bronze.transactions_raw_native AS trn on cr.string_field_0 = trn.business_id

WHERE trn.amount BETWEEN 100 AND 200
  AND DATE(trn.timestamp) IN ('2015-04-29', '2018-07-20', '2024-03-13')
AND declined = 0;

--

-- NIVELL 2: NETEJA I TRANSFORMACIÓ (ETL)
-- EX 1.- NETEJA DE PRODUCTES (DATA QUALITY)

CREATE OR REPLACE TABLE `sprint3_silver.products_clean` AS
SELECT 
  Id AS product_id,
  product_name AS name, 
  SAFE_CAST(price AS FLOAT64) AS price,
  colour,
  weight, 
  SAFE_CAST(SUBSTR(warehouse_id, 4) AS INT64) AS warehouse_id,
  category, 
  brand, 
  cost, 
  launch_date,
FROM `sprint3_bronze.products_raw`;

--

-- EX 2.- CREACIÓ DE TRANSACCIONS NETES (CAPA SILVER)

CREATE OR REPLACE TABLE `sprint3_silver.transactions_clean` AS
SELECT 
  id AS transaction_id,
  card_id, 
  business_id,
  SAFE_CAST(timestamp AS TIMESTAMP) AS timestamp,
  IFNULL(SAFE_CAST(amount AS FLOAT64), 0) AS amount, 
  declined,
  ARRAY(SELECT CAST(TRIM(p_id) AS INT64) FROM UNNEST(SPLIT(product_ids, ',')) AS p_id) AS product_ids,
  user_id,
  SAFE_CAST(lat AS FLOAT64) AS lat,
  SAFE_CAST(longitude AS FLOAT64) AS longitude
FROM `sprint3_bronze.transactions_raw`;

-- 

-- EX 3.- UNIFICACIÓ D'USUARIS (UNION)

CREATE OR REPLACE TABLE `sprint3_silver.users_combined` AS

SELECT 
  id AS user_id,           
  'USA' AS origin,          
  name,
  surname,
  phone,
  email,
  birth_date,
  country,
  city,
  postal_code,
  address
FROM `sprint3_bronze.american_users_raw`

UNION ALL

SELECT 
  id AS user_id,           
  'Europe' AS origin,
  name,
  surname,
  phone,
  email,
  birth_date,
  country,
  city,
  postal_code,
  address
FROM `sprint3_bronze.european_users_raw`;

--

-- EX 4.- MATERIALITZACIO COMPANYIES I TARGETES DE CRÈDIT

CREATE OR REPLACE TABLE `sprint3_silver.companies_clean` AS
SELECT 
  string_field_0 AS company_id,       
  string_field_1 AS company_name,     
  string_field_2 AS phone,         
  string_field_3 AS email,          
  string_field_4 AS country,
  string_field_5 AS web           
FROM `sprint3_bronze.companies_raw`;

CREATE OR REPLACE TABLE `sprint3_silver.credit_cards_clean` AS
SELECT 
  id AS card_id,                    
  user_id,
  iban,
  pan,
  pin,
  cvv,
  track1,
  track2,
  expiring_date,
FROM `sprint3_bronze.credit_cards_raw`;

-- 

-- NIVELL 3: PRESENTACIÓ DE DADES I CREACIÓ DE VISTES
-- EX. 1 LA VISTA DE MÀRQUETING (LÒGICA DE NEGOCI)

CREATE OR REPLACE VIEW `sprint3_gold.v_marketing_kpis` AS 
SELECT 
  cc.company_name, 
  cc.phone, 
  cc.country,
  ROUND(AVG(tc.amount), 2) AS mitjana_import,

  CASE 
    WHEN AVG(tc.amount) > 260 THEN 'Premium'
    ELSE 'Standard'
  END AS client_tier

FROM sprint3_silver.companies_clean AS cc
JOIN sprint3_silver.transactions_clean AS tc 
  on cc.company_id = tc.business_id

WHERE declined = 0

GROUP BY cc.company_name, cc.phone, cc.country;

SELECT *
FROM `sprint3_gold.v_marketing_kpis`
ORDER BY client_tier ASC, mitjana_import DESC;


--

-- EX 2.- RÀNQUING DE PRODUCTES (LA POTÈNCIA ELS ARRAYS)

CREATE OR REPLACE TABLE `sprint3_gold.product_sales_ranking` AS


WITH transactions_polished AS (
  SELECT p_id
  FROM `sprint3_silver.transactions_clean`,
  UNNEST(product_ids) AS p_id
)


SELECT
  pc.product_id,                  
  pc.name,
  pc.price,
  pc.colour,                      
  COUNT(tc.p_id) AS total_sold  


FROM `sprint3_silver.products_clean` AS pc
LEFT JOIN transactions_polished AS tc
  ON pc.product_id = tc.p_id


GROUP BY
  pc.product_id, pc.name, pc.price, pc.colour


ORDER BY total_sold DESC;

-- 

-- EX 3.- EXPORTACIÓ DE RESULTATS

SELECT *
FROM sprint3_gold.product_sales_ranking;