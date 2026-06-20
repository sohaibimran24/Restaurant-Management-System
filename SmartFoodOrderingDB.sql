-- ============================================================
-- Smart Online Food Ordering System
-- Fully Fixed SSMS-Compatible SQL Script
-- ============================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SmartFoodOrderingDB')
BEGIN
    CREATE DATABASE SmartFoodOrderingDB;
END
GO

USE SmartFoodOrderingDB;
GO

-- DROP TABLES
IF OBJECT_ID('dbo.Payment', 'U') IS NOT NULL DROP TABLE dbo.Payment;
IF OBJECT_ID('dbo.Order_Details', 'U') IS NOT NULL DROP TABLE dbo.Order_Details;
IF OBJECT_ID('dbo.Orders', 'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Menu_Item', 'U') IS NOT NULL DROP TABLE dbo.Menu_Item;
IF OBJECT_ID('dbo.Customer', 'U') IS NOT NULL DROP TABLE dbo.Customer;
IF OBJECT_ID('dbo.Restaurant', 'U') IS NOT NULL DROP TABLE dbo.Restaurant;
GO

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE dbo.Restaurant (
    restaurant_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(200) NOT NULL,
    contact_number VARCHAR(20)
);
GO

CREATE TABLE dbo.Customer (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20),
    address VARCHAR(300),
    password_hash VARCHAR(256) NOT NULL
);
GO

CREATE TABLE dbo.Menu_Item (
    item_id INT IDENTITY(1,1) PRIMARY KEY,
    restaurant_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_MenuItem_Restaurant
    FOREIGN KEY (restaurant_id)
    REFERENCES dbo.Restaurant(restaurant_id)
    ON DELETE CASCADE
);
GO

CREATE TABLE dbo.Orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATETIME DEFAULT GETDATE(),
    status VARCHAR(50) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','confirmed','completed','cancelled')),
    total_amount DECIMAL(10,2),
    CONSTRAINT FK_Order_Customer
    FOREIGN KEY (customer_id)
    REFERENCES dbo.Customer(customer_id)
);
GO

CREATE TABLE dbo.Order_Details (
    order_detail_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL,
    item_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    subtotal DECIMAL(10,2),
    CONSTRAINT FK_OrderDetail_Order
    FOREIGN KEY (order_id)
    REFERENCES dbo.Orders(order_id)
    ON DELETE CASCADE,
    CONSTRAINT FK_OrderDetail_MenuItem
    FOREIGN KEY (item_id)
    REFERENCES dbo.Menu_Item(item_id)
);
GO

CREATE TABLE dbo.Payment (
    payment_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL UNIQUE,
    payment_method VARCHAR(50)
        CHECK (payment_method IN ('Cash','Card','JazzCash','EasyPaisa')),
    payment_status VARCHAR(50) NOT NULL DEFAULT 'pending'
        CHECK (payment_status IN ('pending','completed','failed')),
    amount DECIMAL(10,2) NOT NULL,
    payment_date DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Payment_Order
    FOREIGN KEY (order_id)
    REFERENCES dbo.Orders(order_id)
);
GO

-- ============================================================
-- FIXED TRIGGER
-- ============================================================

CREATE OR ALTER TRIGGER trg_UpdateOrderTotal
ON dbo.Order_Details
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE od
    SET subtotal = od.quantity * mi.price
    FROM dbo.Order_Details od
    JOIN dbo.Menu_Item mi ON od.item_id = mi.item_id;

    UPDATE o
    SET total_amount = ISNULL((
        SELECT SUM(subtotal)
        FROM dbo.Order_Details od
        WHERE od.order_id = o.order_id
    ),0)
    FROM dbo.Orders o;
END;
GO

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

CREATE OR ALTER PROCEDURE sp_RegisterCustomer
    @name VARCHAR(100),
    @email VARCHAR(150),
    @phone VARCHAR(20)=NULL,
    @address VARCHAR(300)=NULL,
    @password VARCHAR(256)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Customer WHERE email=@email)
    BEGIN
        RAISERROR('Email already registered.',16,1);
        RETURN;
    END

    INSERT INTO dbo.Customer(name,email,phone,address,password_hash)
    VALUES(@name,@email,@phone,@address,@password);

    SELECT SCOPE_IDENTITY() AS new_customer_id;
END;
GO

CREATE OR ALTER PROCEDURE sp_LoginCustomer
    @email VARCHAR(150),
    @password VARCHAR(256)
AS
BEGIN
    SELECT customer_id,name,email,phone,address
    FROM dbo.Customer
    WHERE email=@email AND password_hash=@password;
END;
GO

CREATE OR ALTER PROCEDURE sp_PlaceOrder
    @customer_id INT,
    @item_ids VARCHAR(MAX),
    @quantities VARCHAR(MAX)
AS
BEGIN
    BEGIN TRANSACTION;

    BEGIN TRY

        INSERT INTO dbo.Orders(customer_id,status)
        VALUES(@customer_id,'pending');

        DECLARE @order_id INT = SCOPE_IDENTITY();

        ;WITH items AS (
            SELECT value item_id,
                   ROW_NUMBER() OVER (ORDER BY (SELECT 1)) rn
            FROM STRING_SPLIT(@item_ids, ',')
        ),
        qtys AS (
            SELECT value quantity,
                   ROW_NUMBER() OVER (ORDER BY (SELECT 1)) rn
            FROM STRING_SPLIT(@quantities, ',')
        )
        INSERT INTO dbo.Order_Details(order_id,item_id,quantity)
        SELECT @order_id,
               CAST(i.item_id AS INT),
               CAST(q.quantity AS INT)
        FROM items i
        JOIN qtys q ON i.rn=q.rn;

        COMMIT TRANSACTION;

        SELECT @order_id AS order_id,
               'Order placed successfully' AS message;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- VIEWS
-- ============================================================

CREATE OR ALTER VIEW vw_OrderSummary AS
SELECT
    o.order_id,
    c.name AS customer_name,
    c.email,
    o.order_date,
    o.status,
    o.total_amount,
    p.payment_method,
    p.payment_status,
    COUNT(od.order_detail_id) AS item_count
FROM dbo.Orders o
JOIN dbo.Customer c ON o.customer_id=c.customer_id
LEFT JOIN dbo.Payment p ON o.order_id=p.order_id
LEFT JOIN dbo.Order_Details od ON o.order_id=od.order_id
GROUP BY
    o.order_id,c.name,c.email,o.order_date,o.status,
    o.total_amount,p.payment_method,p.payment_status;
GO

CREATE OR ALTER VIEW vw_FullMenu AS
SELECT
    mi.item_id,
    r.restaurant_id,
    r.name AS restaurant_name,
    r.location,
    mi.name AS item_name,
    mi.category,
    mi.price
FROM dbo.Menu_Item mi
JOIN dbo.Restaurant r ON mi.restaurant_id=r.restaurant_id;
GO

-- ============================================================
-- SAMPLE DATA
-- ============================================================

INSERT INTO dbo.Restaurant(name,location,contact_number)
VALUES
('Lahori Desi Dhaba','Gulberg, Lahore','042-35761234'),
('Bundu Khan','MM Alam Road, Lahore','042-35761000'),
('Salt n Pepper','DHA Phase 5, Lahore','042-35870000');

INSERT INTO dbo.Menu_Item(restaurant_id,name,category,price)
VALUES
(1,'Nihari','Main',350),
(1,'Paye','Main',300),
(1,'Lassi','Drink',120),
(1,'Naan','Bread',40),
(1,'Kheer','Dessert',150),
(2,'Chicken Tikka','Main',650),
(2,'Seekh Kebab','Main',550),
(2,'Raita','Side',80),
(2,'Roghni Naan','Bread',60),
(2,'Gulab Jamun','Dessert',120),
(3,'Sizzling Chicken','Main',850),
(3,'BBQ Platter','Main',1200);

INSERT INTO dbo.Customer(name,email,phone,address,password_hash)
VALUES
('Ali Hassan','ali@example.com','03001234567','Gulberg',
'HASH123'),
('Sara Ahmed','sara@example.com','03219876543','DHA',
'HASH456');

INSERT INTO dbo.Orders(customer_id,status)
VALUES
(1,'completed'),
(2,'pending');

INSERT INTO dbo.Order_Details(order_id,item_id,quantity)
VALUES
(1,1,2),
(1,4,4),
(1,3,1),
(2,6,1),
(2,9,2);

-- Payments AFTER totals calculated
INSERT INTO dbo.Payment(order_id,payment_method,payment_status,amount)
SELECT 1,'JazzCash','completed',total_amount
FROM dbo.Orders WHERE order_id=1;

INSERT INTO dbo.Payment(order_id,payment_method,payment_status,amount)
SELECT 2,'Cash','pending',total_amount
FROM dbo.Orders WHERE order_id=2;
GO

-- ============================================================
-- VERIFICATION
-- ============================================================

PRINT 'Restaurants';
SELECT * FROM dbo.Restaurant;

PRINT 'Menu';
SELECT * FROM vw_FullMenu;

PRINT 'Customers';
SELECT customer_id,name,email FROM dbo.Customer;

PRINT 'Order Summary';
SELECT * FROM vw_OrderSummary;
GO