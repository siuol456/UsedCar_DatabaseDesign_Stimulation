Use Team_4_project;
GO

--USE Team_4_project;

-- Views
-- Customer Information for sellers to make contact or admins to check status
CREATE VIEW dbo.[vw_CustomerPersonalInfo]
AS
SELECT c.CustomerID,
       CONCAT(c.FirstName,' ',c.MiddleName,' ',c.LastName) AS [FullName],
       ci.Email,
       ci.Phone,
       a.AddressLine1,
       a.City,
       a.ZipCode,
       s.StateAbb,
       s.Country
FROM Users.Customer c
     LEFT JOIN Users.ContactInfo ci
     ON c.ContactInfoID = ci.ContactInfoID
     LEFT JOIN Users.Address a
     ON c.AddressID = a.AddressID
     LEFT JOIN Users.State s
     ON a.StateID = s.StateID;
GO

-- Customer preference for seller to find potential customer or macth possible car in list
CREATE VIEW  dbo.[vw_CustomerCarPreferences]
AS
SELECT C.CustomerID,
       CONCAT(c.FirstName,' ',c.MiddleName,' ',c.LastName) AS 'CustomerName',
       BudgetMin,
       BudgetMax,
       CarAgeMin,
       CarAgeMax,
       MileageMin,
       MileageMax,
       ManufacturerName+ ' ' +ModelName AS 'CarModel',
       ColorName
FROM Users.Customer C WITH (NOLOCK)
LEFT JOIN Preference.CustomerPref CUP WITH (NOLOCK) ON C.CustomerID = CUP.CustomerID
LEFT JOIN Preference.ModelPref MP WITH (NOLOCK) ON CUP.CustomerID = MP.CustomerID
LEFT JOIN Car.CarModel CM WITH (NOLOCK) ON CM.ModelID = MP.ModelID
LEFT JOIN Car.Manufacturer M WITH (NOLOCK) ON CM.ManufacturerID = M.ManufacturerID
LEFT JOIN Preference.ColorPref CP WITH (NOLOCK) ON CP.CustomerID = C.CustomerID
LEFT JOIN Car.ColorIndex CI WITH (NOLOCK) ON CI.ColorID = CP.ColorID;
GO

-- To gather sold car info and apply in table check constraint function
CREATE VIEW  dbo.[vw_SoldCars]
AS
SELECT s.CarSaleID, s.TotalAmount AS SoldPrice,s.SalesDate ,cl.Age ,
       m.ManufacturerName ,cm.ModelName , cbs.StyleName , cts.TransmissionName ,ci.ColorName
FROM Sales.Sales s WITH (NOLOCK)
LEFT JOIN Sales.CarForSale cfs WITH (NOLOCK) ON s.CarSaleID  = cfs.CarSaleID
LEFT JOIN Sales.CarList cl  WITH (NOLOCK) ON cfs.CarID = cl.CarID
LEFT JOIN Car.CarSpecification cs WITH (NOLOCK) ON cl.CarSpecifyID = cs.CarSpecifyID
LEFT JOIN Car.CarModel cm  WITH (NOLOCK) on cs.ModelID = cm.ModelID
LEFT JOIN Car.CarTransmissionStyle cts  WITH (NOLOCK) ON cs.TransmissionID = cts.TransmissionID
LEFT JOIN Car.ColorIndex ci  WITH (NOLOCK) ON cs.ColorID = ci.ColorID
LEFT JOIN Car.CarBodyStyle cbs  WITH (NOLOCK) ON cs.BodyStyleID  = cbs.BodyStyleID
LEFT JOIN Car.Manufacturer m WITH (NOLOCK) ON cm.ManufacturerID = m.ManufacturerID;
GO

-- Functions
-- To find whether a car with CarID is sold.
-- 0 : not sale for car, coressponding CarID. Otherwise, the car has been sold.
CREATE FUNCTION dbo.CheckCarSold (@CarID int)
RETURNS smallint
AS
BEGIN
   DECLARE @Count smallint=0;
   SELECT @Count = COUNT(1) FROM Sales.Sales s
        JOIN Sales.CarForSale cfs
            ON s.CarSaleID  = cfs.CarSaleID
   WHERE cfs.CarID = @CarID;
   RETURN @Count;
END;
GO

-- Check if a car with CarSaleID has been sold
-- 0 : not sold yet. Otherwise, the car has been already sold.
CREATE FUNCTION dbo.CheckForCarSale (@CarSaleID int)
RETURNS smallint
AS
BEGIN
   DECLARE @CarID int;
   DECLARE @Count smallint=0;
   SELECT @CarID = CarID FROM Sales.CarForSale WHERE CarSaleID = @CarSaleID;

   SELECT @Count = dbo.CheckCarSold(@CarID);

   RETURN @Count;
END;
GO

-- Table check constraint function to ensure the payment method and required info matches
CREATE FUNCTION dbo.CheckPaymentInfo (@PID int)
RETURNS smallint
AS
BEGIN
    DECLARE @Indicator smallint=0;
    DECLARE @BK VARCHAR(20);
    DECLARE @CN VARCHAR(20);
    DECLARE @Ptype VARCHAR(10);
    SELECT @BK = ISNULL(BankAccountNo,''), @CN = ISNULL(CreditCardNo,'' ), @Ptype = TransType
    FROM Sales.Payment
    WHERE PaymentID = @PID;
    IF @Ptype = 'Cash' AND @BK = '' AND @CN = ''
    BEGIN
        SET @Indicator = 1;
    END
    IF @Ptype = 'ACC'  AND @BK !='' AND @CN = ''
    BEGIN
        SET @Indicator = 1;
    END
    IF @Ptype = 'Card' AND @BK = '' AND @CN != ''
    BEGIN
        SET @Indicator = 1;
    END
    RETURN @Indicator;
END;
GO

-- Function for computed column on Sales.Sales.RemainAmount
CREATE FUNCTION dbo.CalcRemainAmount(@SalesID INT, @TotalAmount MONEY)
    RETURNS MONEY
AS
BEGIN
    DECLARE @PaidAmount MONEY =
        ISNULL((SELECT SUM(p.Amount) FROM Sales.Payment p WHERE p.SalesID = @SalesID), 0);
    RETURN @TotalAmount - @PaidAmount;
END;
GO

-- Function for computed column on Sales.Sales.SalesStat
CREATE FUNCTION dbo.CalcSalesStat(@SalesID INT, @TotalAmount MONEY)
    RETURNS VARCHAR(15)
AS
BEGIN
    DECLARE @PaidAmount MONEY =
        (SELECT SUM(p.Amount) FROM Sales.Payment p WHERE p.SalesID = @SalesID);

    DECLARE @SalesStat VARCHAR(15) = (
        SELECT CASE
                   WHEN @PaidAmount <= 0
                       THEN 'Initial'
                   WHEN @PaidAmount = @TotalAmount
                       THEN 'Complete'
                   ELSE 'In-progress'
                   END
    )
    RETURN @SalesStat;
END;
GO

-- Table check function to ensure the car in sale has past inspection
Create Function dbo.CheckInspect (@CID int)
RETURNS smallint
AS
BEGIN
    DECLARE @Indicator smallint=0;
    DECLARE @vs VARCHAR(15);
    SELECT @vs = VerifyStatus
    FROM Inspect.InspectionReport
    WHERE CarID = @CID;
    IF @vs = 'Verified'
    BEGIN
        SET @Indicator = 1;
    END
    RETURN @Indicator;
END;
GO



-- Table-Function Check Constraints
ALTER TABLE Sales.Sales
ADD CONSTRAINT CK__SoldCar CHECK (dbo.CheckForCarSale(CarSaleID)=1);

ALTER TABLE Sales.Payment
ADD CONSTRAINT CK__Method CHECK (dbo.CheckPaymentInfo(PaymentID)=1);

ALTER TABLE Sales.CarForSale
ADD CONSTRAINT CK_Inspect CHECK (dbo.CheckInspect(CarID)=1);

-- Added computed columns base on a function
ALTER TABLE Sales.Sales
ADD RemainAmount AS (dbo.CalcRemainAmount(SalesID, TotalAmount));
ALTER TABLE Sales.Sales
ADD SalesStat AS (dbo.CalcSalesStat(SalesID, TotalAmount));


-- Encription Information
-- Create Master Key
CREATE MASTER KEY
    ENCRYPTION BY PASSWORD = ; -- Add password here
GO

-- Create certificate to protect symmetric key
CREATE CERTIFICATE Team4Certificate
    WITH SUBJECT = 'Project Team4 Certificate',
    EXPIRY_DATE = '2021-12-31';
GO

-- Create symmetric key to encrypt data
CREATE SYMMETRIC KEY Team4SymmetricKey
    WITH ALGORITHM = AES_128
    ENCRYPTION BY CERTIFICATE Team4Certificate;
GO


-- Procedure
-- Daily Procedure on data encryption
CREATE PROC dbo.DataEncrypt
AS
BEGIN
    DECLARE @d date = getdate();
    OPEN SYMMETRIC KEY Team4SymmetricKey
    DECRYPTION BY CERTIFICATE Team4Certificate;
    DECLARE @counter int = 1;
    DECLARE @BK VARCHAR(250);
    DECLARE @CN VARCHAR(250);
    DECLARE @I  int;
    WHILE @counter in (SELECT ROW_NUMBER () OVER (ORDER BY p.PaymentID)
                 FROM Sales.Payment p WHERE p.PayDate = @d)
    BEGIN
       WITH a AS (
       SELECT ROW_NUMBER () OVER (ORDER BY p.PaymentID) AS r, p.*
                 FROM Sales.Payment p
       )
       SELECT @BK = BankAccountNo , @CN = CreditCardNo ,@I = PaymentID
       FROM a
       WHERE r = @counter;
       IF @BK IS NOT NULL
       BEGIN
          UPDATE Sales.Payment
          SET BankAccountNo = EncryptByKey(Key_GUID(N'Team4SymmetricKey'),
                                  convert(varbinary, @BK))
          WHERE PaymentID = @I;
       END
       IF @CN IS NOT NULL
       BEGIN
          UPDATE Sales.Payment
          SET CreditCardNo = EncryptByKey(Key_GUID(N'Team4SymmetricKey'),
                                  convert(varbinary, @CN))
          WHERE PaymentID = @I
       END
       SET @counter += 1
    END
    CLOSE SYMMETRIC KEY Team4SymmetricKey;
END;
GO

-- Report for Fraud Related information
CREATE PROC Inspect.FraudReportProc
(@CarID int , @SID int , @CID int)
AS
BEGIN
    IF @CarID IS NOT NULL AND @SID IS NOT NULL AND @CID IS NOT NULL
    BEGIN
        WITH sellertemp AS(
            SELECT s.SellerID ,s.FirstName +''+s.LastName AS Seller,
              ci2.Email ,ci2.Phone, cfs.CarID
            FROM Users.Seller s LEFT JOIN Users.Dealership d
                                ON s.DealershipID = d.DealershipID
                                LEFT JOIN Users.ContactInfo ci2
                                ON s.ContactInfoID = ci2.ContactInfoID
                                LEFT JOIN Sales.CarForSale cfs
                                ON s.SellerID = cfs.SellerID
        WHERE s.SellerID = @SID
        )
        SELECT TOP(1)SellerID , Seller,Email ,Phone,
              STUFF((SELECT  ', '+ RTRIM(CAST(st.CarID as varchar(4)))
                     FROM sellertemp st
                     FOR XML PATH('')) , 1, 2, '')AS [Related Cars]
        FROM sellertemp
        SELECT ir.CarID , ir.ReportLink ,
               i.FirstName +''+i.LastName AS Inspector,
               ci.Email ,ci.Phone
        FROM Inspect.InspectionReport ir LEFT JOIN Inspect.Inspectors i
                                         ON ir.InspectorID = i.InspectorID
                                         LEFT JOIN Users.ContactInfo ci
                                         ON i.ContactInfoID = ci.ContactInfoID
        WHERE ir.CarID = @CarID
        SELECT *
        FROM dbo.vw_CustomerPersonalInfo vcpi
        WHERE vcpi.CustomerID = @CID
        SELECT p.PaymentID ,p.Amount ,p.PayDate ,s2.CustomerID , cfs2.SellerID
        FROM Sales.Sales s2 LEFT JOIN Sales.Payment p
                            ON s2.SalesID = p.SalesID
                            RIGHT JOIN Sales.CarForSale cfs2
                            ON cfs2.CarSaleID = s2.CarSaleID
        WHERE s2.CustomerID = @CID;
    END
    IF @CarID IS NULL AND @SID IS NOT NULL AND @CID IS NOT NULL
    BEGIN
        WITH sellertemp AS(
            SELECT s.SellerID ,s.FirstName +''+s.LastName AS Seller,
              ci2.Email ,ci2.Phone, cfs.CarID
            FROM Users.Seller s LEFT JOIN Users.Dealership d
                                ON s.DealershipID = d.DealershipID
                                LEFT JOIN Users.ContactInfo ci2
                                ON s.ContactInfoID = ci2.ContactInfoID
                                LEFT JOIN Sales.CarForSale cfs
                                ON s.SellerID = cfs.SellerID
        WHERE s.SellerID = @SID
        )
        SELECT TOP(1)SellerID , Seller,Email ,Phone,
              STUFF((SELECT  ', '+ RTRIM(CAST(st.CarID as varchar(4)))
                     FROM sellertemp st
                     FOR XML PATH('')) , 1, 2, '')AS [Related Cars]
        FROM sellertemp
        SELECT *
        FROM dbo.vw_CustomerPersonalInfo vcpi
        WHERE vcpi.CustomerID = @CID
        SELECT p.PaymentID ,p.Amount ,p.PayDate ,s2.CustomerID , cfs2.SellerID
        FROM Sales.Sales s2 LEFT JOIN Sales.Payment p
                            ON s2.SalesID = p.SalesID
                            RIGHT JOIN Sales.CarForSale cfs2
                            ON cfs2.CarSaleID = s2.CarSaleID
        WHERE s2.CustomerID = @CID
        SELECT 'No Car mentioned in this record';
    END
    IF @CarID IS NULL AND @SID IS NULL AND @CID IS NOT NULL
    BEGIN
        SELECT *
        FROM dbo.vw_CustomerPersonalInfo vcpi
        WHERE vcpi.CustomerID = @CID
        SELECT p.PaymentID ,p.Amount ,p.PayDate ,s2.CustomerID , cfs2.SellerID
        FROM Sales.Sales s2 LEFT JOIN Sales.Payment p
                            ON s2.SalesID = p.SalesID
                            RIGHT JOIN Sales.CarForSale cfs2
                            ON cfs2.CarSaleID = s2.CarSaleID
        WHERE s2.CustomerID = @CID
        SELECT 'No seller mentioned in this record',
               'No car mentioned in this record';
    END
    IF @CarID IS NOT NULL AND @SID IS NOT NULL AND @CID IS NULL
    BEGIN
        WITH sellertemp AS(
            SELECT s.SellerID ,s.FirstName +''+s.LastName AS Seller,
              ci2.Email ,ci2.Phone, cfs.CarID
            FROM Users.Seller s LEFT JOIN Users.Dealership d
                                ON s.DealershipID = d.DealershipID
                                LEFT JOIN Users.ContactInfo ci2
                                ON s.ContactInfoID = ci2.ContactInfoID
                                LEFT JOIN Sales.CarForSale cfs
                                ON s.SellerID = cfs.SellerID
        WHERE s.SellerID = @SID
        )
        SELECT TOP(1)SellerID , Seller,Email ,Phone,
              STUFF((SELECT  ', '+ RTRIM(CAST(st.CarID as varchar(4)))
                     FROM sellertemp st
                     FOR XML PATH('')) , 1, 2, '')AS [Related Cars]
        FROM sellertemp
        SELECT ir.CarID , ir.ReportLink ,
               i.FirstName +''+i.LastName AS Inspector,
               ci.Email ,ci.Phone
        FROM Inspect.InspectionReport ir LEFT JOIN Inspect.Inspectors i
                                         ON ir.InspectorID = i.InspectorID
                                         LEFT JOIN Users.ContactInfo ci
                                         ON i.ContactInfoID = ci.ContactInfoID
        WHERE ir.CarID = @CarID
        SELECT 'No customer is mentioned in this record';
    END
    IF @CarID IS NOT NULL AND @SID IS NULL AND @CID IS NOT NULL
    BEGIN
        SELECT ir.CarID , ir.ReportLink ,
               i.FirstName +''+i.LastName AS Inspector,
               ci.Email ,ci.Phone
        FROM Inspect.InspectionReport ir LEFT JOIN Inspect.Inspectors i
                                         ON ir.InspectorID = i.InspectorID
                                         LEFT JOIN Users.ContactInfo ci
                                         ON i.ContactInfoID = ci.ContactInfoID
        WHERE ir.CarID = @CarID
        SELECT *
        FROM dbo.vw_CustomerPersonalInfo vcpi
        WHERE vcpi.CustomerID = @CID
        SELECT p.PaymentID ,p.Amount ,p.PayDate ,s2.CustomerID , cfs2.SellerID
        FROM Sales.Sales s2 LEFT JOIN Sales.Payment p
                            ON s2.SalesID = p.SalesID
                            RIGHT JOIN Sales.CarForSale cfs2
                            ON cfs2.CarSaleID = s2.CarSaleID
        WHERE s2.CustomerID = @CID
        SELECT 'No seller mentioned in this record';
    END
    IF @CarID IS NOT NULL AND @SID IS NULL AND @CID IS NULL
    BEGIN
        SELECT ir.CarID , ir.ReportLink ,
               i.FirstName +''+i.LastName AS Inspector,
               ci.Email ,ci.Phone
        FROM Inspect.InspectionReport ir LEFT JOIN Inspect.Inspectors i
                                         ON ir.InspectorID = i.InspectorID
                                         LEFT JOIN Users.ContactInfo ci
                                         ON i.ContactInfoID = ci.ContactInfoID
        WHERE ir.CarID = @CarID
        SELECT 'No seller mentioned in this record',
               'No customer is mentioned in this record';
    END
    IF @CarID IS NOT NULL AND @SID IS NULL AND @CID IS NULL
    BEGIN
        WITH sellertemp AS(
            SELECT s.SellerID ,s.FirstName +''+s.LastName AS Seller,
              ci2.Email ,ci2.Phone, cfs.CarID
            FROM Users.Seller s LEFT JOIN Users.Dealership d
                                ON s.DealershipID = d.DealershipID
                                LEFT JOIN Users.ContactInfo ci2
                                ON s.ContactInfoID = ci2.ContactInfoID
                                LEFT JOIN Sales.CarForSale cfs
                                ON s.SellerID = cfs.SellerID
        WHERE s.SellerID = @SID
        )
        SELECT TOP(1)SellerID , Seller,Email ,Phone,
              STUFF((SELECT  ', '+ RTRIM(CAST(st.CarID as varchar(4)))
                     FROM sellertemp st
                     FOR XML PATH('')) , 1, 2, '')AS [Related Cars]
        FROM sellertemp
        SELECT 'No customer is mentioned in this record',
               'No car mentioned in this record';
    END
END
GO





-- Triggers
-- Trigger for updating Sales.Sales on LastPaymentDate
CREATE TRIGGER Sales.UpdateLastPaymentDate
ON Sales.Payment
FOR INSERT
AS
BEGIN
    UPDATE Sales.Sales
    SET LastPaymentDate= CURRENT_TIMESTAMP
    WHERE SalesID = (SELECT DISTINCT SalesID FROM inserted);
END;
GO

-- When a record is insert for Fraud report generate related report
CREATE TRIGGER Inspect.FraudReportG
ON Inspect.FraudReport
FOR INSERT, UPDATE
AS
BEGIN
    DECLARE @Car int;
    DECLARE @Seller int;
    DECLARE @Customer int;
    SELECT @Car = CarID, @Seller = SellerID, @Customer = CustomerID
    FROM inserted;
    EXEC Inspect.FraudReportProc @Car, @Seller, @Customer;
END
GO
