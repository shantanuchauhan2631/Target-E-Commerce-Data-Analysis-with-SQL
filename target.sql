DROP DATABASE IF EXISTS target;
CREATE DATABASE target;


-- Table: customers
CREATE TABLE customers (
    customer_id text,
    customer_unique_id text,
    customer_zip_code_prefix integer,
    customer_city text,
    customer_state text
);

-- Table: orders
CREATE TABLE orders (
    order_id text,
    customer_id text,
    order_status text,
    order_purchase_timestamp timestamp,
    order_approved_at timestamp,
    order_delivered_carrier_date timestamp,
    order_delivered_customer_date timestamp,
    order_estimated_delivery_date timestamp
);

-- Table: order_items
CREATE TABLE order_items (
    order_id text,
    order_item_id integer,
    product_id text,
    seller_id text,
    shipping_limit_date timestamp,
    price double precision,
    freight_value double precision
);

-- Table: payments
CREATE TABLE payments (
    order_id text,
    payment_sequential integer,
    payment_type text,
    payment_installments integer,
    payment_value double precision
);

-- Table: products
CREATE TABLE products (
    product_id text,
    product_category text,
    product_name_length double precision,
    product_description_length double precision,
    product_photos_qty double precision,
    product_weight_g double precision,
    product_length_cm double precision,
    product_height_cm double precision,
    product_width_cm double precision
);

-- Table: sellers
CREATE TABLE sellers (
    seller_id text,
    seller_zip_code_prefix integer,
    seller_city text,
    seller_state text
);

-- Table: order_reviews
CREATE TABLE order_reviews (
    review_id text,
    order_id text,
    review_score integer,
    review_comment_title text,
    review_creation_date text,
    review_answer_timestamp text
);

-- Table: geolocation
CREATE TABLE geolocation (
    geolocation_zip_code_prefix integer,
    geolocation_lat double precision,
    geolocation_lng double precision,
    geolocation_city text,
    geolocation_state text
);


--1. Import the dataset and do usual exploratory analysis steps like checking the structure & 
--characteristics of the dataset

--Data type of all columns in the "customers" table.
SELECT
  column_name,
  data_type,
  is_nullable,
  character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'customers'
ORDER BY ordinal_position;

--Get the time range between which the orders were placed.
SELECT
  MIN(order_purchase_timestamp) AS first_order_ts,
  MAX(order_purchase_timestamp) AS last_order_ts,
  COUNT(*) AS total_orders
FROM public.orders;

--Count the Cities & States of customers who ordered during the given period.

SELECT
  COUNT(DISTINCT c.customer_city)   AS distinct_cities,
  COUNT(DISTINCT c.customer_state)  AS distinct_states
FROM public.customers c
JOIN public.orders o
  ON c.customer_id = o.customer_id;


--2. In-depth Exploration

--Is there a growing trend in the no. of orders placed over the past years?

select
	extract(year from order_purchase_timestamp) as year,
	count(order_id) as total_orders
from orders
group by extract(year from order_purchase_timestamp)
order by extract(year from order_purchase_timestamp)

--Can we see some kind of monthly seasonality in terms of the no. of orders being placed?

select
	extract(month from order_purchase_timestamp) as year,
	count(order_id) as total_orders
from orders
group by extract(month from order_purchase_timestamp)
order by extract(month from order_purchase_timestamp)

--During what time of the day, do the Brazilian customers mostly place their orders? (Dawn, Morning, Afternoon or Night)
--0-6 hrs : Dawn
--7-12 hrs : Mornings
--13-18 hrs : Afternoon
--19-23 hrs : Night

select 
	count(case when extract (hour from order_purchase_timestamp) between 0 and 6 then 1 end) as dawn,
	count(case when extract (hour from order_purchase_timestamp) between 7 and 12 then 1 end) as mornings,
	count(case when extract (hour from order_purchase_timestamp) between 13 and 18 then 1 end) as afternoon,
	count(case when extract (hour from order_purchase_timestamp) between 19 and 23 then 1 end) as night
from orders


--3. Evolution of E-commerce orders in the Brazil region.

--Get the month on month no. of orders placed in each state.

select
	c.customer_state,
	extract(month from o.order_purchase_timestamp) as month,
	extract(year from o.order_purchase_timestamp) as year,
	count(o.order_id) as no_of_orders
from customers as c
join orders as o
on c.customer_id = o.customer_id
group by c.customer_state, extract(month from o.order_purchase_timestamp), extract(year from o.order_purchase_timestamp)
order by c.customer_state, extract(month from o.order_purchase_timestamp), extract(year from o.order_purchase_timestamp)

--How are the customers distributed across all the states?

select
	customer_state,
	count(customer_id) as total_customers
from customers
group by customer_state
order by count(customer_id) desc


--4. Impact on Economy: Analyze the money movement by e-commerce by looking at order prices, freight and others.

--Get the % increase in the cost of orders from year 2017 to 2018 (include months between Jan to Aug only).
--You can use the "payment_value" column in the payments table to get the cost of orders.

SELECT
    SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
              AND EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
             THEN p.payment_value ELSE 0 END) AS total_2017,
    SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
              AND EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
             THEN p.payment_value ELSE 0 END) AS total_2018,
    (
        SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
                  AND EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
                 THEN p.payment_value ELSE 0 END)
        -
        SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
                  AND EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
                 THEN p.payment_value ELSE 0 END)
    ) * 100.0
    /
    NULLIF(
        SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
                  AND EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
                 THEN p.payment_value ELSE 0 END),
        0
    ) AS pct_increase
FROM orders o
JOIN payments p ON o.order_id = p.order_id;

--Calculate the Total & Average value of order price for each state.

select 
	distinct c.customer_state,
	round(sum(payment_value)::numeric,2) as total,
	round(avg(payment_value)::numeric,2) as avg
from orders as o
join customers as c
on o.customer_id = c.customer_id
join payments as p
on o.order_id=p.order_id
group by c.customer_state

--Calculate the Total & Average value of order freight for each state.

select
	c.customer_state,
	round(sum(i.freight_value)::numeric,2) as total,
	round(avg(i.freight_value)::numeric,2) as avg
from customers as c
join orders as o
on c.customer_id=o.customer_id
join order_items as i
on o.order_id=i.order_id
group by c.customer_state


--5. Analysis based on sales, freight and delivery time.

--Find the no. of days taken to deliver each order from the order’s purchase date as delivery time.
--Also, calculate the difference (in days) between the estimated & actual delivery date of an order.

select 
	order_id,
	extract (days from (order_delivered_customer_date - order_purchase_timestamp)) as delivery_days,
	extract (days from (order_delivered_customer_date - order_estimated_delivery_date)) as delivery_days
from orders
where order_status = 'delivered'

--Find out the top 5 states with the highest & lowest average freight value.

WITH cte1 AS (
    SELECT
        c.customer_state,
        AVG(i.freight_value) AS avg_freight,
        'low'::text AS type
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items i ON o.order_id = i.order_id
    GROUP BY c.customer_state
    ORDER BY AVG(i.freight_value)
    LIMIT 5
),
cte2 AS (
    SELECT
        c.customer_state,
        AVG(i.freight_value) AS avg_freight,
        'high'::text AS type
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items i ON o.order_id = i.order_id
    GROUP BY c.customer_state
    ORDER BY AVG(i.freight_value) DESC
    LIMIT 5
)
SELECT * 
FROM cte1
UNION ALL
SELECT * 
FROM cte2
ORDER BY type, avg_freight;

--Find out the top 5 states with the highest & lowest average delivery time.

with cte1 as(
select
	c.customer_state,
	round(avg(extract(day from (order_delivered_customer_date - order_purchase_timestamp))),2) as avg_delivery_time,
	'High'::text as type
from customers as c
join orders as o
on c.customer_id=o.customer_id
group by c.customer_state
order by avg(extract(day from (order_delivered_customer_date - order_purchase_timestamp))) desc
limit 5
),

cte2 as(
select
	c.customer_state,
	round(avg(extract(day from (order_delivered_customer_date - order_purchase_timestamp))),2) as avg_delivery_time,
	'Low'::text as type
from customers as c
join orders as o
on c.customer_id=o.customer_id
group by c.customer_state
order by avg(extract(day from (order_delivered_customer_date - order_purchase_timestamp)))
limit 5
)

select *
from cte1
union all
select *
from cte2

--Find out the top 5 states where the order delivery is really fast as compared to the estimated date of delivery.
--You can use the difference between the averages of actual & 
--estimated delivery date to figure out how fast the delivery was for each state.

select 
	c.customer_state,
	round(avg(extract(day from (o.order_estimated_delivery_date - o.order_purchase_timestamp))),2)
	-(select round(avg(extract(day from (order_estimated_delivery_date - order_purchase_timestamp))),2) from orders)
	as avg_days_earlier
from customers as c
join orders as o
on c.customer_id = o.customer_id
group by c.customer_state
order by round(avg(extract(day from (o.order_estimated_delivery_date - o.order_purchase_timestamp))),2)
	-(select round(avg(extract(day from (order_estimated_delivery_date - order_purchase_timestamp))),2) from orders) desc
limit 5

--6.Analysis based on the payments:

--Find the month on month no. of orders placed using different payment types.

select 
	extract(year from order_purchase_timestamp) as year,
	extract(month from order_purchase_timestamp) as month,
	payment_type,
	count(distinct p.order_id) as total
from orders as o
join payments as p
on o.order_id = p.order_id
group by extract(year from order_purchase_timestamp),
		extract(month from order_purchase_timestamp),
		payment_type

--Find the no. of orders placed on the basis of the payment installments that have been paid.

select
	payment_installments,
	count(distinct order_id) as total_orders
from payments
where payment_installments>1
group by payment_installments

