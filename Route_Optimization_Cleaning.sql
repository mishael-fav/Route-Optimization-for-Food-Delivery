
USE Route_Optimization;

----------------------------------
-- ==============================
-- DATA CLEANING AND PREPARATION
-- ==============================
----------------------------------

-- Check the dataset for any missing values and correct data type 
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'CustomerOrders'; --(CustomerOrders, Drivers, Restaurants, TrafficData)


--There are NULL values in the CustomerOrders table in the Delivery Time and Time taken to deliver columns. 
--This is because the delivery hasn't been made, as the Order Status indicates 'Pending'
SELECT * FROM CustomerOrders;

-- we don't want any NULL values in our CustomerOrders dataset, therefore replace the NULL with 0000-00-00 00:00:00
UPDATE CustomerOrders 
SET DeliveryTime = '1900-01-01 00:00:00.0000000'
WHERE DeliveryTime = '';

UPDATE CustomerOrders 
SET Timetakentodeliver = '00:00'
WHERE Timetakentodeliver = '';


--The Timetakentodeliver column which is aaparently the difference between the 'OrderTimestamp' and 'DeliveryTime' appear incorrect
--To confirm this, lets compare the value in the Timetakentodeliver column with a new column created from the DATEDIFF( MINUTE, OrderTimestamp, DeliveryTime)
ALTER TABLE CustomerOrders
ADD DeliveryDurationMin INT; --this is formatted in minutes

--Confirm if the columns are formatted with the right datatype (datatime)
SELECT 
    COLUMN_NAME, 
    DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'CustomerOrders' AND COLUMN_NAME IN ('OrderTimestamp', 'DeliveryTime');

--Calculted time taken to deliver
UPDATE CustomerOrders
SET DeliveryDurationMin = DATEDIFF(
    MINUTE,
    OrderTimestamp,
    CASE 
        WHEN DeliveryTime IS NULL OR CONVERT(TIME, DeliveryTime) = '00:00:00'
        THEN OrderTimestamp
        ELSE DeliveryTime
    END
);

select * from CustomerOrders;
--Notice the values do not correlate. While the inconsistency might be as a result of an incorrect datatype format.
--Its safe to calculate the delivery time to ensure reliable data

--Hence, we have to Drop the TimeTakenToDeliver column 
ALTER TABLE CustomerOrders
DROP COLUMN TimeTakenToDeliver;

--Similarly, for the DeliveryHours columns which have invalid value input for the pending delivery
ALTER TABLE CustomerOrders
DROP COLUMN DeliveryHours;

--Add a calculated Delivery hour
ALTER TABLE CustomerOrders
ADD DeliveryHour INT;

UPDATE CustomerOrders
SET DeliveryHour = DATEPART(HOUR,
    CASE 
        WHEN DeliveryTime IS NULL OR CONVERT(TIME, DeliveryTime) = '00:00:00'
        THEN 0
        ELSE DeliveryTime
    END
);

--Let's also compute what time of day each order were made
ALTER TABLE CustomerOrders
ADD Timeofday varchar(20);

--Populate time-of-day categories based on DeliveryTime
UPDATE CustomerOrders
SET Timeofday = 
  CASE 
    WHEN DATEPART(HOUR, DeliveryTime) BETWEEN 5 AND 11 THEN 'Morning'
    WHEN DATEPART(HOUR, DeliveryTime) BETWEEN 12 AND 16 THEN 'Afternoon'
    WHEN DATEPART(HOUR, DeliveryTime) BETWEEN 17 AND 20 THEN 'Evening'
	 WHEN DATEPART(HOUR, DeliveryTime) = 0 THEN 'Not Yet Delivered'
    ELSE 'Night'
  END;

--Upon examining the other table, there appears to be no inconsistencies 
-- QUERY TABLE
SELECT * FROM CustomerOrders;
SELECT * FROM Drivers;
SELECT * FROM Restaurants;
SELECT * FROM TrafficData;



