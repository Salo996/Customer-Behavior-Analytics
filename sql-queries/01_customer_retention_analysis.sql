-- =================================================================
-- CUSTOMER RETENTION ANALYSIS [EASY]
-- =================================================================
-- Business Question: What is our customer retention rate by cohort?
-- Strategic Value: Identify retention trends and customer loyalty patterns
-- Technical Implementation: Cohort analysis with month-over-month retention

WITH customer_first_purchase AS (
    -- Identify each customer's first purchase month
    SELECT 
        user_pseudo_id as customer_id,
        MIN(DATE(TIMESTAMP_MICROS(event_timestamp))) as first_purchase_date,
        DATE_TRUNC(MIN(DATE(TIMESTAMP_MICROS(event_timestamp))), MONTH) as cohort_month
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE event_name = 'purchase'
    AND _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    GROUP BY user_pseudo_id
),

customer_purchases AS (
    -- Get all customer purchase dates
    SELECT 
        user_pseudo_id as customer_id,
        DATE(TIMESTAMP_MICROS(event_timestamp)) as purchase_date,
        DATE_TRUNC(DATE(TIMESTAMP_MICROS(event_timestamp)), MONTH) as purchase_month
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE event_name = 'purchase'
    AND _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

retention_data AS (
    -- Calculate retention periods for each customer
    SELECT 
        cfp.customer_id,
        cfp.cohort_month,
        cp.purchase_month,
        DATE_DIFF(cp.purchase_month, cfp.cohort_month, MONTH) as period_number
    FROM customer_first_purchase cfp
    JOIN customer_purchases cp ON cfp.customer_id = cp.customer_id
),

cohort_sizes AS (
    -- Get the size of each cohort
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) as cohort_size
    FROM customer_first_purchase
    GROUP BY cohort_month
),

retention_rates AS (
    -- Calculate retention rates by cohort and period
    SELECT 
        rd.cohort_month,
        rd.period_number,
        COUNT(DISTINCT rd.customer_id) as customers_retained,
        cs.cohort_size,
        ROUND(COUNT(DISTINCT rd.customer_id) * 100.0 / cs.cohort_size, 2) as retention_rate_percent
    FROM retention_data rd
    JOIN cohort_sizes cs ON rd.cohort_month = cs.cohort_month
    GROUP BY rd.cohort_month, rd.period_number, cs.cohort_size
)

-- EXECUTIVE SUMMARY: Customer Retention Analytics
SELECT 
    cohort_month,
    period_number,
    cohort_size,
    customers_retained,
    retention_rate_percent,
    CASE 
        WHEN period_number = 0 THEN 'New Customers'
        WHEN period_number = 1 THEN 'Month 1 Retention'
        WHEN period_number = 2 THEN 'Month 2 Retention'
        WHEN period_number = 3 THEN 'Month 3+ Retention'
        ELSE CONCAT('Month ', period_number, ' Retention')
    END as retention_stage,
    -- Business Intelligence Insights
    CASE 
        WHEN retention_rate_percent >= 50 THEN 'Excellent Retention'
        WHEN retention_rate_percent >= 30 THEN 'Good Retention'
        WHEN retention_rate_percent >= 15 THEN 'Average Retention'
        ELSE 'Needs Improvement'
    END as retention_quality
FROM retention_rates
ORDER BY cohort_month, period_number;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. Cohort Month: Customer acquisition period
-- 2. Retention Rate: Percentage of customers returning each month
-- 3. Customer Lifecycle: From acquisition to loyal repeat customers
-- 4. Strategic Focus: Identify highest-value retention periods
-- =================================================================