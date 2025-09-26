USE Route_Optimization;


----------------------------------
-- ============================
-- EXPLORATORY DATA ANALYSIS
-- ============================
----------------------------------

--=============================
--1. Delivery Performance
--=============================

-- Avg, Min and Max Delivery Time (In Minutes)
SELECT ROUND(AVG(DeliveryDurationMin), 3) AS AvgDeliveryTime,
ROUND(MIN(DeliveryDurationMin), 3) AS MinDeliveryTime,
ROUND(MAX(DeliveryDurationMin), 3) AS MaxDeliveryTime
FROM CustomerOrders
WHERE DeliveryDurationMin <> 0

--=============================

--Average Delivery Time Of each Restaurant
SELECT r.RestaurantID,
		r.REstaurantName,
		ROUND(AVG(DeliveryDurationMin), 3) AS AverageDeliveryTime_Min
FROM Restaurants r JOIN CustomerOrders o
ON r.RestaurantID = O.RestaurantID
GROUP BY r.RestaurantID, r.REstaurantName

--=============================

-- Longest average delivery times by route (assumes StartLocation/EndLocation or RestaurantID & Customer)
SELECT 
    r.RestaurantName,
    t.LocationName,
    AVG(DeliveryDurationMin) AS AvgDeliveryTime
FROM CustomerOrders co
JOIN Restaurants r ON co.RestaurantID = r.RestaurantID
JOIN TrafficData t ON co.LocationID = t.LocationID
GROUP BY r.RestaurantName, t.LocationName
ORDER BY AvgDeliveryTime DESC;

--=============================

-- Average delivery time by time of day
SELECT 
    CASE 
        WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 18 AND 23 THEN 'Evening'
        ELSE 'Night'
    END AS TimeOfDay,
    AVG(DeliveryDurationMin) AS AvgDeliveryTime
FROM CustomerOrders
GROUP BY CASE 
        WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 18 AND 23 THEN 'Evening'
        ELSE 'Night'
    END;

--=============================

-- Number of Order by time of day (Peak ordering time)
SELECT 
  CASE 
    WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 5 AND 11 THEN 'Morning'
    WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 12 AND 16 THEN 'Afternoon'
    WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 17 AND 20 THEN 'Evening'
    ELSE 'Night'
  END AS TimeOfDay,
  COUNT(*) AS NumberOfOrders
FROM CustomerOrders
GROUP BY 
  CASE 
    WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 5 AND 11 THEN 'Morning'
    WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 12 AND 16 THEN 'Afternoon'
    WHEN DATEPART(HOUR, OrderTimestamp) BETWEEN 17 AND 20 THEN 'Evening'
    ELSE 'Night'
  END
ORDER BY NumberOfOrders DESC;

--=============================

--Average Delivery Time (Min) Of each Restaurant
SELECT r.RestaurantID,
		r.REstaurantName,
		ROUND(AVG(DeliveryDurationMin), 3) AS AverageDeliveryTime
FROM Restaurants r JOIN CustomerOrders o
ON r.RestaurantID = O.RestaurantID
GROUP BY r.RestaurantID, r.REstaurantName
ORDER BY AverageDeliveryTime

--=============================

-- Delivery time vs traffic congestion 
SELECT 
    t.TrafficDensity,
    AVG(DeliveryDurationMin) AS AvgDeliveryTime
FROM CustomerOrders co
JOIN TrafficData t ON co.LocationID = t.LocationID
GROUP BY t.TrafficDensity
ORDER BY AvgDeliveryTime DESC;

-- Insight:
-- [There is no definite correlation between the Traffic Density and the delivery time; 
-- as some Delivery with relatively LOW Traffic Density takes as much time to Delivery as those with HIGH Traffic Density.
-- Which means there are other factors that are for the Delay]
--=============================



--=============================
--2. Route Optimization
--=============================

--Routes consistently experiencing delays due to traffic conditions
SELECT 
    co.LocationID,
    AVG(td.TrafficDensity) AS AvgTrafficLevel,
    AVG(DeliveryDurationMin) AS AvgDeliveryTime,
    COUNT(*) AS DeliveryCount
FROM 
    CustomerOrders co
JOIN 
    TrafficData td ON co.LocationID = td.LocationID
GROUP BY 
    co.LocationID
HAVING 
    AVG(td.TrafficDensity) > 50  -- traffic level is 1 (low) to 5 (very high)
ORDER BY 
    AvgTrafficLevel DESC, AvgDeliveryTime DESC;


--=============================

-- The optimal path based on least travel time for high-volume delivery areas
WITH RouteVolumes AS (
    SELECT 
        LocationID,
        COUNT(*) AS TotalDeliveries,
        AVG(DeliveryDurationMin) AS AvgTravelTime
    FROM 
        CustomerOrders
    GROUP BY 
        LocationID
)
SELECT 
    LocationID,
    TotalDeliveries,
    AvgTravelTime
FROM 
    RouteVolumes
WHERE 
    TotalDeliveries > 10-- Threshold
ORDER BY 
    AvgTravelTime ASC;



--=============================
--3. Driver Efficiency
--=============================

--Driver shift length
SELECT DriverID,
	ShiftStart,
	ShiftEnd,
	DATEDIFF(HOUR, ShiftStart, ShiftEnd) AS ShiftLength_Hr
FROM Drivers

--=============================

--Days with the most delivery (Drivers busiest day)
 SELECT 
  DriverID,
  CAST(DeliveryTime AS DATE) AS DeliveryDate,
  COUNT(*) AS NumberOfDeliveries
FROM CustomerOrders
WHERE OrderStatus = 'Delivered'
GROUP BY 
  DriverID,
  CAST(DeliveryTime AS DATE)
ORDER BY 
  DriverID,
  NumberOfDeliveries DESC;

--=============================

--Busy time for Drivers
SELECT DriverID,
  DATEPART(HOUR, OrderTimestamp) AS OrderHour,
  DeliveryHour,
  COUNT(*) AS NumberOfOrders
FROM CustomerOrders
GROUP BY DriverID, DATEPART(HOUR, OrderTimestamp), DeliveryHour
ORDER BY DriverID, NumberOfOrders DESC;

--=============================

--The drivers with the highest on-time delivery rates BASED OFF the Average delivery Time (9 Min)
SELECT 
    d.DriverID,
    d.DriverName,
    COUNT(*) AS TotalDeliveries,
    SUM(CASE 
            WHEN DeliveryDurationMin <= 9 THEN 1 
            ELSE 0 
        END) AS OnTimeDeliveries,
    CAST(SUM(CASE 
            WHEN DeliveryDurationMin <= 9 THEN 1 
            ELSE 0 
        END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS OnTimeRate
FROM 
    CustomerOrders co
JOIN 
    Drivers d ON co.DriverID = d.DriverID
GROUP BY 
    d.DriverID, d.DriverName
ORDER BY 
    OnTimeRate DESC;


--=============================
--4. Order Insights
--=============================

-- Top 5 restaurants with highest order volume
SELECT 
    r.RestaurantName,
    COUNT(*) AS TotalOrders
FROM CustomerOrders co
JOIN Restaurants r ON co.RestaurantID = r.RestaurantID
GROUP BY r.RestaurantName
ORDER BY TotalOrders DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;

--=============================

--Frequency of product Delivered (More PENDING)
SELECT OrderStatus,
	COUNT(*) AS StatusCount
FROM CustomerOrders
GROUP BY OrderStatus

--=============================

--Number of orders per Restaurant
SELECT RestaurantID,
	COUNT(*) AS TotalOrder
FROM CustomerOrders
GROUP BY RestaurantID

--=============================

-- Average Orders per Restaurant by Hour
SELECT OrderHour,
    AVG(OrderCount) AS AvgOrdersPerRestaurant
FROM (
    SELECT 
        RestaurantID,
        DATEPART(HOUR, OrderTimestamp) AS OrderHour,
        COUNT(*) AS OrderCount
    FROM CustomerOrders
    GROUP BY RestaurantID, DATEPART(HOUR, OrderTimestamp)
) AS SubQuery
GROUP BY OrderHour
ORDER BY OrderHour;

--=============================

-- Average Orders per Restaurant by Day
SELECT OrderDay,
    AVG(OrderCount) AS AvgOrdersPerRestaurant
FROM (
    SELECT 
        RestaurantID,
        DATENAME(WEEKDAY, OrderTimestamp) AS OrderDay,
        COUNT(*) AS OrderCount
    FROM CustomerOrders
    GROUP BY RestaurantID, DATENAME(WEEKDAY, OrderTimestamp)
) AS SubQuery
GROUP BY OrderDay
ORDER BY 
    CASE 
        WHEN OrderDay = 'Monday' THEN 1
        WHEN OrderDay = 'Tuesday' THEN 2
        WHEN OrderDay = 'Wednesday' THEN 3
        WHEN OrderDay = 'Thursday' THEN 4
        WHEN OrderDay = 'Friday' THEN 5
        WHEN OrderDay = 'Saturday' THEN 6
        WHEN OrderDay = 'Sunday' THEN 7
    END;

--=============================