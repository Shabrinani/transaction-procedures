ALTER PROCEDURE ProductionOrder
	@ProductID INT,
	@OrderQty INT,
	@ScrappedQty INT,
	@StartDate DATETIME,
    @ProductionDetails dbo.ProductionOperationSequence READONLY
AS
BEGIN
    SET NOCOUNT ON;

    -- Acquire exclusive locks on tables
    SELECT 1 FROM Production.WorkOrder WITH (TABLOCKX);
    SELECT 1 FROM Production.WorkOrderRouting WITH (TABLOCKX);
    SELECT 1 FROM Production.ProductInventory WITH (TABLOCKX);

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @DaysToManufacture INT;
		DECLARE @DueDate DATETIME;
		DECLARE @WorkOrderID INT;
		DECLARE @OperationSequence INT;
		DECLARE @LocationID INT;
		DECLARE @ProductionDate DATETIME;
		DECLARE @ScheduledEndDate DATETIME;
		DECLARE @StandardCost MONEY;
		DECLARE @PlannedCost MONEY;

		SELECT @DaysToManufacture = DaysToManufacture FROM Production.Product WHERE ProductID = @ProductID;
		SET @DueDate = DATEADD(DAY, @DaysToManufacture, @StartDate);

        -- Insert into WorkOrder
        INSERT INTO Production.WorkOrder
        (
            ProductID,
            OrderQty,
			ScrappedQty,
			StartDate,
			DueDate
        )
        VALUES
        (
            @ProductID,
            @OrderQty,
            @ScrappedQty,
            @StartDate,
            @DueDate
        );

        -- Get the WorkOrderID of the newly inserted record
        SET @WorkOrderID = SCOPE_IDENTITY();

        -- Loop through each product in @ProductionDetails
        DECLARE product_cursor CURSOR FOR
        SELECT 
            OperationSequence, 
            LocationID,
			ProductionDate
        FROM @ProductionDetails;

        OPEN product_cursor;
        FETCH NEXT FROM product_cursor INTO @OperationSequence, @LocationID, @ProductionDate;

        WHILE @@FETCH_STATUS = 0
        BEGIN

		SET @ScheduledEndDate = DATEADD(DAY, @DaysToManufacture, @ProductionDate);
		SELECT @StandardCost = StandardCost FROM Production.Product WHERE ProductID = @ProductID;
		SET @PlannedCost = @StandardCost * @OrderQty;

            -- Insert into WorkorderRouting
            INSERT INTO Production.WorkOrderRouting
            (
                WorkOrderID,
				ProductID,
				OperationSequence,
				LocationID,
				ScheduledStartDate,
				ScheduledEndDate,
				PlannedCost
            )
            VALUES
            (
                @WorkOrderID,
				@ProductID,
				@OperationSequence,
				@LocationID,
				@ProductionDate,
				@ScheduledEndDate,
				@PlannedCost
            );

            -- Update ProductInventory
            UPDATE Production.ProductInventory 
            SET Quantity = Quantity + @OrderQty, 
			ModifiedDate = GETDATE()
            WHERE ProductID = @ProductID AND LocationID = @LocationID;

            FETCH NEXT FROM product_cursor INTO @OperationSequence, @LocationID, @ProductionDate;
        END

        CLOSE product_cursor;
        DEALLOCATE product_cursor;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
