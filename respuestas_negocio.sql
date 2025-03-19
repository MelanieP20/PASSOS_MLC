
CREATE OR REPLACE VIEW melanie_db.mlc.vw_birthday_customers_sales AS
WITH customer_cte AS (
    SELECT
        user_id,
        email,
        first_name,
        last_name,
        gender,
        birth_date
    FROM melanie_db.mlc.t_customer
    WHERE TO_CHAR(birth_date, 'MM-DD') = TO_CHAR(CURRENT_DATE(),'MM-DD')  
),

order_cte AS (
    SELECT 
        user_id,
        SUM(total_price) AS total_order_price  
    FROM melanie_db.mlc.t_order
    WHERE TO_CHAR(order_date, 'YYYYMM') = '202001' AND order_status = 'completed'
    GROUP BY user_id
),

payment_cte AS (
    SELECT
        user_id,
        LISTAGG(DISTINCT payment_method, ', ') WITHIN GROUP (ORDER BY payment_method) AS payment_methods, 
        SUM(amount) AS total_payment_amount 
    FROM melanie_db.mlc.t_payment
    WHERE payment_status = 'paid'
    GROUP BY user_id
),

final_cte AS (
    SELECT
        c.user_id AS "customer id",
        c.email AS "customer email",
        c.first_name AS "customer first name",
        c.last_name AS "customer last name",
        c.gender AS "customer gender",
        c.birth_date AS "birth date",
        o.total_order_price AS "order final price",
        p.payment_methods AS "payment methods",  
        p.total_payment_amount AS "final payment amount"  
    FROM customer_cte c
    LEFT JOIN order_cte o ON c.user_id = o.user_id
    LEFT JOIN payment_cte p ON c.user_id = p.user_id
)

SELECT * FROM final_cte;
--------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW melanie_db.mlc.vw_top5_cellphone_sellers AS
WITH customer_cte AS (
    SELECT
        user_id,
        first_name,
        last_name
    FROM melanie_db.mlc.t_customer
),

order_cte AS (
    SELECT 
        user_id,
        item_id,  
        order_status,
        TO_CHAR(order_date, 'YYYY-MM') AS order_date_by_month, 
        COUNT(order_id) AS order_count, 
        SUM(quantity) AS total_quantity,  
        SUM(total_price) AS total_order_price  
    FROM melanie_db.mlc.t_order
    WHERE TO_CHAR(order_date, 'YYYY') = '2020' AND order_status = 'completed'
    GROUP BY user_id, item_id, order_status, order_date_by_month
),

payment_cte AS (
    SELECT
        user_id,
        payment_id,
        LISTAGG(payment_method, ',') WITHIN GROUP (ORDER BY payment_id) as payment_methods,  
        TO_CHAR(payment_date, 'YYYY-MM') AS payment_date_by_month,  
        payment_status,  
        SUM(amount) AS total_payment_amount  
    FROM melanie_db.mlc.t_payment p
    WHERE p.payment_status = 'paid'
    GROUP BY user_id, payment_id, payment_date_by_month, payment_status
),

item_cte AS (
    SELECT 
        item_id,
        catg_id
    FROM melanie_db.mlc.t_item
),

category_cte AS (
    SELECT 
        catg_id,
        child_catg_name,
        catg_path
    FROM melanie_db.mlc.t_category t
),

final_cte AS (
    SELECT
        c.user_id AS "user id",
        c.first_name AS "customer first name",
        c.last_name AS "customer last name",
        o.order_status AS "order status", 
        o.order_date_by_month AS "sell date",  
        o.order_count AS "sell amount",  
        o.total_quantity AS "product quantity sold",  
        o.total_order_price AS "total order price",
        t.catg_id as "category id",  
        t.child_catg_name as "category name",  
        t.catg_path as "category path",  
        o.item_id as "item_id",  
        p.payment_methods AS "payment methods",  
        p.payment_status AS "payment status",  
        p.total_payment_amount AS "total payment amount",  
        ROW_NUMBER() OVER (PARTITION BY o.order_date_by_month ORDER BY o.total_order_price DESC) AS rank
    FROM customer_cte c
    LEFT JOIN order_cte o ON c.user_id = o.user_id  
    LEFT JOIN item_cte i ON o.item_id = i.item_id  
    LEFT JOIN category_cte t ON i.catg_id = t.catg_id  
    LEFT JOIN payment_cte p ON c.user_id = p.user_id AND o.order_date_by_month = p.payment_date_by_month 
)

SELECT * 
FROM final_cte 
WHERE rank <= 5  
ORDER BY "sell date", rank;

-------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE usp_item_status_history()
  RETURNS STRING
  LANGUAGE SQL
  EXECUTE AS OWNER
AS
$$
BEGIN
  -- Inserir o histórico do item, baseado na tabela t_item
  INSERT INTO t_item_status_history (item_id, price, status, record_date)
  SELECT
    item_id,
    unite_price AS price,
    item_status AS status,
    CURRENT_TIMESTAMP AS record_date
  FROM
    melanie_db.mlc.t_item
  WHERE
    -- Verifica se o item foi atualizado desde a última vez
    created_at > (SELECT MAX(record_date) FROM t_item_status_history WHERE item_id = t_item.item_id);

  RETURN 'Histórico inserido com sucesso';
END;
$$;

--------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE usp_item_status_history()
  RETURNS STRING
  LANGUAGE SQL
  EXECUTE AS OWNER
AS
$$
BEGIN
  -- Inserir histórico para todos os itens na t_item, se ainda não existe na t_item_status_history
  INSERT INTO t_item_status_history (item_id, price, status, record_date)
  SELECT
    item_id,
    unite_price AS price,
    item_status AS status,
    CREATED_AT AS record_date
  FROM
    melanie_db.mlc.t_item
  WHERE
    NOT EXISTS (
      SELECT 1
      FROM t_item_status_history
    );

  -- Inserir histórico de itens atualizados (preço ou status alterado)
  INSERT INTO t_item_status_history (item_id, price, status, record_date)
  SELECT
    item_id,
    unite_price AS price,
    item_status AS status,
    CREATED_AT AS record_date
  FROM
    melanie_db.mlc.t_item
  WHERE
    EXISTS (
      SELECT 1
      FROM t_item_status_history
      WHERE t_item_status_history.item_id = t_item.item_id
      AND (
        t_item_status_history.price != t_item.unite_price OR
        t_item_status_history.status != t_item.item_status
      )
    );

  RETURN 'Histórico inserido com sucesso';
END;
$$;

