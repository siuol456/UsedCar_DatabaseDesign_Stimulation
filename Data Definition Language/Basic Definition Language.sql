CREATE database Team_4_project;
GO

USE Team_4_project;
GO

create schema Sales;
GO
create schema Inspect;
GO
create schema Preference;
GO
create schema Users;
GO
create schema Car;
GO

-- Schema: Car
create table Car.ColorIndex
(
    ColorID   int IDENTITY primary key,
    ColorName varchar(20) NOT NULL unique
);
create table Car.Manufacturer
(
    ManufacturerID   int IDENTITY primary key,
    ManufacturerName varchar(50) NOT NULL unique
);
create table Car.CarTransmissionStyle
(
    TransmissionID   int IDENTITY primary key,
    TransmissionName varchar(15) NOT NULL unique
);
create table Car.CarBodyStyle
(
    BodyStyleID int IDENTITY primary key,
    StyleName   varchar(50) NOT NULL unique
);
create table Car.CarModel
(
    ModelID        int IDENTITY primary key,
    ModelName      varchar(20) NOT NULL,
    ManufacturerID int         NOT NULL
        references Car.Manufacturer,
    ModelYear      Date        NOT NULL,
    constraint CarModel_UN
        unique (ModelName, ManufacturerID, ModelYear)
);
create table Car.CarSpecification
(
    CarSpecifyID         int IDENTITY primary key,
    ModelID              int NOT NULL
        references Car.CarModel,
    BodyStyleID          int NOT NULL
        references Car.CarBodyStyle,
    ColorID              int NOT NULL
        references Car.ColorIndex,
    TransmissionID int NOT NULL
        references Car.CarTransmissionStyle
);
-- Schema: Users
create table Users.State
(
    StateID  int IDENTITY primary key,
    State    varchar(40) NOT NULL,
    StateAbb varchar(2)  NOT NULL,
    Country  varchar(50) NOT NULL
);
create table Users.Address
(
    AddressID    int IDENTITY primary key,
    AddressLine1 text        NOT NULL,
    City         varchar(50) NOT NULL,
    StateID      int         NOT NULL
        references Users.State,
    ZipCode      varchar(5)  NOT NULL
);
create table Users.ContactInfo
(
    ContactInfoID int IDENTITY primary key,
    ContactType   VARCHAR(10) NOT NULL
        constraint CK__ContactType
            check ([ContactType] IN ('Other', 'Business', 'Private')),
    Email         text,
    Phone         varchar(12)
);
create table Users.Customer
(
    CustomerID    int IDENTITY primary key,
    FirstName     varchar(20) NOT NULL,
    MiddleName    varchar(20),
    LastName      varchar(20) NOT NULL,
    AddressID     int         NOT NULL
        references Users.Address,
    ContactInfoID int         NOT NULL
        references Users.ContactInfo
);
create table Users.Dealership
(
    DealershipID   int IDENTITY primary key,
    DealershipName int NOT NULL,
    AddressID      int NOT NULL
        references Users.Address,
    ContactInfoID  int NOT NULL
        references Users.ContactInfo
);
create table Users.Seller
(
    SellerID      int IDENTITY primary key,
    FirstName     varchar(20) NOT NULL,
    MiddleName    varchar(20),
    LastName      varchar(20) NOT NULL,
    SellerType    varchar(10) NOT NULL
        constraint CK__SellerType
            check ([SellerType] IN ('Other', 'Individual', 'Dealership')),
    DealershipID  int         NOT NULL
        references Users.Dealership,
    ContactInfoID int         NOT NULL
        references Users.ContactInfo
);

create table Users.Administration
(
    AdminID       int IDENTITY primary key,
    FirstName     varchar(20) NOT NULL,
    MiddleName    varchar(20),
    LastName      varchar(20) NOT NULL,
    ContactInfoID int         NOT NULL
        references Users.ContactInfo
);

-- Sechema Preference;
create table Preference.CustomerPref
(
    CustomerID int NOT NULL primary key
        references Users.Customer,
    BudgetMin  float,
    BudgetMax  float,
    CarAgeMin  float,
    CarAgeMax  float,
    MileageMin float,
    MileageMax float,
    Other      text
);
create table Preference.ModelPref
(
    ModelPrefID int IDENTITY primary key,
    CustomerID  int NOT NULL
        references Users.Customer,
    ModelID     int NOT NULL
        references Car.CarModel
);
create table Preference.ColorPref
(
    ColorPrefID int IDENTITY primary key,
    CustomerID  int NOT NULL
        references Users.Customer,
    ColorID       int NOT NULL
        references Car.ColorIndex
);

-- Schema: Sales
create table Sales.CarList
(
    CarID               int identity primary key,
    CarSpecifyID        int            NOT NULL
        references Car.CarSpecification,
    VinCode             VARCHAR(17)    NOT NULL unique,
    CurrentPrice        decimal(10, 2) NOT NULL,
    Age                 numeric        NOT NULL,
    Mileage             numeric        NOT NULL,
    PostDate            date           NOT NULL,
    SpecialModification text,
    LinkToPicture       text           NOT NULL
);
create table Sales.CarForSale
(
    CarSaleID int IDENTITY primary key,
    SellerID  int NOT NULL
        references Users.Seller,
    CarID     int NOT NULL
        references Sales.CarList
        --  Note: This constraint will be added after creating function 'CheckInspect'
        --constraint CK_Inspect
        --    check ([dbo].[CheckInspect]([CarID]) = 1)
);
create table Sales.CustomerInterested
(
    InterestID   int IDENTITY primary key,
    CarID        int  NOT NULL
        references Sales.CarList,
    CustomerID   int  NOT NULL
        references Users.Customer,
    InterestDate date NOT NULL
);
create table Sales.Sales
(
    SalesID         int IDENTITY primary key,
    CustomerID      int   NOT NULL
        references Users.Customer,
    CarSaleID       int   NOT NULL unique
        references Sales.CarForSale,
        -- Note: This constraint will be added after creating function 'CheckInspect'
        --constraint CK__SoldCar
        --    check ([dbo].[CheckForCarSale]([CarSaleID]) = 1),
    TotalAmount     money NOT NULL,
    LastPaymentData date  NOT NULL default getdate(),
    SalesDate       date  NOT NULL default getdate(),
    LastPaymentDate date default getdate() not null,
    -- Note: This two computed columns will be added after creating function 'CalcRemainAmount' and 'CalcSalesStat'
    --RemainAmount    AS (dbo.CalcRemainAmount(SalesID, TotalAmount)),
    --SalesStat       AS (dbo.CalcSalesStat(SalesID, TotalAmount))
);
create table Sales.Payment
(
    PaymentID     int IDENTITY primary key,
    SalesID       int         NOT NULL
        references Sales.Sales,
    Amount        money       NOT NULL,
    PayDate       date        NOT NULL,
    TransType     varchar(10) NOT NULL
        constraint CK__TransType
            check ([TransType] IN ('ACH', 'Cash', 'Card', 'Other')),
    BankAccountNo varchar(20),
    CreditCardNo  varchar(20)
    -- Note: This constraint will be added after creating function 'CheckPaymentInfo'
    --constraint CK__Method
    --    check ([dbo].[CheckPaymentInfo]([PaymentID]) = 1),
);



-- Schema: Inspect
create table Inspect.Inspectors
(
    InspectorID   int IDENTITY primary key,
    FirstName     varchar(20) NOT NULL,
    MiddleName    varchar(20),
    LastName      varchar(20) NOT NULL,
    AddressID     int         NOT NULL
        references Users.Address,
    ContactInfoID int         NOT NULL
        references Users.ContactInfo
);
create table Inspect.InspectionReport
(
    ReportID     int IDENTITY primary key,
    InspectorID  int         NOT NULL
        references Inspect.Inspectors,
    CarID        int         NOT NULL
        references Sales.CarList,
    InspectDate  date        NOT NULL,
    ReportLink   text        NOT NULL,
    AdminID      int         NOT NULL
        references Users.Administration,
    VerifyStatus VARCHAR(15) NOT NULL
        constraint CK__Verify
            check ([VerifyStatus] IN('Other', 'Denied', 'In-process', 'Verified'))
);

create table Inspect.FraudReport
(
    FraudReportID int IDENTITY primary key,
    AdminID       int NOT NULL
        references Users.Administration,
    SellerID      int
        references Users.Seller,
    CustomerID    int
        references Users.Customer,
    CarID         int
        references Sales.CarList
);
