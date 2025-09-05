-- =================================================================
-- CUSTOMER JOURNEY ANALYTICS [MEDIUM-HARD]
-- =================================================================
-- Business Question: How do customers progress from first visit to purchase?
-- Strategic Value: Optimize conversion funnel and customer experience

-- Customer journey analysis with conversion metrics
SELECT 
    customer_id,
    first_visit_date,
    first_purchase_date,
    total_visits,
    total_purchases,
    ROUND(total_purchases * 100.0 / total_visits, 2) as conversion_rate,
    CASE 
        WHEN total_purchases >= 5 THEN 'Repeat Buyer'
        WHEN total_purchases >= 2 THEN 'Multi-Purchase'
        WHEN total_purchases = 1 AND total_visits <= 3 THEN 'Quick Convert'
        WHEN total_purchases = 1 THEN 'Slow Convert'
        WHEN total_visits >= 5 THEN 'Browser'
        ELSE 'Visitor'
    END as journey_type
FROM (
    SELECT 
        customer_id,
        MIN(visit_date) as first_visit_date,
        MIN(CASE WHEN purchase_amount > 0 THEN visit_date END) as first_purchase_date,
        COUNT(*) as total_visits,
        SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) as total_purchases
    FROM customer_visits
    GROUP BY customer_id
) journey_data
ORDER BY conversion_rate DESC;

-- Conversion funnel analysis
SELECT 
    funnel_stage,
    customer_count,
    LAG(customer_count) OVER (ORDER BY stage_number) as previous_stage,
    ROUND(customer_count * 100.0 / LAG(customer_count) OVER (ORDER BY stage_number), 2) as conversion_rate
FROM (
    SELECT 1 as stage_number, 'Total Visitors' as funnel_stage, 
           COUNT(DISTINCT customer_id) as customer_count
    FROM customer_visits
    
    UNION ALL
    
    SELECT 2, 'Multiple Visits (2+)', COUNT(DISTINCT customer_id)
    FROM customer_visits 
    GROUP BY customer_id 
    HAVING COUNT(*) >= 2
    
    UNION ALL
    
    SELECT 3, 'First Purchase', COUNT(DISTINCT customer_id)
    FROM customer_visits 
    WHERE purchase_amount > 0
    
    UNION ALL
    
    SELECT 4, 'Repeat Purchase', COUNT(DISTINCT customer_id)
    FROM customer_visits 
    WHERE purchase_amount > 0
    GROUP BY customer_id 
    HAVING COUNT(*) >= 2
) funnel_data
ORDER BY stage_number;

-- Journey optimization recommendations
SELECT 
    journey_type,
    COUNT(*) as customer_count,
    ROUND(AVG(conversion_rate), 2) as avg_conversion_rate,
    CASE 
        WHEN journey_type = 'Browser' THEN 'Focus on conversion tactics'
        WHEN journey_type = 'Slow Convert' THEN 'Simplify purchase process'
        WHEN journey_type = 'Quick Convert' THEN 'Target similar prospects'
        WHEN journey_type = 'Multi-Purchase' THEN 'Upsell opportunities'
        WHEN journey_type = 'Repeat Buyer' THEN 'Loyalty program'
        ELSE 'Improve site engagement'
    END as optimization_focus
FROM (
    SELECT 
        customer_id,
        COUNT(*) as total_visits,
        SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) as total_purchases,
        ROUND(SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as conversion_rate,
        CASE 
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) >= 5 THEN 'Repeat Buyer'
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) >= 2 THEN 'Multi-Purchase'
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) = 1 AND COUNT(*) <= 3 THEN 'Quick Convert'
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) = 1 THEN 'Slow Convert'
            WHEN COUNT(*) >= 5 THEN 'Browser'
            ELSE 'Visitor'
        END as journey_type
    FROM customer_visits
    GROUP BY customer_id
) journey_summary
GROUP BY journey_type
ORDER BY avg_conversion_rate DESC;

-- =================================================================
-- KEY INSIGHTS: Customer journey patterns and funnel optimization
-- =================================================================