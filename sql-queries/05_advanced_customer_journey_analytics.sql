-- =================================================================
-- CUSTOMER JOURNEY ANALYTICS [MEDIUM-HARD]
-- =================================================================
-- Business Question: How do customers progress through our sales funnel?
-- Strategic Value: Optimize conversion paths and improve customer experience
-- Technical Implementation: Journey analysis with conversion tracking

-- Customer journey funnel analysis
SELECT 
    customer_id,
    first_visit_date,
    first_purchase_date,
    total_visits,
    total_purchases,
    conversion_rate,
    avg_days_to_purchase,
    -- Journey classification
    CASE 
        WHEN total_purchases >= 5 THEN 'Repeat Buyer'
        WHEN total_purchases >= 2 THEN 'Multi-Purchase'
        WHEN total_purchases = 1 AND total_visits <= 3 THEN 'Quick Converter'
        WHEN total_purchases = 1 AND total_visits > 3 THEN 'Slow Converter'
        WHEN total_visits >= 5 THEN 'Browser'
        ELSE 'One-Time Visitor'
    END as journey_type,
    -- Purchase efficiency
    CASE 
        WHEN conversion_rate >= 50 THEN 'Highly Efficient'
        WHEN conversion_rate >= 25 THEN 'Efficient'
        WHEN conversion_rate >= 10 THEN 'Average'
        ELSE 'Inefficient'
    END as conversion_efficiency
FROM (
    -- Calculate customer journey metrics
    SELECT 
        customer_id,
        MIN(visit_date) as first_visit_date,
        MIN(CASE WHEN purchase_amount > 0 THEN visit_date END) as first_purchase_date,
        COUNT(*) as total_visits,
        SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) as total_purchases,
        ROUND(
            SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
        ) as conversion_rate,
        ROUND(
            AVG(CASE WHEN purchase_amount > 0 THEN 
                visit_date - MIN(visit_date) OVER (PARTITION BY customer_id) 
            END), 1
        ) as avg_days_to_purchase
    FROM customer_activity_log
    GROUP BY customer_id
) journey_metrics
ORDER BY total_purchases DESC, conversion_rate DESC;

-- Journey type analysis for business insights
SELECT 
    journey_type,
    COUNT(*) as customer_count,
    ROUND(AVG(total_visits), 1) as avg_visits,
    ROUND(AVG(total_purchases), 1) as avg_purchases,
    ROUND(AVG(conversion_rate), 2) as avg_conversion_rate,
    ROUND(AVG(avg_days_to_purchase), 1) as avg_days_to_convert,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage_of_customers,
    -- Optimization recommendations
    CASE 
        WHEN journey_type = 'Browser' THEN 'Focus on conversion tactics - product demos, trials, urgency'
        WHEN journey_type = 'Slow Converter' THEN 'Streamline purchase process, reduce friction'
        WHEN journey_type = 'Quick Converter' THEN 'Expand reach - this is ideal customer behavior'
        WHEN journey_type = 'Multi-Purchase' THEN 'Upsell and cross-sell opportunities'
        WHEN journey_type = 'Repeat Buyer' THEN 'Loyalty programs and VIP treatment'
        ELSE 'Improve initial engagement and site experience'
    END as optimization_strategy
FROM (
    SELECT 
        customer_id,
        COUNT(*) as total_visits,
        SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) as total_purchases,
        ROUND(
            SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
        ) as conversion_rate,
        AVG(CASE WHEN purchase_amount > 0 THEN 
            visit_date - MIN(visit_date) OVER (PARTITION BY customer_id) 
        END) as avg_days_to_purchase,
        CASE 
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) >= 5 THEN 'Repeat Buyer'
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) >= 2 THEN 'Multi-Purchase'
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) = 1 AND COUNT(*) <= 3 THEN 'Quick Converter'
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) = 1 AND COUNT(*) > 3 THEN 'Slow Converter'
            WHEN COUNT(*) >= 5 THEN 'Browser'
            ELSE 'One-Time Visitor'
        END as journey_type
    FROM customer_activity_log
    GROUP BY customer_id
) journey_analysis
GROUP BY journey_type
ORDER BY avg_conversion_rate DESC;

-- Conversion funnel analysis
SELECT 
    funnel_stage,
    customer_count,
    ROUND(customer_count * 100.0 / LAG(customer_count) OVER (ORDER BY stage_order), 2) as conversion_rate,
    ROUND(customer_count * 100.0 / FIRST_VALUE(customer_count) OVER (ORDER BY stage_order), 2) as overall_rate
FROM (
    SELECT 
        1 as stage_order,
        'Total Visitors' as funnel_stage,
        COUNT(DISTINCT customer_id) as customer_count
    FROM customer_activity_log
    
    UNION ALL
    
    SELECT 
        2 as stage_order,
        'Engaged Visitors (2+ visits)' as funnel_stage,
        COUNT(DISTINCT customer_id) as customer_count
    FROM customer_activity_log
    GROUP BY customer_id
    HAVING COUNT(*) >= 2
    
    UNION ALL
    
    SELECT 
        3 as stage_order,
        'Active Browsers (5+ visits)' as funnel_stage,
        COUNT(DISTINCT customer_id) as customer_count
    FROM customer_activity_log
    GROUP BY customer_id
    HAVING COUNT(*) >= 5
    
    UNION ALL
    
    SELECT 
        4 as stage_order,
        'First-Time Buyers' as funnel_stage,
        COUNT(DISTINCT customer_id) as customer_count
    FROM customer_activity_log
    WHERE purchase_amount > 0
    
    UNION ALL
    
    SELECT 
        5 as stage_order,
        'Repeat Buyers (2+ purchases)' as funnel_stage,
        COUNT(DISTINCT customer_id) as customer_count
    FROM customer_activity_log
    WHERE purchase_amount > 0
    GROUP BY customer_id
    HAVING COUNT(*) >= 2
) funnel_data
ORDER BY stage_order;

-- Journey optimization insights
SELECT 
    'JOURNEY OPTIMIZATION SUMMARY' as analysis_type,
    -- Overall conversion metrics
    ROUND(
        COUNT(CASE WHEN total_purchases > 0 THEN 1 END) * 100.0 / COUNT(*), 2
    ) as overall_conversion_rate,
    ROUND(AVG(total_visits), 1) as avg_visits_per_customer,
    ROUND(AVG(CASE WHEN total_purchases > 0 THEN avg_days_to_purchase END), 1) as avg_days_to_first_purchase,
    -- Key insights
    'Focus on converting browsers to buyers - largest opportunity' as primary_recommendation,
    'Optimize for quick converters - highest efficiency segment' as secondary_recommendation
FROM (
    SELECT 
        customer_id,
        COUNT(*) as total_visits,
        SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) as total_purchases,
        AVG(CASE WHEN purchase_amount > 0 THEN 
            visit_date - MIN(visit_date) OVER (PARTITION BY customer_id) 
        END) as avg_days_to_purchase
    FROM customer_activity_log
    GROUP BY customer_id
) summary_metrics;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. Journey Types: Customer behavior classification by purchase patterns
-- 2. Conversion Efficiency: Rate of visits that result in purchases
-- 3. Funnel Analysis: Step-by-step conversion rates through customer journey
-- 4. Optimization Strategies: Targeted improvement recommendations by segment
-- =================================================================