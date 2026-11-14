--1.1 Data Exploration
SELECT 'menu' AS tb1, COUNT (*) AS n FROM menu
UNION ALL SELECT 'sales', COUNT(*) FROM sales
UNION ALL SELECT 'stores', COUNT(*) FROM stores
UNION ALL SELECT 'Customer', COUNT(*) FROM customers;


SELECT TABLE_NAME, COLUMN_NAME,DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME in ('menu','customers','sales','stores')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

ALTER TABLE sales ADD order_time_dt datetime2(0);
UPDATE sales SET order_time_dt = TRY_CONVERT(datetime2, order_time,120);
ALTER TABLE sales DROP COLUMN order_time;
EXEC sp_rename 'sales.order_time_dt','order_time', 'COLUMN';

ALTER TABLE customers ADD join_date_dt datetime2(0);
UPDATE customers SET join_date_dt = TRY_CONVERT(datetime2, join_date,120);
ALTER TABLE customers DROP COLUMN join_date;
EXEC sp_rename 'customers.join_date_dt','join_date', 'COLUMN';

SELECT * FROM customers;

--1.2 Checking NULL
SELECT
	SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
	SUM(CASE WHEN join_date IS NULL THEN 1 ELSE 0 END) AS null_join_date,
	SUM(CASE WHEN gender IS NULL THEN 1 ELSE 0 END) AS null_gender,
	SUM(CASE WHEN age IS NULL THEN 1 ELSE 0 END) AS null_age
FROM customers;	
-- There is no NUll in customer table

SELECT
	SUM(CASE WHEN menu_id IS NULL THEN 1 ELSE 0 END) AS null_menu_id,
	SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS null_product_name,
	SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_category,
	SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price
FROM menu;	
-- There is no null in menu table

SELECT
	SUM(CASE WHEN sale_id IS NULL THEN 1 ELSE 0 END) AS null_sale_id,
	SUM(CASE WHEN order_time IS NULL THEN 1 ELSE 0 END) AS null_order_time,
	SUM(CASE WHEN menu_id IS NULL THEN 1 ELSE 0 END) AS null_menu_id,
	SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS null_quantiy,
	SUM(CASE WHEN store_id IS NULL THEN 1 ELSE 0 END) AS null_store_id,
	SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id
FROM sales;
-- There is no null in sales table

SELECT
	SUM(CASE WHEN store_id IS NULL THEN 1 ELSE 0 END) AS null_store_id,
	SUM(CASE WHEN store_name IS NULL THEN 1 ELSE 0 END) AS null_store_name,
	SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS null_region
FROM stores;
-- There is no null in stores table


--1.3 Checking duplicate
--find duplitacte in customer_id
SELECT customer_id, COUNT(*) AS cnt
FROM customers
GROUP BY customer_id
HAVING COUNT(*)>1;

--find duplicate in menu_id
SELECT menu_id, COUNT(*) AS cnt
FROM menu
GROUP BY menu_id
HAVING COUNT(*)>1;

--find duplicate in sales table
SELECT order_time, menu_id, quantity, store_id, customer_id, COUNT(*) AS cnt
FROM sales
GROUP BY order_time, menu_id, quantity, store_id, customer_id
HAVING COUNT(*)>1;


--1.4 Checking Orphan key
SELECT COUNT(*) AS orphan_menu
FROM sales s 
LEFT JOIN menu m 
ON s.menu_id = m.menu_id
WHERE m.menu_id IS NULL;

SELECT COUNT(*) AS orphan_store
FROM sales s 
LEFT JOIN stores s2 
ON s.store_id = s2.store_id 
WHERE s2.store_id IS NULL;

SELECT COUNT(*) AS orphan_customer
FROM sales s 
LEFT JOIN customers c
ON s.customer_id = c.customer_id 
WHERE c.customer_id IS NULL;


--1.5 checking unconsistent
SELECT category, COUNT(*) FROM menu GROUP BY category;
SELECT gender, COUNT(*) FROM customers GROUP BY gender;
SELECT region, COUNT(*) FROM stores GROUP BY region;
SELECT * FROM menu WHERE product_name <> LTRIM(RTRIM(product_name));
SELECT * FROM stores WHERE store_name <> LTRIM(RTRIM(store_name));

SELECT store_id, store_name, region FROM stores;
UPDATE stores SET store_name = N'Gourmet Binh Thanh' WHERE store_id=3;
UPDATE stores SET store_name = N'Gourmet Phu Nhuan' WHERE store_id=4;
UPDATE stores SET store_name = N'Gourmet Go Vap' WHERE store_id=5;
UPDATE stores SET store_name = N'Gourmet Thu Duc' WHERE store_id=6;
UPDATE stores SET store_name = N'Gourmet Tan Binh' WHERE store_id=7;




--2.1.1 Overall
SELECT ROUND(SUM(quantity*price),2) AS total_revenue, 
		COUNT(*) AS total_ordered,
		ROUND(SUM(quantity*price)/COUNT(*),2) AS avg_order_value,
		ROUND(SUM(quantity)/COUNT(*),2) AS avg_item_per_order
FROM sales s
JOIN menu m
ON s.menu_id = m.menu_id;

--2.1.2 Top 5 best seller
SELECT TOP 5 m.product_name AS product_name, 
		SUM(quantity) AS total_order_quantity,
		CAST(100.0 * SUM(s.quantity) / SUM(SUM(s.quantity)) OVER () AS decimal(5,2)) AS pct_of_units
FROM sales s
JOIN menu m
ON s.menu_id = m.menu_id
GROUP BY m.product_name
ORDER BY SUM(s.quantity) DESC;


--2.1.3 Top 3 by revenue
WITH product_stats AS (
SELECT m.product_name AS product_name, 
				SUM(quantity) AS unit_sold,
				ROUND(SUM(s.quantity * m.price),2) AS total_revenue
FROM sales s
JOIN menu m
ON s.menu_id = m.menu_id
GROUP BY m.product_name)
SELECT product_name, total_revenue, unit_sold,
		CAST(total_revenue/SUM(total_revenue) OVER () AS decimal(5,2)) AS pct_of_revenue
FROM product_stats
ORDER BY total_revenue DESC;


--2.1.4 Revenue by category
WITH revenue_by_category AS (
	SELECT m.category, 
					COUNT(DISTINCT m.menu_id) AS products,
					SUM(s.quantity) AS units_sold
					ROUND(SUM(s.quantity*m.price),2) AS total_revenue
	FROM sales s
	JOIN menu m
	ON s.menu_id = m.menu_id
	GROUP BY m.category)
SELECT category, products, units_sold,
		CAST (100.0 * total_revenue/SUM(total_revenue) OVER () AS decimal(5,2)) AS pct_per_rev,
		CAST(100.0 * units_sold/ SUM(units_sold) OVER () AS decimal(5,2)) AS pct_units,
		ROUND(1.0* total_revenue/ products,2) AS revenue_per_products
FROM revenue_by_category;


--2.1.5 Best product by category
WITH product_revenue AS(
	SELECT category, product_name, ROUND(SUM(quantity*price),2) AS total_revenue
	FROM sales s 
	JOIN menu m
	ON s.menu_id = m.menu_id
	GROUP BY m.category, m.product_name),
ranked AS (
	SELECT category, product_name, total_revenue,
			RANK () OVER(PARTITION BY category ORDER BY total_revenue DESC) AS rnk,
			CAST(100.0*total_revenue/SUM(total_revenue) OVER (PARTITION BY category) AS decimal(5,2)) AS pct_per_category,
			COUNT(*) OVER(PARTITION BY category) AS products_in_category
	FROM product_revenue)
SELECT category, product_name, total_revenue, pct_per_category, products_in_category,
		CAST(100.0/ products_in_category AS decimal(5,2)) AS even_split_pct
FROM ranked
WHERE rnk <= 2
ORDER BY total_revenue DESC, rnk;


--2.1.7 Store Rev vs Avg order value
SELECT
    st.store_name,
    st.region,
    COUNT(*)                                          AS orders,
    SUM(s.quantity)                                   AS units_sold,
    ROUND(SUM(s.quantity * m.price), 2)               AS total_revenue,
    CAST(100.0 * SUM(s.quantity * m.price)
         / SUM(SUM(s.quantity * m.price)) OVER () AS decimal(5,2)) AS pct_of_revenue,
    ROUND(1.0 * SUM(s.quantity * m.price) / COUNT(*), 2)          AS avg_order_value,
    CAST(100.0 * (1.0 * SUM(s.quantity * m.price)
         / AVG(SUM(s.quantity * m.price)) OVER () - 1) AS decimal(6,2)) AS vs_avg_store_pct
FROM sales s
JOIN menu m    ON s.menu_id = m.menu_id
JOIN stores st ON s.store_id = st.store_id
GROUP BY st.store_id, st.store_name, st.region
ORDER BY total_revenue DESC;


--2.2.1 Monthly Rev
SELECT MONTH(order_time) AS mth, 
		COUNT(DISTINCT CAST(s.order_time AS date)) AS days_with_sales,
		COUNT(*) AS orders,
		ROUND(SUM(quantity*price),2) AS total_rev,
		ROUND(SUM(quantity*price)/COUNT(DISTINCT CAST(s.order_time AS date)),2) AS rev_per_day
FROM sales s
JOIN menu m
ON s.menu_id = m.menu_id 
GROUP BY MONTH(order_time)
ORDER BY mth;


--2.2.2 Month over month grow
WITH monthly_revenue AS(
	SELECT MONTH(order_time) AS mth, ROUND(SUM(quantity*price),2) AS total_rev
	FROM sales s
	JOIN menu m
	ON s.menu_id = m.menu_id 
	GROUP BY MONTH(order_time)
)
SELECT mth, total_rev,
		ROUND(100.0*(total_rev-LAG(total_rev) OVER (ORDER BY mth))/
		NULLIF(LAG(total_rev) OVER (ORDER BY mth),0),2) AS growth
FROM monthly_revenue;

--2.2.3 Rev by day of week
SELECT DATENAME(weekday,order_time) AS weekname, 
		COUNT(DISTINCT CAST(order_time AS date)) AS day_in_data,
		ROUND(SUM(quantity*price),2) AS total_rev,
		ROUND(1.0 * SUM(quantity*price) / COUNT(DISTINCT CAST(order_time AS date)),2) AS rev_per_day,
		ROUND(1.0 * SUM(quantity*price) / COUNT(*),2) AS AOV
FROM sales s
JOIN menu m
ON s.menu_id  = m.menu_id 
GROUP BY DATENAME(weekday, order_time)
ORDER BY total_rev DESC;


--2.2.4 Weekday vs weekend
SELECT 
	CASE 
		WHEN DATENAME(weekday, order_time) IN ('Saturday', 'Sunday') THEN 'weekend'
		ELSE 'weekday'
	END AS type_of_date,
	COUNT(DISTINCT CAST(order_time AS date)) AS day_in_data,
		COUNT(*) AS total_ordered,
		ROUND(SUM(quantity*price),2) AS total_rev,
		ROUND(1.0 * SUM(quantity*price) / COUNT(DISTINCT CAST(order_time AS date)),2) AS rev_per_day,
		ROUND(1.0 * SUM(quantity*price) / COUNT(*),2) AS AOV
FROM sales s
JOIN menu m
ON s.menu_id  = m.menu_id 
GROUP BY CASE 
		WHEN DATENAME(weekday, order_time) IN ('Saturday', 'Sunday') THEN 'weekend'
		ELSE 'weekday'END;

--2.2.5 Peak Hour
SELECT DATEPART(hour,order_time) AS hr, 
		COUNT(*) AS num_ordered,
		CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS pct_per_order,
		ROUND(SUM(quantity*price),2) AS total_rev,
		CAST(100.0 * SUM(quantity*price)/ SUM(SUM(quantity*price)) OVER () AS decimal (5,2)) AS pct_per_rev,
		ROUND(1.0*SUM(quantity*price)/COUNT(*),2) AS avg_per_order
FROM sales s
JOIN menu m ON s.menu_id = m.menu_id 
GROUP BY DATEPART(hour,order_time)
ORDER BY hr;