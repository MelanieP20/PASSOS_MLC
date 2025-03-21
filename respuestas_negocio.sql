create or replace view MELANIE_DB.MLC.VW_BIRTHDAY_CUSTOMERS_SALES(
	"customer id",
	"customer email",
	"customer first name",
	"customer last name",
	"customer gender",
	"birth date",
	"order final price",
	"payment methods",
	"final payment amount"
) as
WITH customer_cte AS (
    -- Selecting customer details for customers whose birthday is today
    SELECT
        user_id,        -- Customer's unique identifier
        email,          -- Customer's email
        first_name,     -- Customer's first name
        last_name,      -- Customer's last name
        gender,         -- Customer's gender
        birth_date      -- Customer's birth date
    FROM melanie_db.mlc.t_customer
    -- Filter customers whose birth date matches today's date in MM-DD format
    WHERE TO_CHAR(birth_date, 'MM-DD') = TO_CHAR(CURRENT_DATE(),'MM-DD')  
),

order_cte AS (
    -- Summing up the total price of orders for customers in January 2020 with a completed order status
    SELECT 
        user_id,                      -- Customer's unique identifier
        SUM(total_price) AS total_order_price  -- Summing the total price of completed orders for each customer
    FROM melanie_db.mlc.t_order
    -- Filter orders completed in January 2020
    WHERE TO_CHAR(order_date, 'YYYYMM') = '202001' AND order_status = 'completed'
    GROUP BY user_id   -- Group by user_id to get the total for each customer
),

payment_cte AS (
    -- Aggregating payment methods and total payment amount for customers who made paid payments
    SELECT
        user_id,                                    -- Customer's unique identifier
        LISTAGG(DISTINCT payment_method, ', ') WITHIN GROUP (ORDER BY payment_method) AS payment_methods,  -- Concatenate distinct payment methods
        SUM(amount) AS total_payment_amount  -- Summing the total amount paid by each customer
    FROM melanie_db.mlc.t_payment
    -- Filter payments with the status 'paid'
    WHERE payment_status = 'paid'
    GROUP BY user_id   -- Group by user_id to get the total payment amount for each customer
),

final_cte AS (
    -- Combining customer, order, and payment information into a final result
    SELECT
        c.user_id AS "customer id",                -- Customer's unique identifier
        c.email AS "customer email",                -- Customer's email
        c.first_name AS "customer first name",     -- Customer's first name
        c.last_name AS "customer last name",       -- Customer's last name
        c.gender AS "customer gender",             -- Customer's gender
        c.birth_date AS "birth date",              -- Customer's birth date
        o.total_order_price AS "order final price",  -- Total price of completed orders
        p.payment_methods AS "payment methods",    -- Aggregated list of payment methods used by the customer
        p.total_payment_amount AS "final payment amount"  -- Total amount of payments made by the customer
    FROM customer_cte c
    LEFT JOIN order_cte o ON c.user_id = o.user_id  -- Left join with order details
    LEFT JOIN payment_cte p ON c.user_id = p.user_id  -- Left join with payment details
)

-- Selecting only the records where the total order price is greater than or equal to 1500
SELECT * FROM final_cte where "order final price" >= 1500;

--------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW melanie_db.mlc.vw_top5_cellphone_sellers AS

-- Define a Common Table Expression (CTE) to retrieve customer details (user_id, first name, last name)
WITH customer_cte AS (
    SELECT
        user_id,        -- Unique identifier for the customer
        first_name,     -- Customer's first name
        last_name       -- Customer's last name
    FROM melanie_db.mlc.t_customer
),

-- Define a CTE to retrieve order details, summarizing the number of orders, total quantity, and total price per customer/item/month
order_cte AS (
    SELECT 
        user_id,                           -- Unique identifier for the customer
        item_id,                           -- Unique identifier for the item purchased
        order_status,                      -- Status of the order (e.g., completed, pending)
        TO_CHAR(order_date, 'YYYY-MM') AS order_date_by_month,  -- Convert order date to 'YYYY-MM' format
        COUNT(order_id) AS order_count,                  -- Count the number of orders for each customer/item
        SUM(quantity) AS total_quantity,                -- Calculate the total quantity of products ordered
        SUM(total_price) AS total_order_price           -- Calculate the total price of the orders
    FROM melanie_db.mlc.t_order
    -- Filter orders to include only completed orders in the year 2020
    WHERE TO_CHAR(order_date, 'YYYY') = '2020' AND order_status = 'completed'
    GROUP BY user_id, item_id, order_status, order_date_by_month  -- Group by customer, item, order status, and order date
),

-- Define a CTE to summarize payment details, including methods and total payment amounts
payment_cte AS (
    SELECT
        user_id,                                     -- Unique identifier for the customer
        payment_id,                                  -- Unique identifier for each payment
        LISTAGG(payment_method, ',') WITHIN GROUP (ORDER BY payment_id) as payment_methods,  -- Aggregate distinct payment methods into a list
        TO_CHAR(payment_date, 'YYYY-MM') AS payment_date_by_month,  -- Convert payment date to 'YYYY-MM' format
        payment_status,                               -- Status of the payment (e.g., paid, pending)
        SUM(amount) AS total_payment_amount           -- Total amount paid by the customer
    FROM melanie_db.mlc.t_payment p
    -- Filter payments to include only those with a 'paid' status
    WHERE p.payment_status = 'paid'
    GROUP BY user_id, payment_id, payment_date_by_month, payment_status  -- Group by customer, payment, and payment date
),

-- Define a CTE to retrieve item category details
item_cte AS (
    SELECT 
        item_id,       -- Unique identifier for the item
        catg_id        -- Category identifier for the item
    FROM melanie_db.mlc.t_item
),

-- Define a CTE to retrieve category details
category_cte AS (
    SELECT 
        catg_id,               -- Category identifier
        child_catg_name,       -- Name of the child category
        catg_path              -- Path of the category hierarchy
    FROM melanie_db.mlc.t_category t
),

-- Define the final CTE to join all the previous CTEs together and compute ranking based on order price
final_cte AS (
    SELECT
        c.user_id AS "user id",                       -- Customer's unique identifier
        c.first_name AS "customer first name",        -- Customer's first name
        c.last_name AS "customer last name",          -- Customer's last name
        o.order_status AS "order status",             -- Status of the order (e.g., completed)
        o.order_date_by_month AS "sell date",         -- Month when the order was made
        o.order_count AS "sell amount",               -- Number of orders placed by the customer
        o.total_quantity AS "product quantity sold",  -- Total quantity of products sold to the customer
        o.total_order_price AS "total order price",   -- Total price of all orders placed
        t.catg_id as "category id",                   -- Category ID of the item
        t.child_catg_name as "category name",         -- Name of the category
        t.catg_path as "category path",               -- Category path in the hierarchy
        o.item_id as "item_id",                       -- Unique identifier for the item
        p.payment_methods AS "payment methods",       -- List of payment methods used by the customer
        p.payment_status AS "payment status",         -- Status of the payment (e.g., paid)
        p.total_payment_amount AS "total payment amount",  -- Total amount paid by the customer
        ROW_NUMBER() OVER (PARTITION BY o.order_date_by_month ORDER BY o.total_order_price DESC) AS rank  -- Assign a rank to orders based on total price
    FROM customer_cte c
    LEFT JOIN order_cte o ON c.user_id = o.user_id     -- Join customer data with order data
    LEFT JOIN item_cte i ON o.item_id = i.item_id      -- Join order data with item data
    LEFT JOIN category_cte t ON i.catg_id = t.catg_id  -- Join item data with category data
    LEFT JOIN payment_cte p ON c.user_id = p.user_id AND o.order_date_by_month = p.payment_date_by_month  -- Join customer data with payment data
)

-- Select the top 5 sellers (rank <= 5) based on order price for each month
SELECT * 
FROM final_cte 
WHERE rank <= 5  -- Filter to include only the top 5 sellers based on order price
ORDER BY "sell date", rank;  -- Order the results by sell date and rank

--------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE MELANIE_DB.MLC.USP_ITEM_STATUS_HISTORY()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS '
BEGIN
  -- Insert historical data for all items in t_item that do not yet exist in t_item_status_history
  -- This will insert item_id, unit price, item status, and the creation timestamp for those items
  INSERT INTO t_item_status_history (item_id, price, status, record_date)
  SELECT
    item_id,                              -- Item identifier
    unite_price AS price,                  -- Unit price of the item
    item_status AS status,                 -- Current status of the item
    CREATED_AT AS record_date              -- Creation timestamp for when the item was added
  FROM
    melanie_db.mlc.t_item
  WHERE
    NOT EXISTS (                           -- Check if the item does not already exist in t_item_status_history
      SELECT 1
      FROM t_item_status_history
    );

  -- Insert historical data for items that have been updated (if the price or status has changed)
  -- This will insert item_id, unit price, item status, and the creation timestamp for those items
  INSERT INTO t_item_status_history (item_id, price, status, record_date)
  SELECT
    item_id,                              -- Item identifier
    unite_price AS price,                  -- Unit price of the item
    item_status AS status,                 -- Current status of the item
    CREATED_AT AS record_date              -- Creation timestamp for when the item was added
  FROM
    melanie_db.mlc.t_item
  WHERE
    EXISTS (                               -- Check if the item already exists in t_item_status_history
      SELECT 1
      FROM t_item_status_history
      WHERE t_item_status_history.item_id = t_item.item_id  -- Match item_id with the status history table
      AND (
        t_item_status_history.price != t_item.unite_price  -- Check if the price is different from the previous record
        OR
        t_item_status_history.status != t_item.item_status -- Check if the status is different from the previous record
      )
    );

  -- Return a success message after successfully inserting the historical data
  RETURN ''History successfully updated'';
END;
';
