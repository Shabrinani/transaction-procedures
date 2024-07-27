DECLARE @ProductsToAdd dbo.ProductPO;

INSERT INTO @ProductsToAdd (ProductID, Quantity, ReceivedQty, RejectedQty)
VALUES 
    (1, 10, 0, 0), 
    (2, 5, 0, 0);  

EXEC PurchaseOrder
    @EmployeeID = 123,             
    @VendorID = 1492,               
    @Status = 1,                   
    @ProductsToAdd = @ProductsToAdd, 
    @ShipMethodID = 1;           