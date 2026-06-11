-- NIVEL 1
-- 1

SELECT * 
FROM sprint3_silver.transactions_clean AS tc
JOIN sprint3_silver.companies_clean AS cc
  ON(tc.business_id = cc.company_id)
WHERE 1=1
  AND tc.declined = 0
  AND DATE(tc.timestamp) = DATE '2022-03-12'
  AND cc.country = 'Germany';

-- 2

CREATE OR REPLACE TABLE sprint3_silver.transactions_recent AS
SELECT * EXCEPT(`timestamp`),
 TIMESTAMP_SUB(
    CURRENT_TIMESTAMP(), 
    INTERVAL CAST(RAND() * 50 AS INT64) DAY) AS `timestamp`
FROM `sprint3_silver.transactions_clean`;

CREATE OR REPLACE TABLE sprint3_gold.fact_transactions_optimized 
 PARTITION BY DATE(timestamp)
 CLUSTER BY business_id
AS 
  SELECT * 
  FROM sprint3_silver.transactions_recent;
  
  -- 3
  
  SELECT *
FROM sprint3_silver.transactions_recent
WHERE 1=1
  AND DATE(timestamp) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND CURRENT_DATE();
  
  -- 4
  
  CREATE OR REPLACE MATERIALIZED VIEW sprint3_gold.mv_daily_sales AS
SELECT 
  DATE(tc.timestamp) AS Data, 
  SUM(tc.amount) AS Vendes_Totals_Dia 
FROM sprint3_silver.transactions_clean AS tc
GROUP BY DATE(tc.timestamp);

-- NIVEL 2
-- 1

WITH VIP_Stats AS (
SELECT 
  user_id,
  ROUND(SUM(amount), 2) AS Despesa_Total,
  COUNT(transaction_id) AS Quantitat_Transaccions,
  ROUND(AVG(amount), 2) AS Tiquet_Mitja,
  MAX(amount) AS Compra_Maxima
FROM sprint3_silver.transactions_clean
WHERE declined = 0 
GROUP BY user_id
HAVING SUM(amount) > 500)

SELECT *
FROM VIP_Stats;

WITH Vip_Stats AS (
  SELECT 
    user_id,
    SUM(amount) AS Despesa_Total,
    COUNT(transaction_id) AS Quantitat_Transaccions,
    ROUND(AVG(amount), 2) AS Tiquet_Mitja,
    MAX(amount) AS Compra_Maxima
  FROM sprint3_silver.transactions_clean
  WHERE declined = 0 
  GROUP BY user_id
  HAVING SUM(amount) > 500
)

SELECT 
  uc.user_id,
  CONCAT(uc.name, ' ', uc.surname) AS nom_complet,
  uc.email,
  vs.Quantitat_Transaccions AS num_compres,
  vs.Tiquet_Mitja AS tiquet_mig,
  vs.Compra_Maxima AS max_compra,
  ROUND(vs.Despesa_Total, 2) AS total_gastat
FROM Vip_Stats AS vs
JOIN sprint3_silver.users_combined AS uc
USING (user_id)
ORDER BY total_gastat DESC;

-- 2

WITH analisi_tendencies AS (
  SELECT 
    Data,
    ROUND(Vendes_Totals_Dia, 2) AS Vendes_Avui,
    ROUND(LAG(Vendes_Totals_Dia) OVER (ORDER BY Data), 2) AS Vendes_ahir
 FROM sprint3_gold.mv_daily_sales
)

SELECT
  Data,
  Vendes_Avui,
  Vendes_Ahir,
  ROUND(
    SAFE_DIVIDE(
      Vendes_Avui - Vendes_Ahir,
      Vendes_Ahir
    ) * 100,
    2
  ) AS Diff_Percentual
FROM analisi_tendencies
ORDER BY Data;

-- 3

SELECT
  Data,
  ROUND(Vendes_Totals_Dia, 2) AS Vendes_Del_Dia,
  ROUND(
    SUM(Vendes_Totals_Dia) OVER (
      PARTITION BY EXTRACT(YEAR FROM Data)
      ORDER BY Data
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ),
    2
  ) AS Vendes_Acumulades_YTD
FROM sprint3_gold.mv_daily_sales
ORDER BY Data;

-- 4 

WITH tres_compres AS (
  SELECT
    tc.user_id,
    uc.name,
    uc.surname,
    uc.email,
    tc.timestamp AS data_compra,
    tc.amount AS import,
    ROW_NUMBER() OVER (
      PARTITION BY tc.user_id
      ORDER BY tc.timestamp
    ) AS rn
  FROM sprint3_silver.transactions_clean tc
  JOIN sprint3_silver.users_combined uc
    USING (user_id)
)

SELECT
  user_id,
  CONCAT(name, ' ', surname) AS nom_complet,
  email,
  data_compra AS data_tercera_compra,
  import AS import_tercera_compra,
  AVG(import) OVER (PARTITION BY user_id) AS mitjana_3_primers
FROM tres_compres
QUALIFY rn <= 3;

-- NIVEL 3
-- 1

CREATE OR REPLACE TABLE sprint3_gold.dim_transactions_flat AS
SELECT 
  tc.transaction_id,
  tc.user_id, 
  product_id,
  pc.name AS product_name,
  pc.price AS product_price,
FROM sprint3_silver.transactions_clean AS tc
  CROSS JOIN UNNEST(tc.product_ids) AS product_id
  JOIN sprint3_silver.products_clean AS pc
    ON CAST(product_id AS INT64) = pc.product_id;
	
-- 2

SELECT
  product_name,
  COUNT(*) AS unitats_venudes
FROM sprint3_gold.dim_transactions_flat
GROUP BY product_name
ORDER BY unitats_venudes DESC
LIMIT 5;

-- 3

CREATE OR REPLACE FUNCTION sprint3_gold.calculate_tax(amount FLOAT64) 
RETURNS FLOAT64 AS (
  amount * 1.21
);

CREATE OR REPLACE TABLE sprint3_gold.dim_transactions_flat AS
SELECT 
  tc.transaction_id,
  tc.user_id, 
  product_id,
  pc.name,
  pc.price,
  sprint3_gold.calculate_tax(pc.price) AS product_price_tax_inc
FROM sprint3_silver.transactions_clean AS tc
CROSS JOIN UNNEST(tc.product_ids) AS product_id
JOIN sprint3_silver.products_clean AS pc
  ON product_id = CAST(pc.product_id AS INT64);
	