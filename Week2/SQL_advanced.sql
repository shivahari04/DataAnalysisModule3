USE coffeeshop_db;

-- =========================================================
-- ADVANCED SQL ASSIGNMENT
-- Subqueries, CTEs, Window Functions, Views
-- =========================================================
-- Notes:
-- - Unless a question says otherwise, use orders with status = 'paid'.
-- - Write ONE query per prompt.
-- - Keep results readable (use clear aliases, ORDER BY where it helps).

-- =========================================================
-- Q1) Correlated subquery: Above-average order totals (PAID only)
-- =========================================================
-- For each PAID order, compute order_total (= SUM(quantity * products.price)).
-- Return: order_id, customer_name, store_name, order_datetime, order_total.
-- Filter to orders where order_total is greater than the average PAID order_total
-- for THAT SAME store (correlated subquery).
-- Sort by store_name, then order_total DESC.

-- Couldnt figure out - did a lot of research but still couldnt figure out 
-- spent hours on it 

/* select o.order_id, 
	concat(c.first_name, ' ', c.last_name) as customer_name,
    s.name as store_name,  
    o.order_datetime,
	sum(oi.quantity * p.price) as order_total
    from orders o join customers c on o.customer_id = c.customer_id
    join stores s on s.store_id = o.store_id
    join order_items oi on oi.order_id = o.order_id
    join products p on p.product_id = oi.product_id
    where status = 'paid'
    group by o.order_id, customer_name, store_name, o.order_datetime
    having order_total > 
    ( 		select avg(oi2.quantity*p2.price) as store_order_total
			from order_items oi2 join products p2 on oi2.product_id = p2.product_id
			join orders o2 on oi2.order_id = o2.order_id
            where o2.status = 'paid' and o2.store_id = s.store_id
		) 	order by store_name, order_total desc; 
       ;
*/
-- =========================================================
-- Q2) CTE: Daily revenue and 3-day rolling average (PAID only)
-- =========================================================
-- Using a CTE, compute daily revenue per store:
--   revenue_day = SUM(quantity * products.price) grouped by store_id and DATE(order_datetime).
-- Then, for each store and date, return:
--   store_name, order_date, revenue_day,
--   rolling_3day_avg = average of revenue_day over the current day and the prior 2 days.
-- Use a window function for the rolling average.
-- Sort by store_name, order_date.

with daily_revenue as (
select
	o.store_id, 
    date(o.order_datetime) as order_date,
    sum(oi.quantity*p.price) as revenue_day
    from orders o join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    where o.status = 'paid'
    group by o.store_id, order_date 
    )
    select s.name as store_name, 
		daily_revenue.order_date,
        daily_revenue.revenue_day,
        round(
        avg(daily_revenue.revenue_day) 
        over(partition by daily_revenue.store_id
		order by daily_revenue.order_date	
        rows between 2 preceding and current row), 2) as rolling_3days_avg
        from daily_revenue join stores s on s.store_id = daily_revenue.store_id
        order by store_name, order_date; 
        
-- =========================================================
-- Q3) Window function: Rank customers by lifetime spend (PAID only)
-- =========================================================
-- Compute each customer's total spend across ALL stores (PAID only).
-- Return: customer_id, customer_name, total_spend,
--         spend_rank (DENSE_RANK by total_spend DESC).
-- Also include percent_of_total = customer's total_spend / total spend of all customers.
-- Sort by total_spend DESC.

with customer_spend as
(
	select c.customer_id, 
	concat(c.first_name, ' ', c.last_name) as customer_name, 
	sum(oi.quantity*p.price) as total_spend
	from customers c join orders o on c.customer_id = o.customer_id
	join order_items oi on o.order_id = oi.order_id
	join products p on p.product_id = oi.product_id
    where o.status = 'paid'
	group by c.customer_id, customer_name
    ) 
select 
	customer_id,
    customer_name,
    total_spend, 
    dense_rank () over (order by total_spend desc) as spend_rank,
    round(total_spend/sum(total_spend) over() *100, 2) as total_percent
    from customer_spend
    order by total_spend desc;
    
-- =========================================================
-- Q4) CTE + window: Top product per store by revenue (PAID only)
-- =========================================================
-- For each store, find the top-selling product by REVENUE (not units).
-- Revenue per product per store = SUM(quantity * products.price).
-- Return: store_name, product_name, category_name, product_revenue.
-- Use a CTE to compute product_revenue, then a window function (ROW_NUMBER)
-- partitioned by store to select the top 1.
-- Sort by store_name.

with top_product as 
( select 
	s.name as store_name, 
    p.name as product_name,
    ca.name as category_name,
    sum(oi.quantity*p.price) as product_revenue
    from stores s join orders o on s.store_id = o.store_id
    join order_items oi on o.order_id = oi.order_id
    join products p on oi.product_id = p.product_id
    join categories ca on ca.category_id = p.category_id
    where o.status = 'paid'
    group by store_name, product_name,category_name
    ) select store_name, product_name, category_name, product_revenue
    from (select *, 
		row_number()over(partition by store_name order by product_revenue desc) as number_of_rows
        from top_product
        ) as ranked
        where number_of_rows = 1
        order by store_name
        ;

-- =========================================================
-- Q5) Subquery: Customers who have ordered from ALL stores (PAID only)
-- =========================================================
-- Return customers who have at least one PAID order in every store in the stores table.
-- Return: customer_id, customer_name.
-- Hint: Compare count(distinct store_id) per customer to (select count(*) from stores).

-- select store_id, name from stores;

select c.customer_id, concat(c.first_name, ' ', c.last_name) as customer_name
from customers c join orders o on c.customer_id = o.customer_id
where o.status = 'paid'
group by c.customer_id, customer_name
having count( distinct o.store_id) = (
				select count(*) from stores);

-- =========================================================
-- Q6) Window function: Time between orders per customer (PAID only)
-- =========================================================
-- For each customer, list their PAID orders in chronological order and compute:
--   prev_order_datetime (LAG),
--   minutes_since_prev (difference in minutes between current and previous order).
-- Return: customer_name, order_id, order_datetime, prev_order_datetime, minutes_since_prev.
-- Only show rows where prev_order_datetime is NOT NULL.
-- Sort by customer_name, order_datetime.

With order_time as (
		select concat(c.first_name, ' ', c.last_name) as customer_name, 
		o.order_id, 
        date(o.order_datetime) as order_datetime, 
       lag(o.order_datetime) over(partition by c.customer_id order by o.order_datetime) as prev_order_datetime
		from customers c join orders o on c.customer_id = o.customer_id
       where o.status = 'paid')
       select 
			customer_name, 
            order_id, 
            order_datetime, 
			prev_order_datetime,
			timestampdiff(minute, prev_order_datetime, order_datetime) as minutes_since_prev
			from order_time
			where prev_order_datetime is not null
            order by customer_name, order_datetime
        ;
       
        
-- =========================================================
-- Q7) View: Create a reusable order line view for PAID orders
-- =========================================================
-- Create a view named v_paid_order_lines that returns one row per PAID order item:
--   order_id, order_datetime, store_id, store_name,
--   customer_id, customer_name,
--   product_id, product_name, category_name,
--   quantity, unit_price (= products.price),
--   line_total (= quantity * products.price)
--
-- After creating the view, write a SELECT that uses the view to return:
--   store_name, category_name, revenue
-- where revenue is SUM(line_total),
-- sorted by revenue DESC.

create view	v_paid_order_lines as 
select
	o.order_id, o.order_datetime, o.store_id, s.name as store_name,
	c.customer_id, concat(c.first_name, ' ', c.last_name) as customer_name, 
    p.product_id, p.name as product_name, ca.name as category_name,
	oi.quantity, p.price as unit_price,
	(oi.quantity * p.price) as line_total
    from orders o join order_items oi on o.order_id = oi.order_id
    join stores s on o.store_id = s.store_id
    join products p on p.product_id = oi.product_id
    join customers c on c.customer_id = o.customer_id
    join categories ca on ca.category_id = p.category_id
    where o.status = 'paid'
;
   -- select * from v_paid_order_lines; 
select     
	store_name, category_name, 
    sum(line_total) as revenue
    from v_paid_order_lines
    group by store_name, category_name
    order by revenue desc;


-- =========================================================
-- Q8) View + window: Store revenue share by payment method (PAID only)
-- =========================================================
-- Create a view named v_paid_store_payments with:
--   store_id, store_name, payment_method, revenue
-- where revenue is total PAID revenue for that store/payment_method.
--
-- Then query the view to return:
--   store_name, payment_method, revenue,
--   store_total_revenue (window SUM over store),
--   pct_of_store_revenue (= revenue / store_total_revenue)
-- Sort by store_name, revenue DESC.

create view v_paid_store_payments as
select
    s.store_id,
    s.name as store_name,
    o.payment_method,
    sum(oi.quantity * p.price) as revenue
from orders o
join stores s on o.store_id = s.store_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
where o.status = 'paid'
group by s.store_id, store_name, o.payment_method;

-- select * from v_paid_store_payments;
select 
    store_name,
    payment_method,
    revenue,
    sum(revenue) over (partition by store_name) as store_total_revenue,
   round(revenue / sum(revenue) over(partition by store_name) * 100, 2) as pct_of_store_revenue
from v_paid_store_payments
order by store_name, revenue desc;

-- =========================================================
-- Q9) CTE: Inventory risk report (low stock relative to sales)
-- =========================================================
-- Identify items where on_hand is low compared to recent demand:
-- Using a CTE, compute total_units_sold per store/product for PAID orders.
-- Then join inventory to that result and return rows where:
--   on_hand < total_units_sold
-- Return: store_name, product_name, on_hand, total_units_sold, units_gap (= total_units_sold - on_hand)
-- Sort by units_gap DESC.

-- select product_id, on_hand from inventory;

With units_sold as 
(
	select o.store_id,
		oi.product_id,
        sum(oi.quantity) as total_units_sold
	from orders o join order_items oi on o.order_id = oi.order_id
	where o.status = 'paid'
    group by o.store_id, oi.product_id
    )
select s.name as store_name, 
p.name as product_name,
i.on_hand,
u.total_units_sold,
(u.total_units_sold - i.on_hand) as unit_gap
from units_sold u join inventory i 
on u.store_id = i.store_id and u.product_id = i.product_id
join products p on p.product_id = i.product_id
join stores s on  u.store_id = s.store_id
where i.on_hand < u.total_units_sold
order by unit_gap desc;

