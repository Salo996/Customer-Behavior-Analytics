-- =================================================================
-- CUSTOMER ACTIVITY SEGMENTATION ANALYSIS [EASY]
-- =================================================================
-- Business Question: How can we group customers by their spending behavior?
-- Strategic Value: Create targeted marketing campaigns for different customer types

-- Customer segmentation by spending and activity
SELECT 
    customer_id,
    total_orders,
    total_spent,
    avg_order_value,
    CASE 
        WHEN total_spent >= 1000 THEN 'VIP Customer'
        WHEN total_spent >= 500 THEN 'Premium Customer'
        WHEN total_spent >= 100 THEN 'Regular Customer'
        ELSE 'Budget Customer'
    END as customer_segment
FROM (
    SELECT 
        customer_id,
        COUNT(*) as total_orders,
        SUM(order_amount) as total_spent,
        ROUND(AVG(order_amount), 2) as avg_order_value
    FROM customer_orders
    GROUP BY customer_id
) customer_metrics
ORDER BY total_spent DESC;

-- Segment summary with marketing recommendations
SELECT 
    customer_segment,
    COUNT(*) as customer_count,
    ROUND(AVG(total_spent), 2) as avg_spending,
    CASE 
        WHEN customer_segment = 'VIP Customer' THEN 'Exclusive offers and personal service'
        WHEN customer_segment = 'Premium Customer' THEN 'Loyalty program and early access'
        WHEN customer_segment = 'Regular Customer' THEN 'Standard promotions and discounts'
        ELSE 'Welcome campaigns and onboarding'
    END as marketing_strategy
FROM (
    SELECT 
        customer_id,
        SUM(order_amount) as total_spent,
        CASE 
            WHEN SUM(order_amount) >= 1000 THEN 'VIP Customer'
            WHEN SUM(order_amount) >= 500 THEN 'Premium Customer'
            WHEN SUM(order_amount) >= 100 THEN 'Regular Customer'
            ELSE 'Budget Customer'
        END as customer_segment
    FROM customer_orders
    GROUP BY customer_id
) segment_data
GROUP BY customer_segment
ORDER BY avg_spending DESC;

-- =================================================================
-- KEY INSIGHTS: Customer segments with tailored marketing strategies
-- =================================================================