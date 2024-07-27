CREATE FUNCTION GetNewRevisionNumber (@SalesOrderID INT)
RETURNS INT
AS
BEGIN
    DECLARE @CurrentRevisionNumber INT;
    DECLARE @NewRevisionNumber INT;

    -- Mengambil nomor revisi terbaru untuk sebuah pesanan penjualan tertentu
    SELECT @CurrentRevisionNumber = ISNULL(MAX(RevisionNumber), 0)
    FROM Sales.SalesOrderHeader
    WHERE SalesOrderID = @SalesOrderID;

    -- Menambahkan nomor revisi baru
    SET @NewRevisionNumber = @CurrentRevisionNumber + 1;

    -- Mengembalikan nilai revisi baru
    RETURN @NewRevisionNumber;
END;
