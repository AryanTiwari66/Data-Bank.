USE data_bank;

/******** A. CUSTOMER NODES EXPLORTION ***********/

-- How many unique nodes are there one the Data Bank system? 

SELECT 
    COUNT(DISTINCT node_id) AS nodes_counts
FROM
    customer_nodes; 

-- What is number of nodes per region?
SELECT 
    regions.region_id,
    regions.region_name,
    COUNT(DISTINCT customer_nodes.node_id) AS unique_nodes,
    COUNT(node_id) AS number_of_nodes
FROM
    regions
        INNER JOIN
    data_bank.customer_nodes ON regions.region_id = customer_nodes.region_id
GROUP BY region_id , regions.region_name; 

--  How many customers are allocated to each region?
SELECT 
    regions.region_id,
    regions.region_name,
    COUNT(DISTINCT customer_nodes.customer_id) AS customer_counts
FROM
    regions
        INNER JOIN
    data_bank.customer_nodes ON regions.region_id = customer_nodes.region_id
GROUP BY regions.region_id , regions.region_name;

-- How many days on average are customers reallocated to a different node?
SELECT 
    AVG(DATEDIFF(start_date, end_date)) AS average_reallocation_days
FROM
    customer_nodes
WHERE
    end_date != '99991231';


/**********  B. CUSTOMER TRANSACTION*********/

-- What is the unique count and total amount for each transaction type?
SELECT 
    txn_type,
    COUNT(txn_type) AS unique_count,
    SUM(txn_amount) AS total_amount
FROM
    customer_transactions
GROUP BY txn_type;

-- What is the average total historical counts and amounts for all customers?
WITH cte_deposit AS (
SELECT 
customer_transactions.customer_id,
txn_type,
COUNT( txn_type) AS Totalcount,
AVG(txn_amount) AS Totalamount
FROM customer_transactions
WHERE txn_type = 'deposit' 
GROUP BY customer_id)

SELECT avg(TotalCount) as avg_count, avg(TotalAmount) as avg_amount
from cte_deposit;

 -- What is the average total historical deposit counts and amounts for all customers?
with counts_tab as
(select customer_id, count(txn_type) as TotalCount, 
sum(txn_amount) as TotalAmount
from customer_transactions
where txn_type = 'deposit'
group by customer_id
)

select avg(TotalCount) as avg_count, avg(TotalAmount) as avg_amount
from counts_tab

-- 3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

;with abc as
(
select customer_id, datepart(month,txn_date) as months,
sum(case when txn_type='deposit' then 1 else 0 end) as deposit,
sum(case when txn_type='withdrawl' then 1 else 0 end) as withdrawl,
sum(case when txn_type='purchase' then 1 else 0 end) as purchase
from customer_transactions
group by  datepart(month,txn_date),customer_id
)
select months,count(customer_id) as customers
from abc
where deposit>1 and (withdrawl=1 or purchase=1)
group by months

-- 4. What is the closing balance for each customer at the end of the month?
;with abc as (
select customer_id ,datepart(month,txn_date) as months,
sum(case when txn_type='deposit' then txn_amount 
else -txn_amount 
end) as balance
from customer_transactions
group by customer_id,datepart(month,txn_date)
order by 1
)
select *, sum(balance) over(partition by customer_id order by months asc rows between unbounded preceding and current row) as Closing_balance
from abc
group by customer_id, months, balance
order by customer_id

-- 5. What is the percentage of customers who increase their closing balance by more than 5%?
;with abc as (
select customer_id ,datepart(month,txn_date) as months,
sum(case when txn_type='deposit' then txn_amount 
else -txn_amount 
end) as balance
from customer_transactions
group by customer_id,datepart(month,txn_date)
order by 1
),
close_bal as (
select *, sum(balance) over(partition by customer_id order by months asc rows between unbounded preceding and current row) as Closing_balance
from abc
group by customer_id, months, balance

),
prev_bal as (
select *, lag(Closing_balance)over(partition by customer_id order by months) as prev_bal
from close_bal

),
bal_diff as(
select *,
case when Closing_balance>0 and prev_bal>0 then Closing_balance-prev_bal
when Closing_balance<0 and prev_bal<0 then Closing_balance-prev_bal
when Closing_balance<0 and prev_bal>0 then -(-Closing_balance+prev_bal)
when Closing_balance>0 and prev_bal<0 then (Closing_balance-prev_bal)
end as bal_diff
from prev_bal
where Closing_balance > prev_bal 
order by customer_id
),
bal as(
select *,cast (bal_diff*100 /prev_bal as float) as bal_prcnt
from bal_diff
)
select round(cast(count(distinct customer_id)*100/(select count(distinct customer_id) from customer_transactions) as float),2) as prcnt_customer
from bal 
where  bal_prcnt>5 or bal_prcnt<-5