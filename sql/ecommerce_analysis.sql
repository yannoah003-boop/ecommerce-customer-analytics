LOAD DATA INFILE "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/online_retail_clean.csv"
INTO TABLE online_retail_clean
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

## ROWs
SELECT COUNT(*) as row_cnt FROM online_retail_clean;

## Range of Date
select min(invoicedate) as min_dt, max(invoicedate) as max_dt
from online_retail_clean;

## Quantity, Unitprice, Revenue
select sum(quantity<0) as bad_qty, sum(unitprice<0) as bad_price, sum(revenue<0) as bad_revenue
from online_retail_clean;

## The number of Customers
select COUNT(distinct customerid) as unique_customers
from online_retail_clean;


## 3.1 Overall KPI
select
round(sum(revenue),2) as total_revenue,
count(distinct invoiceno) as total_orders,
count(distinct customerid) as total_customers,
round(sum(revenue)/count(distinct invoiceno),2) as avg_order_value
from online_retail_clean


## 3.2 Monthly Revenue Trend + MoM + Seasonality Pattern
with monthly_sales as(
select date_format(invoicedate,'%Y-%m') as yearmonth,
round(sum(revenue),2) as revenue
from online_retail_clean
group by date_format(invoicedate,'%Y-%m'))

select yearmonth, revenue,
LAG(revenue) over(order by yearmonth) as pre_revenue,
round((revenue-LAG(revenue) over(order by yearmonth))/nullif(LAG(revenue) over(order by yearmonth),0)*100,2) as mom_growth_pct
from monthly_sales
order by yearmonth;

select month(invoicedate) as month_num, round(sum(revenue),2) as revenue
from online_retail_clean
group by month_num
order by month_num;


## 3.3 Country Revenue Analysis
with country_sales as (
select country,round(sum(revenue),2) as revenue
from online_retail_clean
group by country),
total as (
select sum(revenue) as total_revenue
from country_sales)

select c.country, c.revenue,
round(c.revenue/t.total_revenue*100,2) as revenue_share_pct,
rank() over(order by c.revenue desc) as revenue_rk
from country_sales c
cross join total t
order by revenue desc;


## 4.1 Top Selling Products & Top Revenue Products
## Top Selling Products
select stockcode, min(description) as discription,sum(quantity) as total_quantity
from online_retail_clean
group by StockCode
order by total_quantity desc
limit 10;

## Top Revenue Products
create view online_retail_products as 
select *
from online_retail_clean
where StockCode <> 'post'; 

select stockcode, min(description) as discription, round(sum(revenue),2) as total_revenue
from online_retail_products
group by StockCode
order by total_revenue desc
limit 10;


## 4.2 Product Revenue Concentration & Pareto analysis
## Product Revenue
WITH product_sales AS (
    SELECT
        StockCode,
        MIN(Description) AS description,
        SUM(Revenue) AS revenue
    FROM online_retail_products
    GROUP BY StockCode
),
ranked_products AS (
    SELECT
        StockCode,
        description,
        revenue,
        SUM(revenue) OVER() AS total_revenue,
        SUM(revenue) OVER(ORDER BY revenue DESC) AS cumulative_revenue
    FROM product_sales
)
SELECT
    StockCode,
    description,
    ROUND(revenue, 2) AS revenue,
    ROUND(cumulative_revenue / total_revenue * 100, 2) AS cumulative_share_pct
FROM ranked_products
ORDER BY revenue DESC;

## Pareto analysis
with product_sales as(
select stockcode, min(description) as description, sum(revenue) as revenue
from online_retail_products
group by stockcode),

ranked_products as (
select stockcode, description, revenue,
sum(revenue) over() as total_revenue,
sum(revenue) over(order by revenue desc, stockcode) as cumulative_revenue,
row_number() over(order by revenue desc) as product_rank
from product_sales
),

final_table as (
select stockcode, description, round(revenue,2) as revenue, product_rank,
round(cumulative_revenue/total_revenue*100,2) as cumulative_share_pct
from ranked_products
)

select *
from final_table
where cumulative_share_pct >= 80
order by cumulative_share_pct, product_rank
limit 1;


## 5.1 Customer Spending Distribution
## Customer Spending Ranking
with customer_spending as (
select round(sum(revenue),2) as total_spent, customerid,
count(distinct invoiceno) as total_orders,
round(sum(revenue)/count(distinct invoiceno),2) as avg_order_value
from online_retail_products
group by customerid
)
select customerid,total_spent,total_orders, avg_order_value,
row_number() over(order by total_spent desc) as spent_rk
from customer_spending
order by total_spent desc,spent_rk
limit 10;

## Top Customer Share
with customer_spending as (
select sum(revenue) as total_spent, customerid
from online_retail_products
group by customerid
),
ranked_customer as (
select customerid, total_spent,
row_number() over(order by total_spent desc, customerid) as customer_rk
from customer_spending
),
top_10 as (
select round(sum(total_spent),2) as top_10_revenue
from ranked_customer
where customer_rk <= 10
),
overall as (
select round(sum(total_spent),2) as total_revenue
from customer_spending
)

select t.top_10_revenue, o.total_revenue,
round(t.top_10_revenue/o.total_revenue*100,2) as top_10_revenue_pct
from top_10 t
cross join overall o;


## 5.2 Purchase Interval Analysis
with customer_orders as (
select distinct customerid, date, invoiceno
from online_retail_products
),
ordered_orders as (
select customerid,date,
LAG(date) over(partition by customerid
			   order by date) as pre_order_date
from customer_orders
),
purchase_intervals as (
select customerid,
datediff(date,pre_order_date) as days_between_orders
from ordered_orders
where pre_order_date is not null
)

## Repurchase cycle distribution
select
case
when days_between_orders<=7 then '0-7 days'
when days_between_orders<=30 then '8-30 days'
when days_between_orders<=90 then '31-90 days'
else '90+ days' end as interval_group,
count(*) as orders
from purchase_intervals
group by interval_group
order by orders desc;

## Avg purchase interval
select count(*) as total_intervals,
round(avg(days_between_orders),2) as avg_days_between_orders,
min(days_between_orders) as min_days,
max(days_between_orders) as max_days
from purchase_intervals;


## 5.3 RFM Analysis
with customer_rfm as(
select customerid,
count(distinct invoiceno) as frequency,
sum(revenue) as monetary,
max(invoicedate) as last_purchase_date
from online_retail_products
group by customerid
),
max_date as (
select max(invoicedate) as max_date
from online_retail_products
),
rfm_base as (
select c.customerid, c.frequency, c.monetary,
datediff(m.max_date, c.last_purchase_date) as recency
from customer_rfm c
cross join max_date m
),

## RFM
rfm_scores as(
select customerid, frequency, monetary, recency,
6-ntile(5) over(order by recency asc) as r_score,
6-ntile(5) over(order by frequency desc) as f_score,
6-ntile(5) over(order by monetary desc) as m_score
from rfm_base),

## Customer Segmentation
rfm_segments as (
select customerid, monetary, r_score, f_score, m_score,
case
when r_score>=4 and f_score>=4 and m_score>=4 then "Champions"
when f_score>=4 then "Loyal Customers"
when m_score>=4 then "Big Spenders"
when r_score<=2 then "At Risk"
else "Others" end as customer_segment
from rfm_scores
)
## Segment Revenue Contribution
SELECT
customer_segment,
COUNT(*) AS customers,
ROUND(SUM(monetary),2) AS total_revenue,
ROUND(SUM(monetary) /
     (SELECT SUM(monetary) FROM rfm_segments) *100,2) AS revenue_share_pct

FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;

## data check
## score distribution
select m_score ,count(*) as cnt
from rfm_scores
group by m_score
order by m_score;


## 5.4 Customer Retention / Cohort Analysis
with first_purchase as (
select customerid, min(date) as first_purchase_date
from online_retail_products
group by customerid
),
cohort_base as (
select o.customerid, 
date_format(f.first_purchase_date,'%Y-%m') as cohort_month,
date_format(o.date,'%Y-%m') as order_month,
timestampdiff(month, date_format(f.first_purchase_date,'%Y-%m-01'), date_format(o.date,'%Y-%m-01')) as cohort_index
from online_retail_products o
join first_purchase f
on f.customerid=o.customerid 
),
cohort_cnt as (
select cohort_month, cohort_index,
count(distinct customerid) as customers_retained
from cohort_base
group by cohort_month, cohort_index
),
cohort_size as (
select cohort_month, customers_retained as cohort_size
from cohort_cnt
where cohort_index=0
),
retention_table as (
select c.cohort_month, c.cohort_index, c.customers_retained, s.cohort_size,
round(c.customers_retained/s.cohort_size*100, 2) as retention_rate_pct
from cohort_cnt c
join cohort_size s
on c.cohort_month=s.cohort_month
)

select cohort_month,
max(case when cohort_index=0 then retention_rate_pct end) as month_0,
max(case when cohort_index=1 then retention_rate_pct end) as month_1,
max(case when cohort_index=2 then retention_rate_pct end) as month_2,
max(case when cohort_index=3 then retention_rate_pct end) as month_3,
max(case when cohort_index=4 then retention_rate_pct end) as month_4,
max(case when cohort_index=5 then retention_rate_pct end) as month_5,
max(case when cohort_index=6 then retention_rate_pct end) as month_6,
max(case when cohort_index=7 then retention_rate_pct end) as month_7,
max(case when cohort_index=8 then retention_rate_pct end) as month_8,
max(case when cohort_index=9 then retention_rate_pct end) as month_9,
max(case when cohort_index=10 then retention_rate_pct end) as month_10,
max(case when cohort_index=11 then retention_rate_pct end) as month_11
from retention_table
group by cohort_month
order by cohort_month;

## 7-day repeat
with first_purchase as (
select min(date) as first_purchase_date, customerid
from online_retail_products
group by customerid
),
repeat_within_7d as (
select distinct o.customerid
from online_retail_products o
join first_purchase f
on f.customerid=o.customerid
where o.date>f.first_purchase_date
and datediff(o.date,f.first_purchase_date)<=7
)
select count(*) as repeated_customers_7d,
(select count(*) from first_purchase) as totol_customers,
round(count(*)/(select count(*) from first_purchase) *100,2) as repeat_rate_7d_pct
from repeat_within_7d;

## 30-day repeat
with first_purchase as (
select customerid, min(date) as first_purchase_date
from online_retail_products
group by customerid
),
repeat_within_30d as (
select distinct o.customerid
from online_retail_products o
join first_purchase f
on f.customerid=o.customerid
where o.date>f.first_purchase_date
and datediff(o.date,f.first_purchase_date)<=30
)
select count(*) as repeated_customers_30d,
(select count(*) from first_purchase) as total_customers,
round(count(*)/(select count(*) from first_purchase)*100,2) as repeat_rate_30d_pct
from repeat_within_30d;


## Customer Lifetime Value (CLV)
with customer_summary as (
select customerid,count(distinct invoiceno) as total_orders,
sum(revenue) as customer_revenue
from online_retail_products
group by customerid
)

## CLV distribution
select
case
when customer_revenue<100 then '<100'
when customer_revenue<500 then '100-500'
when customer_revenue<1000 then '500-1000'
when customer_revenue<5000 then '1000-5000'
else '5000+' end as clv_segment,
count(*) as customers
from customer_summary
group by clv_segment
order by customers desc;

## Customer lifetime metrics
select count(*) as total_customers,
round(sum(customer_revenue),2) as total_revenue,
round(avg(customer_revenue),2) as avg_customer_lifetime_value,
round(avg(total_orders),2) as avg_orders_per_customer,
round(sum(customer_revenue)/sum(total_orders),2) as avg_order_value
from customer_summary;



## RFM View
create view customer_rfm_scores as
with customer_rfm as(
select customerid,
count(distinct invoiceno) as frequency,
sum(revenue) as monetary,
max(invoicedate) as last_purchase_date
from online_retail_products
group by customerid
),
max_date as (
select max(invoicedate) as max_date
from online_retail_products
),
rfm_base as (
select c.customerid, c.frequency, c.monetary,
datediff(m.max_date, c.last_purchase_date) as recency
from customer_rfm c
cross join max_date m
),

rfm_scores as(
select customerid, frequency, monetary, recency,
6-ntile(5) over(order by recency asc) as r_score,
6-ntile(5) over(order by frequency desc) as f_score,
6-ntile(5) over(order by monetary desc) as m_score
from rfm_base)

select customerid, frequency, recency, monetary, r_score, f_score, m_score,
case
when r_score>=4 and f_score>=4 and m_score>=4 then "Champions"
when f_score>=4 then "Loyal Customers"
when m_score>=4 then "Big Spenders"
when r_score<=2 then "At Risk"
else "Others" end as customer_segment
from rfm_scores;

create view rfm_segment_summary as
select
    customer_segment,
    COUNT(*) AS customers,
    ROUND(SUM(monetary), 2) AS total_revenue,
    ROUND(
        SUM(monetary) / (SELECT SUM(monetary) FROM customer_rfm_scores),
        4
    ) AS revenue_share_pct
FROM customer_rfm_scores
GROUP BY customer_segment
ORDER BY total_revenue DESC;


## Retention & Cohort View
## retention_repeat_metrics
create or replace view retention_repeat_metrics as 
with first_purchase as (
select customerid, min(date) as first_purchase_date
from online_retail_products
group by customerid
),
repeat_within_7d as (
select distinct o.customerid
from online_retail_products o
join first_purchase f
on o.customerid=f.customerid
where o.date>f.first_purchase_date
and datediff(o.date, f.first_purchase_date)<=7
),
repeat_within_30d as (
select distinct o.customerid
from online_retail_products o
join first_purchase f
on f.customerid=o.customerid
where o.date>f.first_purchase_date
and datediff(o.date, f.first_purchase_date)<=30
),
customer_order_gaps as (
select customerid,
datediff(date,
LAG(date) over(partition by customerid order by date)) as days_between_orders
from (select distinct customerid, date from online_retail_products) t
),
avg_gap as (
select round(avg(days_between_orders),2) as avg_days_between_orders
from customer_order_gaps
where days_between_orders is not null
),
total_customers as (
select count(*) as total_customers
from first_purchase
)
select
(select count(*) from repeat_within_7d) as repeat_within_7d,
(select count(*) from repeat_within_30d) as repeat_within_30d,
(select total_customers from total_customers) as total_customers,
round((select count(*) from repeat_within_7d)/(select total_customers from total_customers),4) as repeat_rate_7d_pct,
round((select count(*) from repeat_within_30d)/(select total_customers from total_customers),4) as repeat_rate_30d_pct,
(select avg_days_between_orders from avg_gap) as avg_days_between_orders;


## retention_interval_distribution
create or replace view retention_interval_distribution as
with first_purchase as (
select customerid, min(date) as first_purchase_date
from online_retail_products
group by customerid
),
first_repeat as (
select o.customerid,
min(date) as first_repeat_date
from online_retail_products o
join first_purchase f
on f.customerid=o.customerid
where date>first_purchase_date
group by o.customerid 
),
repeat_gap as (
select f.customerid,
datediff(r.first_repeat_date, f.first_purchase_date) as days_to_repeat
from first_repeat r
join first_purchase f
on f.customerid=r.customerid
)
select
case
when days_to_repeat between 0 and 7 then '0-7 days'
when days_to_repeat between 8 and 30 then '8-30 days'
when days_to_repeat between 31 and 90 then '31-90 days'
else '90+ days'
end as interval_bucket,
count(*) as customers
from repeat_gap
group by interval_bucket
order by 
case
when interval_bucket ='0-7 days' then 1
when interval_bucket ='8-30 days' then 2
when interval_bucket ='31-90 days' then 3
when interval_bucket ='90+ days' then 4
end;


## cohort_retention_table
CREATE OR REPLACE VIEW cohort_retention_table AS
with first_purchase as (
select customerid, min(date) as first_purchase_date
from online_retail_products
group by customerid
),
cohort_base as (
select o.customerid, 
date_format(f.first_purchase_date,'%Y-%m') as cohort_month,
date_format(o.date,'%Y-%m') as order_month,
timestampdiff(month, date_format(f.first_purchase_date,'%Y-%m-01'), date_format(o.date,'%Y-%m-01')) as cohort_index
from online_retail_products o
join first_purchase f
on f.customerid=o.customerid 
),
cohort_cnt as (
select cohort_month, cohort_index,
count(distinct customerid) as customers_retained
from cohort_base
group by cohort_month, cohort_index
),
cohort_size as (
select cohort_month, customers_retained as cohort_size
from cohort_cnt
where cohort_index=0
)
select c.cohort_month, c.cohort_index, c.customers_retained, s.cohort_size,
round(c.customers_retained/s.cohort_size,4) as retention_rate_pct
from cohort_cnt c
join cohort_size s
on c.cohort_month=s.cohort_month
order by c.cohort_month,c.cohort_index;


## cohort_retention_summary
CREATE OR REPLACE VIEW cohort_retention_summary AS
WITH retention_table AS (
    SELECT *
    FROM cohort_retention_table
)
SELECT
    cohort_month,
    MAX(cohort_size) AS cohort_size,
    MAX(CASE WHEN cohort_index = 0 THEN retention_rate_pct END) AS month_0,
    MAX(CASE WHEN cohort_index = 1 THEN retention_rate_pct END) AS month_1,
    MAX(CASE WHEN cohort_index = 3 THEN retention_rate_pct END) AS month_3,
    MAX(CASE WHEN cohort_index = 6 THEN retention_rate_pct END) AS month_6,
    MAX(CASE WHEN cohort_index = 11 THEN retention_rate_pct END) AS month_11
FROM retention_table
GROUP BY cohort_month
ORDER BY cohort_month;




