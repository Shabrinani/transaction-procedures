USE AdventureWorks2012;
DECLARE @CustomerID INT = 123; 
DECLARE @Status INT = 1; 
DECLARE @BillToAddressID INT = 456; 
DECLARE @ShipToAddressID INT = 789; 
DECLARE @ShipMethodID INT = 1; 
DECLARE @Comment NVARCHAR(128) = 'Pesanan online baru'; 

-- Data produk yang akan dipesan
DECLARE @ProductsToAdd dbo.ProductList;
INSERT INTO @ProductsToAdd (ProductID, Quantity)
VALUES
    (999, 5), 
    (998, 5); 

-- Eksekusi stored procedure OnlineOrder
EXEC OnlineOrder
    @CustomerID,
    @Status,
    @ProductsToAdd,
    @BillToAddressID,
    @ShipToAddressID,
    @ShipMethodID,
    @Comment;
