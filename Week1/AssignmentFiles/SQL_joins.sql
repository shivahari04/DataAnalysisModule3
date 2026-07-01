USE coffeeshop_db;

-- =========================================================
-- JOINS & RELATIONSHIPS PRACTICE
-- =========================================================

-- Q1) Join products to categories: list product_name, category_name, price.
select p.name as product_name, c.name as category_name, p.price from products p 
join categories c on p.category_id = c.category_id order by p.price desc;

-- Q2) For each order item, show: order_id, order_datetime, store_name,
--     product_name, quantity, line_total (= quantity * products.price).
--     Sort by order_datetime, then order_id.
select o.order_id, o.order_datetime, s.name as store_name, p.name as product_name, oi.quantity, oi.quantity*p.price as line_total
from orders o join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id 
join stores s on o.store_id = s.store_id
order by o.order_datetime, o.order_id; 

-- Q3) Customer order history (PAID only):
--     For each order, show customer_name, store_name, order_datetime,
--     order_total (= SUM(quantity * products.price) per order).
select concat(c.last_name, ' ',c.first_name) as customer_name, s.name as store_name, o.order_datetime,
sum(oi.quantity*p.price) as order_total
from customers c join orders o on c.customer_id = o.customer_id
join stores s on o.store_id = s.store_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
where o.status = 'paid'
group by o.order_id;

-- Q4) Left join to find customers who have never placed an order.
--     Return first_name, last_name, city, state.

select c.first_name, c.last_name,c.city, c.state from customers c
left join orders o on c.customer_id = o.customer_id
where o.order_id is null;

-- Q5) For each store, list the top-selling product by units (PAID only).
--     Return store_name, product_name, total_units.
--     Hint: Use a window function (ROW_NUMBER PARTITION BY store) or a correlated subquery.

With ranked_products as (select s.name as store_name, p.name as product_name, sum(oi.quantity) as total_units,
row_number() over (partition by s.name order by sum(oi.quantity) desc) as top_selling_product
from stores s join orders o on s.store_id = o.store_id
join order_items oi on oi.order_id = o.order_id
join products p on p.product_id = oi.product_id 
where o.status = 'paid'
group by store_name, product_name
) 
select store_name, product_name, total_units
from ranked_products
where top_selling_product = 1; 

-- Q6) Inventory check: show rows where on_hand < 12 in any store.
--     Return store_name, product_name, on_hand.
select s.name as store_name, p.name as product_name, i.on_hand
from stores s join inventory i on s.store_id = i.store_id
join products p on p.product_id = i.product_id
where i.on_hand < 12;

-- Q7) Manager roster: list each store's manager_name and hire_date.
--     (Assume title = 'Manager').
select s.name as store_name, concat(e.last_name, ' ',e.first_name) as manager_name, e.hire_date
from employees e join stores s on e.store_id = s.store_id
where e.title = 'Manager';

-- Q8) Using a subquery/CTE: list products whose total PAID revenue is above
--     the average PAID product revenue. Return product_name, total_revenue.
 With revenue as (
 select p.name as product_name, sum(p.price*oi.quantity) as total_revenue 
 from products p join order_items oi on p.product_id = oi.product_id
 join orders o on o.order_id = oi.order_id
 where o.status = 'paid'
 group by product_name)
 select product_name, total_revenue
from revenue
where total_revenue > ( select avg(total_revenue) as avg_revenue from revenue);
 
-- Q9) Churn-ish check: list customers with their last PAID order date.
--     If they have no PAID orders, show NULL.
--     Hint: Put the status filter in the LEFT JOIN's ON clause to preserve non-buyer rows.
select concat(c.first_name, ' ', c.last_name) as customer_name, max(date(o.order_datetime)) as last_paid_order
from customers c left join orders o on c.customer_id = o.customer_id and o.status = 'paid'
group by customer_name;

-- Q10) Product mix report (PAID only):
--     For each store and category, show total units and total revenue (= SUM(quantity * products.price)).
select s.name as store_name, c.name as category, sum(oi.quantity) as total_units, sum(oi.quantity * p.price) as total_revenue
from stores s join orders o on s.store_id = o.store_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
join categories c  on c.category_id = p.category_id
where o.status ='paid'
group by store_name, category;

