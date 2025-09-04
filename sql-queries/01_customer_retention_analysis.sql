-- =================================================================
-- CUSTOMER RETENTION ANALYSIS [EASY]
-- =================================================================
-- Business Question: What is our customer retention rate by month?
-- Strategic Value: Identify retention trends and customer loyalty patterns
-- Technical Implementation: Simple cohort analysis with monthly retention

-- Customer retention analysis using simplified data structure
SELECT 
    customer_id,
    first_purchase_month,
    last_purchase_month,
    -- Calculate months between first and last purchase
    CASE 
        WHEN last_purchase_month = first_purchase_month THEN 'New Customer'
        WHEN last_purchase_month = first_purchase_month + 1 THEN 'Month 1 Return'
        WHEN last_purchase_month = first_purchase_month + 2 THEN 'Month 2 Return'
        ELSE 'Long-term Customer'
    END as retention_category,
    total_purchases,
    total_spent
FROM (
    -- Get customer purchase summary
    SELECT 
        customer_id,
        MIN(purchase_month) as first_purchase_month,
        MAX(purchase_month) as last_purchase_month,
        COUNT(*) as total_purchases,
        SUM(purchase_amount) as total_spent
    FROM customer_purchases
    GROUP BY customer_id
) customer_summary
ORDER BY total_spent DESC;

-- Summary retention metrics
SELECT 
    retention_category,
    COUNT(*) as customer_count,
    ROUND(AVG(total_purchases), 1) as avg_purchases,
    ROUND(AVG(total_spent), 2) as avg_spent,
    -- Calculate percentage of each category
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_purchases), 2) as percentage
FROM (
    SELECT 
        customer_id,
        CASE 
            WHEN MAX(purchase_month) = MIN(purchase_month) THEN 'New Customer'
            WHEN MAX(purchase_month) = MIN(purchase_month) + 1 THEN 'Month 1 Return'
            WHEN MAX(purchase_month) = MIN(purchase_month) + 2 THEN 'Month 2 Return'
            ELSE 'Long-term Customer'
        END as retention_category,
        COUNT(*) as total_purchases,
        SUM(purchase_amount) as total_spent
    FROM customer_purchases
    GROUP BY customer_id
) retention_data
GROUP BY retention_category
ORDER BY customer_count DESC;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. Retention Category: Customer lifecycle classification
-- 2. Customer Count: Number of customers in each retention stage
-- 3. Average Purchases: Purchase frequency by retention level
-- 4. Percentage Distribution: Retention pattern breakdown
-- =================================================================