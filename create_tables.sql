CREATE OR REPLACE TABLE t_payment (
    payment_id INT PRIMARY KEY, -- unique payment indicator
    order_id INT NOT NULL, --order identifier
    user_id INT NOT NULL, --user identifier
    payment_method VARCHAR(50) NOT NULL, --payment method for example: card, pix, boleto/factura, mercado pago
    payment_status VARCHAR(50) NOT NULL, --payment status for example: refused, paid
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP, --payment date, timestamp based on user timezone
    amount DECIMAL (10, 2) NOT NULL, --purchase amount
    CONSTRAINT fk_order FOREIGN KEY (order_id) REFERENCES t_order(order_id),
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES t_customer(user_id)
);

CREATE OR REPLACE TABLE t_customer(
    user_id INT PRIMARY KEY, --unique user identifier, if the application does not have an unique identifier use AUTO_INCREMENTED
    email VARCHAR (255) NOT NULL, --user email
    first_name VARCHAR (100) NOT NULL, --user first name
    last_name VARCHAR (100) NOT NULL, --user last name
    user_address VARCHAR (255), --user address
    gender VARCHAR (30), --user gender for example: male, female, non-binary, agender, prefere not to say, ...
    birth_date DATE, --user birth date
    phone_number VARCHAR (20), --user phone number, must use varchar for formating and phone numerbers starting with 0
    country VARCHAR (15), -- user account country based
    country_code VARCHAR(10) -- user account country code based

);

CREATE OR REPLACE TABLE t_order(
    order_id INT PRIMARY KEY, --unique order identifier
    user_id INT NOT NULL, --user identifier
    item_id NUMBER NOT NULL, --item identifier
    quantity INT NOT NULL, --item quantity sold
    unite_price DECIMAL (10,2),--item unite price
    total_price DECIMAL (10,2),--total price based on how much of the item has been sold (unite_price * quantity)
    payment_id NUMBER NOT NULL, --payment identifier
    order_status VARCHAR (50), --current order status for example: pending, completed, canceled
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP, --order generated date, timestamp based on user timezone
    CONSTRAINT fk_item FOREIGN KEY (item_id) REFERENCES t_item(item_id),
    CONSTRAINT fk_payment FOREIGN KEY (payment_id) REFERENCES t_payment(payment_id),
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES t_customer(user_id)
);

CREATE OR REPLACE TABLE t_category(
    catg_id INT PRIMARY KEY, --unique category identifier
    parent_catg_name VARCHAR(255), --parent category name
    parent_catg_description TEXT, --parent detailed category description
    child_catg_name VARCHAR(255), --child category name
    child_catg_description TEXT, --child detailed category description    
    catg_path VARCHAR (255), --hierarchy category path
    parent_catg_id NUMBER, --parent category reference (NULL for parent)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP --creation category timestamp
);

CREATE OR REPLACE TABLE t_item(
    item_id INT PRIMARY KEY, --unique item identifier
    item_name VARCHAR(255), --item name
    catg_id NUMBER NOT NULL, --associated category identifier
    unite_price DECIMAL(10,2) NOT NULL, --unite price for item
    item_description  TEXT, --detailed item description
    item_status VARCHAR(50), --item status for example: active, deactive
    termination_date DATE, --termination date from item
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, --creation item timestamp,
    CONSTRAINT fk_category FOREIGN KEY (catg_id) REFERENCES t_category(catg_id)
);

CREATE OR REPLACE TABLE t_item_status_history (
    item_id INT NOT NULL, -- unique item identifier
    price DECIMAL(10,2) NOT NULL, --item price in the register moment
    status VARCHAR(50) NOT NULL, --item status for example: active, inactive
    record_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,-- history item timestamp
    CONSTRAINT fk_item FOREIGN KEY (item_id) REFERENCES t_item(item_id)  
);