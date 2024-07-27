DECLARE @ProductionDetails dbo.ProductionOperationSequence;
INSERT INTO @ProductionDetails (OperationSequence, LocationID, ProductionDate)
VALUES 
(10, 7, '2024-06-25'), 
(20, 2, '2024-06-26');

EXEC ProductionOrder 
    @ProductID = 710,
    @OrderQty = 50,
    @ScrappedQty = 5,
    @StartDate = '2024-06-24',
    @ProductionDetails = @ProductionDetails;