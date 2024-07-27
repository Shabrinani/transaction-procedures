CREATE TYPE dbo.ProductList AS TABLE (
	SalesOrderDetailID INT PRIMARY KEY IDENTITY(1,1), 
    ProductID INT,
    Quantity INT
);