CREATE TYPE dbo.ProductPO AS TABLE (
	PurchaseOrderDetailID INT PRIMARY KEY IDENTITY(1,1), 
    ProductID INT,
    Quantity INT,
	ReceivedQty DECIMAl(8,2),
	RejectedQty DECIMAL(8,2)
);