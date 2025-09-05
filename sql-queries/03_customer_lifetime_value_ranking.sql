-- =================================================================
-- CUSTOMER LIFETIME VALUE RANKING ANALYSIS [MEDIUM]
-- =================================================================
-- Business Question: Which customers are most valuable for retention efforts?
-- Strategic Value: Prioritize high-value customers for special treatment

-- Customer LTV ranking with window functions
SELECT 
    customer_id,
    total_orders,
    total_revenue,
    avg_order_value,
    days_as_customer,
    -- Rank customers by different metrics
    RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank,
    RANK() OVER (ORDER BY total_orders DESC) as frequency_rank,
    -- Customer tier based on value
    CASE 
        WHEN total_revenue >= 2000 THEN 'Platinum'
        WHEN total_revenue >= 1000 THEN 'Gold'
        WHEN total_revenue >= 500 THEN 'Silver'
        ELSE 'Bronze'
    END as customer_tier
FROM (
    SELECT 
        customer_id,
        COUNT(*) as total_orders,
        SUM(order_amount) as total_revenue,
        ROUND(AVG(order_amount), 2) as avg_order_value,
        DATEDIFF(MAX(order_date), MIN(order_date)) as days_as_customer
    FROM customer_orders
    GROUP BY customer_id
) customer_ltv
ORDER BY total_revenue DESC;

-- Top 20 customers by lifetime value
SELECT 
    customer_id,
    customer_tier,
    total_revenue,
    total_orders,
    revenue_rank,
    CASE 
        WHEN customer_tier = 'Platinum' THEN 'VIP treatment and exclusive access'
        WHEN customer_tier = 'Gold' THEN 'Premium support and early access'
        WHEN customer_tier = 'Silver' THEN 'Loyalty rewards and special offers'
        ELSE 'Standard retention campaigns'
    END as retention_strategy
FROM (
    SELECT 
        customer_id,
        SUM(order_amount) as total_revenue,
        COUNT(*) as total_orders,
        RANK() OVER (ORDER BY SUM(order_amount) DESC) as revenue_rank,
        CASE 
            WHEN SUM(order_amount) >= 2000 THEN 'Platinum'
            WHEN SUM(order_amount) >= 1000 THEN 'Gold'
            WHEN SUM(order_amount) >= 500 THEN 'Silver'
            ELSE 'Bronze'
        END as customer_tier
    FROM customer_orders
    GROUP BY customer_id
) ranked_customers
WHERE revenue_rank <= 20
ORDER BY revenue_rank;

-- =================================================================
-- KEY INSIGHTS: High-value customers ranked for retention investment
-- =================================================================