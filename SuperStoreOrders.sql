use Superstore_Sales_Analysis

SELECT * FROM SuperStoreOrders

-- Total sales: What is the total sales amount for the entire dataset?
select SUM(sales) as total_sales 
from SuperStoreOrders

-- What is the average sales amount for the entire dataset?
select avg(sales) as avg_sales 
from SuperStoreOrders

-- Which products have the highest sales volume?
select top 10 product_name, SUM(sales) as Total_Sales
from SuperStoreOrders
group by product_name
order by Total_Sales desc

-- Top Selling Products by Quantity
select top 10 product_name, sum(quantity) as Total_Quantity_Sold
from SuperStoreOrders
group by product_name
order by Total_Quantity_Sold desc

-- What is the total sales amount for each product category?
select category, SUM(sales) as Total_sales
from SuperStoreOrders
group by category
order by Total_sales desc

--How has the total sales amount evolved over time (e.g., by year or month)?
select year(order_date) as OrderYear, MONTH(order_date) as OrderMonth, sum(sales) as Total_sales
from SuperStoreOrders
group by year(order_date), month(order_date)
order by OrderYear, OrderMonth

--  What is the average profit margin for all sales?
select round(AVG(profit/sales),2) as Avg_Profit_Margin
from SuperStoreOrders
where sales > 0

-- Find Customers with High Sales:
select customer_name, sales
from SuperStoreOrders
where sales > (
		select AVG(sales)
		from SuperStoreOrders
)

-- Find Products with Above-Average Sales in Each Category:
select category, product_name, sales
from SuperStoreOrders as s1
where sales > (
		select AVG(sales)
		from SuperStoreOrders as s2
		where s1.category = s2.category
)

-- Identify Customers who Made Multiple Purchases:
select customer_name
from SuperStoreOrders
where customer_id in (
		select customer_id
		from SuperStoreOrders
		group by customer_id
		having count(distinct order_id) > 1
)



-- Find Products Ordered by Customers in Specific Regions
select product_name
from SuperStoreOrders
where region = 'Africa'
group by product_name

-- Customer Churn Analysis: Query to identify customers who have not made any purchases within the last six months, indicating potential churn.
select customer_id, customer_name
from SuperStoreOrders
where customer_id not in (
		select distinct customer_id
		from SuperStoreOrders
		where order_date >= DATEADD(month, -6, getdate())
)

-- Product Return Analysis: Query to analyze the frequency and reasons for product returns, categorized by product category and customer segment.
select product_name, count(*) as Return_Count
from SuperStoreOrders
where profit < 0 or discount > 0
group by product_name
order by Return_Count desc;

-- Customer Segmentation Based on Purchase Behavior: Query to segment customers into groups based on their purchase frequency, recency, and monetary value (RFM analysis).
with CustomerRFM as (
		select customer_id, DATEDIFF(day, max(order_date), getdate()) as Recency,
				count(distinct order_id) as Frequency, sum(sales) as MonetaryValue
		from SuperStoreOrders
		group by customer_id
)
select customer_id, Recency, Frequency, MonetaryValue,
		case
			when Recency < 30 then 'Active'
			when Frequency > 2 then 'Frequent'
			when MonetaryValue > 1000 then 'HighValue'
			else 'Regular'
		end as Segment
from CustomerRFM
order by Recency, Frequency desc, MonetaryValue desc

-- Seasonal Sales Analysis: This query aims to analyze seasonal trends in sales by calculating the total sales for each quarter of the year.
select year(order_date) as OrderYear,
		case
			when month(order_date) between 1 and 3 then 'Q1'
			when month(order_date) between 4 and 6 then 'Q2'
			when month(order_date) between 7 and 9 then 'Q3'
			when month(order_date) between 10 and 12 then 'Q4'
		end as Quarter,
		sum(sales) as Total_Sales
from SuperStoreOrders
group by year(order_date),
		case
			when month(order_date) between 1 and 3 then 'Q1'
			when month(order_date) between 4 and 6 then 'Q2'
			when month(order_date) between 7 and 9 then 'Q3'
			when month(order_date) between 10 and 12 then 'Q4'
		end
order by OrderYear, Quarter

-- Product Category Growth Analysis: This query aims to analyze the growth or decline of product categories over time by comparing sales amounts between two consecutive years.
select category, year(order_date) as OrderYear,
		sum(case when year(order_date) = year(getdate()) then sales else 0 end) as CurrentYearSales,
		sum(case when year(order_date) = year(getdate()) -1 then sales else 0 end) as PreviousYearSales,
		(sum(case when year(order_date) = year(getdate()) then sales else 0 end) - sum(case when year(order_date) = year(getdate())-1 then sales else 0 end)) as SalesGrowth
from SuperStoreOrders
group by category, year(order_date)
having year(order_date) in (year(getdate()), year(getdate()) - 1)
order by category, OrderYear;

-- Customer Retention Rate Analysis: This query aims to analyze the retention rate of customers over time, specifically focusing on the percentage of customers who make repeat purchases.
with RetentionData as (
	select customer_id, min(order_date) as FirstPurchaseDate, max(order_date) as LastPurchaseDate
	from SuperStoreOrders
	group by customer_id
),
RetentionRates as (
	select DATEDIFF(month, FirstPurchaseDate, LastPurchaseDate) as CustomerTenure,
			count(*) as TotalCustomers, sum(case when datediff(month, FirstPurchaseDate, LastPurchaseDate) > 0 then 1 else 0 end) as RetainedCustomers
	from RetentionData
	group by DATEDIFF(month, FirstPurchaseDate, LastPurchaseDate)
)
select CustomerTenure, TotalCustomers, RetainedCustomers,
		round((RetainedCustomers*100.0/TotalCustomers),2) as RetentionRate
from RetentionRates
order by CustomerTenure;

-- Customer Cohort Analysis: This query aims to analyze customer behavior over time by grouping them into cohorts based on their first purchase date and tracking their purchasing patterns in subsequent months.
with CohortData as(
	select customer_id, min(order_date) as FirstPurchaseDate,
			year(min(order_date)) as CohortYear,
			month(min(order_date)) as CohortMonth,
			year(order_date) as OrderYear,
			month(order_date) as OrderMonth,
			count(distinct order_id) as NumOrders
	from SuperStoreOrders
	group by customer_id, year(order_date), month(order_date)
),
CohortAnalysis as (
	select CohortYear, CohortMonth, OrderYear, OrderMonth,
			count(distinct customer_id) as NumCustomers,
			sum(case when OrderYear = CohortYear and OrderMonth = CohortMonth then NumOrders else 0 end) as CohortSize,
			sum(NumOrders) as TotalOrders
	from CohortData
	group by CohortYear, CohortMonth, OrderYear, OrderMonth
)
select CohortYear, CohortMonth, OrderYear, OrderMonth, NumCustomers, TotalOrders,
		(TotalOrders*100/CohortSize) as Retentionrate
from CohortAnalysis
ORDER BY CohortYear, CohortMonth, OrderYear, OrderMonth;
