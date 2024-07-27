ALTER PROCEDURE OnlineOrder
    @CustomerID INT,
    @Status INT,
    @ProductsToAdd dbo.ProductList READONLY,
    @BillToAddressID INT,
    @ShipToAddressID INT,
    @ShipMethodID INT,
    @Comment NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

	-- Acquire exclusive locks on tables
    SELECT 1 FROM Sales.SalesOrderHeader WITH (TABLOCKX);
    SELECT 1 FROM Sales.SalesOrderDetail WITH (TABLOCKX);
    SELECT 1 FROM Production.ProductInventory WITH (TABLOCKX);

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @AccountNumber NVARCHAR(15);
        DECLARE @CreditCardID INT;
        DECLARE @ProductID INT;
        DECLARE @OrderQty INT;
        DECLARE @UnitPrice MONEY;
        DECLARE @UnitPriceDiscount MONEY;
		DECLARE @SpecialOfferID INT;
        DECLARE @SubTotal MONEY = 0;
        DECLARE @Freight MONEY = 0;
        DECLARE @ShipBase MONEY;
        DECLARE @ShipRate MONEY;
        DECLARE @SalesOrderID INT;

        -- Get credit card ID
        SELECT @CreditCardID = pc.CreditCardID
        FROM Sales.PersonCreditCard pc
        JOIN Person.Person p ON pc.BusinessEntityID = p.BusinessEntityID
        JOIN Sales.Customer c ON p.BusinessEntityID = c.CustomerID
        WHERE c.CustomerID = @CustomerID;

        -- Insert into SalesOrderHeader
        INSERT INTO Sales.SalesOrderHeader
        (
            RevisionNumber,
            DueDate,
            ShipDate,
            Status,
            OnlineOrderFlag,
            CustomerID,
            SalesPersonID,
            BillToAddressID,
            ShipToAddressID,
            ShipMethodID,
            CreditCardID,
            Freight,
            Comment,
            rowguid,
            ModifiedDate
        )
        VALUES
        (
            dbo.GetNewRevisionNumber(@SalesOrderID),
            DATEADD(DAY, 12, GETDATE()),
            DATEADD(DAY, 7, GETDATE()),
            @Status,
            1, 
            @CustomerID,
            NULL,
            @BillToAddressID,
            @ShipToAddressID,
            @ShipMethodID,
            @CreditCardID,
            0,
            @Comment,
            NEWID(),
            GETDATE()
        );

        -- Get the SalesOrderID of the newly inserted record
        SET @SalesOrderID = SCOPE_IDENTITY();

        -- Get ShipBase and ShipRate
        SELECT 
            @ShipBase = sm.ShipBase,
            @ShipRate = sm.ShipRate
        FROM 
            Purchasing.ShipMethod sm
        WHERE 
            sm.ShipMethodID = @ShipMethodID;

        -- Loop through each product in @ProductsToAdd
        DECLARE product_cursor CURSOR FOR
        SELECT 
            ProductID, 
            Quantity 
        FROM @ProductsToAdd;

        OPEN product_cursor;
        FETCH NEXT FROM product_cursor INTO @ProductID, @OrderQty;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Get product unit price
            SELECT @UnitPrice = p.ListPrice
            FROM Production.Product p
            WHERE p.ProductID = @ProductID;

			SELECT @UnitPriceDiscount = so.DiscountPct
			FROM Sales.SpecialOffer so
			INNER JOIN Sales.SpecialOfferProduct sop ON so.SpecialOfferID = sop.SpecialOfferID
			WHERE sop.ProductID = @ProductID;

			SELECT @SpecialOfferID = so.SpecialOfferID
			FROM Sales.SpecialOffer so
			INNER JOIN Sales.SpecialOfferProduct sop ON so.SpecialOfferID = sop.SpecialOfferID
			WHERE sop.ProductID = @ProductID;

            -- Calculate freight and line total
            SET @Freight = @Freight + (@ShipBase + (@ShipRate * @OrderQty));
            SET @SubTotal = @SubTotal + (@OrderQty * @UnitPrice - @UnitPriceDiscount);

            -- Insert into SalesOrderDetail
            INSERT INTO Sales.SalesOrderDetail
            (
                SalesOrderID,
                OrderQty,
                ProductID,
				SpecialOfferID,
                UnitPrice,
                UnitPriceDiscount,
                rowguid,
                ModifiedDate
            )
            VALUES
            (
                @SalesOrderID,
                @OrderQty,
                @ProductID,
				@SpecialOfferID,
                @UnitPrice,
                @UnitPriceDiscount,
                NEWID(),
                GETDATE()
            );

			UPDATE Production.ProductInventory 
			SET Quantity = Quantity - @OrderQty,
			ModifiedDate = GETDATE()
			WHERE ProductID = @ProductID;

            FETCH NEXT FROM product_cursor INTO @ProductID, @OrderQty;
        END

        CLOSE product_cursor;
        DEALLOCATE product_cursor;

        -- Update SalesOrderHeader with calculated values
        UPDATE Sales.SalesOrderHeader
        SET SubTotal = @SubTotal,
            Freight = @Freight
        WHERE SalesOrderID = @SalesOrderID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
