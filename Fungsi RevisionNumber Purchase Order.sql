CREATE FUNCTION GetNewRevisionNumberPO (@PurchaseOrderID INT)
RETURNS INT
AS
BEGIN
    DECLARE @CurrentRevisionNumber INT;
    DECLARE @NewRevisionNumber INT;

    -- Mengambil nomor revisi terbaru untuk sebuah pesanan pembelian tertentu
    SELECT @CurrentRevisionNumber = ISNULL(MAX(RevisionNumber), 0)
    FROM Purchasing.PurchaseOrderHeader
    WHERE PurchaseOrderID = @PurchaseOrderID;

    -- Menambahkan nomor revisi baru
    SET @NewRevisionNumber = @CurrentRevisionNumber + 1;

    -- Mengembalikan nilai revisi baru
    RETURN @NewRevisionNumber;
END;
