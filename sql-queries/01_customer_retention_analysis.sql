-- =================================================================
-- CUSTOMER RETENTION ANALYSIS [EASY]
-- =================================================================
-- Business Question: How many customers return after their first purchase?
-- Strategic Value: Identify retention patterns for marketing campaigns

-- Simple customer retention analysis
SELECT 
    customer_id,
    first_purchase_date,
    last_purchase_date,
    total_purchases,
    CASE 
        WHEN total_purchases = 1 THEN 'One-time Customer'
        WHEN total_purchases = 2 THEN 'Returning Customer'
        WHEN total_purchases >= 3 THEN 'Loyal Customer'
    END as customer_type
FROM (
    SELECT 
        customer_id,
        MIN(purchase_date) as first_purchase_date,
        MAX(purchase_date) as last_purchase_date,
        COUNT(*) as total_purchases
    FROM customer_purchases
    GROUP BY customer_id
) customer_summary
ORDER BY total_purchases DESC;

-- Retention summary
SELECT 
    customer_type,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM (
    SELECT 
        CASE 
            WHEN COUNT(*) = 1 THEN 'One-time Customer'
            WHEN COUNT(*) = 2 THEN 'Returning Customer'
            WHEN COUNT(*) >= 3 THEN 'Loyal Customer'
        END as customer_type
    FROM customer_purchases
    GROUP BY customer_id
) retention_data
GROUP BY customer_type
ORDER BY customer_count DESC;

-- =================================================================
-- KEY INSIGHTS: Shows customer loyalty distribution and retention rates
-- =================================================================