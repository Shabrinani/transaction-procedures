ALTER PROCEDURE PurchaseOrder
    @EmployeeID INT,
    @VendorID INT,
    @Status INT,
    @ProductsToAdd dbo.ProductPO READONLY,
    @ShipMethodID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Acquire exclusive locks on tables
    SELECT 1 FROM Purchasing.PurchaseOrderHeader WITH (TABLOCKX);
    SELECT 1 FROM Purchasing.PurchaseOrderDetail WITH (TABLOCKX);
    SELECT 1 FROM Production.ProductInventory WITH (TABLOCKX);

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @ProductID INT;
        DECLARE @OrderQty INT;
        DECLARE @ReceivedQty INT;
        DECLARE @RejectedQty INT;
        DECLARE @UnitPrice MONEY;
        DECLARE @SubTotal MONEY = 0;
        DECLARE @Freight MONEY = 0;
        DECLARE @ShipBase MONEY;
        DECLARE @ShipRate MONEY;
        DECLARE @PurchaseOrderID INT;
        DECLARE @InventoryQuantity INT;
        DECLARE @ReorderPoint INT;
        DECLARE @ProductName NVARCHAR(50);

        -- Loop through each product in @ProductsToAdd to check reorder point
        DECLARE check_cursor CURSOR FOR
        SELECT ProductID, Quantity
        FROM @ProductsToAdd;

        OPEN check_cursor;
        FETCH NEXT FROM check_cursor INTO @ProductID, @OrderQty;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Get current inventory quantity and reorder point
            SELECT 
                @InventoryQuantity = pi.Quantity,
                @ReorderPoint = p.ReorderPoint
            FROM Production.ProductInventory pi
            JOIN Production.Product p ON pi.ProductID = p.ProductID
            WHERE pi.ProductID = @ProductID;

            -- Check if inventory quantity is less than or equal to reorder point
            IF @InventoryQuantity > @ReorderPoint
            BEGIN
                -- Rollback and throw an error if condition is not met
                CLOSE check_cursor;
                DEALLOCATE check_cursor;
                ROLLBACK TRANSACTION;
                RAISERROR('The quantity of product %s (ID: %d) in inventory is greater than the reorder point.', 16, 1, @ProductName, @ProductID);
                RETURN;
            END

            FETCH NEXT FROM check_cursor INTO @ProductID, @OrderQty;
        END

        CLOSE check_cursor;
        DEALLOCATE check_cursor;

        -- Insert into PurchaseOrderHeader
        INSERT INTO Purchasing.PurchaseOrderHeader
        (
            RevisionNumber,
            Status,
            EmployeeID,
            VendorID,
            ShipMethodID,
            ShipDate
        )
        VALUES
        (
            dbo.GetNewRevisionNumberPO(@PurchaseOrderID),
            @Status,
            @EmployeeID,
            @VendorID,
            @ShipMethodID,
            DATEADD(DAY, 9, GETDATE())
        );

        -- Get the PurchaseOrderID of the newly inserted record
        SET @PurchaseOrderID = SCOPE_IDENTITY();

        -- Get ShipBase and ShipRate
        SELECT 
            @ShipBase = sm.ShipBase,
            @ShipRate = sm.ShipRate
        FROM Purchasing.ShipMethod sm
        WHERE sm.ShipMethodID = @ShipMethodID;

        -- Loop through each product in @ProductsToAdd
        DECLARE product_cursor CURSOR FOR
        SELECT 
            ProductID, 
            Quantity,
            ReceivedQty,
            RejectedQty
        FROM @ProductsToAdd;

        OPEN product_cursor;
        FETCH NEXT FROM product_cursor INTO @ProductID, @OrderQty, @ReceivedQty, @RejectedQty;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Get product unit price
            SELECT @UnitPrice = p.ListPrice
            FROM Production.Product p
            WHERE p.ProductID = @ProductID;

            -- Calculate freight and line total
            SET @Freight = @Freight + (@ShipBase + (@ShipRate * @OrderQty));
            SET @SubTotal = @SubTotal + (@OrderQty * @UnitPrice);

            -- Insert into PurchaseOrderDetail
            INSERT INTO Purchasing.PurchaseOrderDetail
            (
                PurchaseOrderID,
                DueDate,
                OrderQty,
                ProductID,
                UnitPrice,
                ReceivedQty,
                RejectedQty
            )
            VALUES
            (
                @PurchaseOrderID,
                DATEADD(DAY, 14, GETDATE()),
                @OrderQty,
                @ProductID,
                @UnitPrice,
                @ReceivedQty,
                @RejectedQty
            );

            -- Update ProductInventory
            UPDATE Production.ProductInventory 
            SET Quantity = Quantity + @OrderQty,
			ModifiedDate = GETDATE()
            WHERE ProductID = @ProductID;

            FETCH NEXT FROM product_cursor INTO @ProductID, @OrderQty, @ReceivedQty, @RejectedQty;
        END

        CLOSE product_cursor;
        DEALLOCATE product_cursor;

        -- Update PurchaseOrderHeader with calculated values
        UPDATE Purchasing.PurchaseOrderHeader
        SET SubTotal = @SubTotal,
            Freight = @Freight
        WHERE PurchaseOrderID = @PurchaseOrderID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
