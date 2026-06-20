-- ============================================
-- Restaurant Management System
-- Author: Muhammad Sohaib Imran
-- FAST-NUCES, Lahore | FinTech
-- Database: Microsoft SQL Server
-- ============================================

-- ─── CREATE DATABASE ──────────────────────────────────────────
CREATE DATABASE RestaurantDB;
GO

USE RestaurantDB;
GO

-- ─── TABLES ───────────────────────────────────────────────────

-- Categories Table
CREATE TABLE Categories (
    CategoryID   INT PRIMARY KEY IDENTITY(1,1),
    CategoryName VARCHAR(100) NOT NULL,
    Description  VARCHAR(255)
);

-- Menu Items Table
CREATE TABLE MenuItems (
    ItemID       INT PRIMARY KEY IDENTITY(1,1),
    CategoryID   INT FOREIGN KEY REFERENCES Categories(CategoryID),
    ItemName     VARCHAR(100) NOT NULL,
    Description  VARCHAR(255),
    Price        DECIMAL(10,2) NOT NULL,
    IsAvailable  BIT DEFAULT 1,
    CreatedAt    DATETIME DEFAULT GETDATE()
);

-- Tables Table (Restaurant Seating)
CREATE TABLE Tables (
    TableID      INT PRIMARY KEY IDENTITY(1,1),
    TableNumber  INT NOT NULL UNIQUE,
    Capacity     INT NOT NULL,
    Status       VARCHAR(20) DEFAULT 'Available'  -- Available, Occupied, Reserved
);

-- Customers Table
CREATE TABLE Customers (
    CustomerID   INT PRIMARY KEY IDENTITY(1,1),
    FullName     VARCHAR(100) NOT NULL,
    Phone        VARCHAR(20),
    Email        VARCHAR(100),
    CreatedAt    DATETIME DEFAULT GETDATE()
);

-- Orders Table
CREATE TABLE Orders (
    OrderID      INT PRIMARY KEY IDENTITY(1,1),
    TableID      INT FOREIGN KEY REFERENCES Tables(TableID),
    CustomerID   INT FOREIGN KEY REFERENCES Customers(CustomerID),
    OrderDate    DATETIME DEFAULT GETDATE(),
    Status       VARCHAR(20) DEFAULT 'Pending',  -- Pending, Preparing, Served, Paid, Cancelled
    TotalAmount  DECIMAL(10,2) DEFAULT 0,
    Notes        VARCHAR(255)
);

-- Order Items Table
CREATE TABLE OrderItems (
    OrderItemID  INT PRIMARY KEY IDENTITY(1,1),
    OrderID      INT FOREIGN KEY REFERENCES Orders(OrderID),
    ItemID       INT FOREIGN KEY REFERENCES MenuItems(ItemID),
    Quantity     INT NOT NULL,
    UnitPrice    DECIMAL(10,2) NOT NULL,
    Subtotal     AS (Quantity * UnitPrice) PERSISTED  -- Computed Column
);

-- Bills Table
CREATE TABLE Bills (
    BillID       INT PRIMARY KEY IDENTITY(1,1),
    OrderID      INT FOREIGN KEY REFERENCES Orders(OrderID),
    BillDate     DATETIME DEFAULT GETDATE(),
    SubTotal     DECIMAL(10,2),
    TaxRate      DECIMAL(5,2) DEFAULT 16.00,  -- 16% GST Pakistan
    TaxAmount    DECIMAL(10,2),
    TotalAmount  DECIMAL(10,2),
    PaymentMethod VARCHAR(20) DEFAULT 'Cash',  -- Cash, Card, Online
    IsPaid       BIT DEFAULT 0
);

-- Staff Table
CREATE TABLE Staff (
    StaffID      INT PRIMARY KEY IDENTITY(1,1),
    FullName     VARCHAR(100) NOT NULL,
    Role         VARCHAR(50),  -- Waiter, Chef, Manager, Cashier
    Phone        VARCHAR(20),
    HireDate     DATE DEFAULT GETDATE(),
    IsActive     BIT DEFAULT 1
);
GO

-- ─── SAMPLE DATA ──────────────────────────────────────────────

-- Categories
INSERT INTO Categories (CategoryName, Description) VALUES
('Starters',    'Appetizers and starters'),
('Main Course', 'Main dishes and entrees'),
('Drinks',      'Hot and cold beverages'),
('Desserts',    'Sweet dishes and desserts'),
('Fast Food',   'Burgers, fries and snacks');

-- Menu Items
INSERT INTO MenuItems (CategoryID, ItemName, Description, Price) VALUES
(1, 'Chicken Soup',        'Hot chicken broth with vegetables',     250.00),
(1, 'Spring Rolls',        'Crispy vegetable spring rolls (6 pcs)', 300.00),
(2, 'Chicken Karahi',      'Traditional spicy chicken karahi',      950.00),
(2, 'Mutton Biryani',      'Aromatic mutton biryani with raita',    750.00),
(2, 'Grilled Fish',        'Grilled fish with garlic butter sauce', 850.00),
(2, 'Vegetable Pasta',     'Creamy pasta with mixed vegetables',    550.00),
(3, 'Mint Lemonade',       'Fresh mint and lemon drink',            200.00),
(3, 'Mango Shake',         'Fresh mango milkshake',                 250.00),
(3, 'Green Tea',           'Premium green tea',                     150.00),
(4, 'Gulab Jamun',         'Soft gulab jamun in sugar syrup (4pcs)',200.00),
(4, 'Chocolate Brownie',   'Warm brownie with ice cream',           350.00),
(5, 'Zinger Burger',       'Crispy chicken zinger burger',          450.00),
(5, 'French Fries',        'Crispy salted french fries',            200.00);

-- Tables
INSERT INTO Tables (TableNumber, Capacity, Status) VALUES
(1, 2,  'Available'),
(2, 4,  'Available'),
(3, 4,  'Available'),
(4, 6,  'Available'),
(5, 6,  'Available'),
(6, 8,  'Available'),
(7, 10, 'Available');

-- Customers
INSERT INTO Customers (FullName, Phone, Email) VALUES
('Ahmed Khan',    '0300-1234567', 'ahmed@email.com'),
('Sara Ali',      '0311-2345678', 'sara@email.com'),
('Usman Tariq',   '0321-3456789', 'usman@email.com'),
('Fatima Malik',  '0333-4567890', 'fatima@email.com');

-- Staff
INSERT INTO Staff (FullName, Role, Phone) VALUES
('Bilal Ahmed',   'Manager',  '0300-9876543'),
('Kamran Ali',    'Chef',     '0311-8765432'),
('Zara Khan',     'Waiter',   '0321-7654321'),
('Hassan Raza',   'Cashier',  '0333-6543210');
GO

-- ─── STORED PROCEDURES ────────────────────────────────────────

-- Place a New Order
CREATE PROCEDURE PlaceOrder
    @TableID    INT,
    @CustomerID INT,
    @Notes      VARCHAR(255) = NULL
AS
BEGIN
    INSERT INTO Orders (TableID, CustomerID, Notes)
    VALUES (@TableID, @CustomerID, @Notes);

    UPDATE Tables SET Status = 'Occupied' WHERE TableID = @TableID;

    SELECT SCOPE_IDENTITY() AS NewOrderID;
END;
GO

-- Add Item to Order
CREATE PROCEDURE AddOrderItem
    @OrderID  INT,
    @ItemID   INT,
    @Quantity INT
AS
BEGIN
    DECLARE @Price DECIMAL(10,2);
    SELECT @Price = Price FROM MenuItems WHERE ItemID = @ItemID;

    INSERT INTO OrderItems (OrderID, ItemID, Quantity, UnitPrice)
    VALUES (@OrderID, @ItemID, @Quantity, @Price);

    -- Update order total
    UPDATE Orders
    SET TotalAmount = (SELECT SUM(Subtotal) FROM OrderItems WHERE OrderID = @OrderID)
    WHERE OrderID = @OrderID;
END;
GO

-- Generate Bill
CREATE PROCEDURE GenerateBill
    @OrderID       INT,
    @PaymentMethod VARCHAR(20) = 'Cash'
AS
BEGIN
    DECLARE @SubTotal   DECIMAL(10,2);
    DECLARE @TaxRate    DECIMAL(5,2) = 16.00;
    DECLARE @TaxAmount  DECIMAL(10,2);
    DECLARE @Total      DECIMAL(10,2);

    SELECT @SubTotal = TotalAmount FROM Orders WHERE OrderID = @OrderID;
    SET @TaxAmount = (@SubTotal * @TaxRate) / 100;
    SET @Total = @SubTotal + @TaxAmount;

    INSERT INTO Bills (OrderID, SubTotal, TaxRate, TaxAmount, TotalAmount, PaymentMethod, IsPaid)
    VALUES (@OrderID, @SubTotal, @TaxRate, @TaxAmount, @Total, @PaymentMethod, 1);

    UPDATE Orders SET Status = 'Paid' WHERE OrderID = @OrderID;
    UPDATE Tables SET Status = 'Available'
    WHERE TableID = (SELECT TableID FROM Orders WHERE OrderID = @OrderID);

    -- Print Bill Summary
    SELECT
        o.OrderID,
        c.FullName      AS Customer,
        t.TableNumber   AS [Table],
        @SubTotal       AS SubTotal,
        @TaxRate        AS [Tax %],
        @TaxAmount      AS TaxAmount,
        @Total          AS TotalBill,
        @PaymentMethod  AS PaymentMethod
    FROM Orders o
    JOIN Customers c ON o.CustomerID = c.CustomerID
    JOIN Tables t    ON o.TableID    = t.TableID
    WHERE o.OrderID = @OrderID;
END;
GO

-- ─── VIEWS ────────────────────────────────────────────────────

-- Full Order Details View
CREATE VIEW vw_OrderDetails AS
SELECT
    o.OrderID,
    o.OrderDate,
    o.Status         AS OrderStatus,
    t.TableNumber,
    c.FullName       AS CustomerName,
    c.Phone,
    mi.ItemName,
    cat.CategoryName,
    oi.Quantity,
    oi.UnitPrice,
    oi.Subtotal,
    o.TotalAmount
FROM Orders o
JOIN Tables      t   ON o.TableID    = t.TableID
JOIN Customers   c   ON o.CustomerID = c.CustomerID
JOIN OrderItems  oi  ON o.OrderID    = oi.OrderID
JOIN MenuItems   mi  ON oi.ItemID    = mi.ItemID
JOIN Categories  cat ON mi.CategoryID= cat.CategoryID;
GO

-- Daily Sales Summary View
CREATE VIEW vw_DailySales AS
SELECT
    CAST(o.OrderDate AS DATE) AS SaleDate,
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    SUM(b.SubTotal)           AS SubTotal,
    SUM(b.TaxAmount)          AS TotalTax,
    SUM(b.TotalAmount)        AS TotalRevenue
FROM Orders o
JOIN Bills b ON o.OrderID = b.OrderID
WHERE b.IsPaid = 1
GROUP BY CAST(o.OrderDate AS DATE);
GO

-- Menu Popularity View
CREATE VIEW vw_MenuPopularity AS
SELECT
    mi.ItemName,
    cat.CategoryName,
    mi.Price,
    SUM(oi.Quantity)   AS TotalOrdered,
    SUM(oi.Subtotal)   AS TotalRevenue
FROM OrderItems oi
JOIN MenuItems  mi  ON oi.ItemID    = mi.ItemID
JOIN Categories cat ON mi.CategoryID= cat.CategoryID
GROUP BY mi.ItemName, cat.CategoryName, mi.Price;
GO

-- ─── SAMPLE QUERIES ───────────────────────────────────────────

-- View full menu by category
SELECT cat.CategoryName, mi.ItemName, mi.Price, mi.IsAvailable
FROM MenuItems mi
JOIN Categories cat ON mi.CategoryID = cat.CategoryID
ORDER BY cat.CategoryName, mi.Price;

-- View all available tables
SELECT TableNumber, Capacity, Status
FROM Tables
WHERE Status = 'Available'
ORDER BY TableNumber;

-- Place a sample order (Table 2, Customer 1)
EXEC PlaceOrder @TableID = 2, @CustomerID = 1, @Notes = 'Less spicy please';

-- Add items to order 1
EXEC AddOrderItem @OrderID = 1, @ItemID = 3, @Quantity = 2;  -- 2x Chicken Karahi
EXEC AddOrderItem @OrderID = 1, @ItemID = 7, @Quantity = 2;  -- 2x Mint Lemonade
EXEC AddOrderItem @OrderID = 1, @ItemID = 10, @Quantity = 1; -- 1x Gulab Jamun

-- View order details
SELECT * FROM vw_OrderDetails WHERE OrderID = 1;

-- Generate bill for order 1
EXEC GenerateBill @OrderID = 1, @PaymentMethod = 'Cash';

-- View daily sales
SELECT * FROM vw_DailySales;

-- View most popular menu items
SELECT TOP 5 * FROM vw_MenuPopularity ORDER BY TotalOrdered DESC;

-- Total revenue today
SELECT SUM(TotalAmount) AS TodayRevenue
FROM Bills
WHERE CAST(BillDate AS DATE) = CAST(GETDATE() AS DATE)
AND IsPaid = 1;
