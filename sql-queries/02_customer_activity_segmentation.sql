-- =================================================================
-- CUSTOMER ACTIVITY SEGMENTATION ANALYSIS [EASY]
-- =================================================================
-- Business Question: How can we segment customers by their activity levels?
-- Strategic Value: Enable targeted marketing and personalization strategies
-- Technical Implementation: Simple customer behavior grouping

-- Customer activity segmentation analysis
SELECT 
    customer_id,
    total_visits,
    total_purchases,
    total_spent,
    -- Simple activity scoring
    (total_visits * 1) + (total_purchases * 5) + (total_spent * 0.1) as activity_score,
    -- Customer segmentation based on activity
    CASE 
        WHEN total_purchases >= 5 AND total_spent >= 1000 THEN 'VIP Customer'
        WHEN total_purchases >= 3 AND total_spent >= 500 THEN 'Loyal Customer'
        WHEN total_purchases >= 1 AND total_spent >= 100 THEN 'Regular Customer'
        WHEN total_visits >= 5 THEN 'Active Browser'
        ELSE 'New Visitor'
    END as customer_segment,
    -- Value classification
    CASE 
        WHEN total_spent >= 1000 THEN 'High Value'
        WHEN total_spent >= 300 THEN 'Medium Value'
        WHEN total_spent >= 50 THEN 'Low Value'
        ELSE 'No Purchase'
    END as value_tier
FROM (
    -- Calculate customer activity metrics
    SELECT 
        customer_id,
        COUNT(*) as total_visits,
        SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) as total_purchases,
        SUM(CASE WHEN purchase_amount > 0 THEN purchase_amount ELSE 0 END) as total_spent
    FROM customer_activity
    GROUP BY customer_id
) customer_metrics
ORDER BY activity_score DESC;

-- Segment summary for business insights
SELECT 
    customer_segment,
    COUNT(*) as customer_count,
    ROUND(AVG(total_visits), 1) as avg_visits,
    ROUND(AVG(total_purchases), 1) as avg_purchases,
    ROUND(AVG(total_spent), 2) as avg_spent,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as segment_percentage,
    -- Marketing strategy recommendation
    CASE 
        WHEN customer_segment = 'VIP Customer' THEN 'Premium rewards & exclusive offers'
        WHEN customer_segment = 'Loyal Customer' THEN 'Loyalty program & upselling'
        WHEN customer_segment = 'Regular Customer' THEN 'Retention campaigns'
        WHEN customer_segment = 'Active Browser' THEN 'Conversion optimization'
        ELSE 'Welcome & onboarding campaigns'
    END as marketing_strategy
FROM (
    SELECT 
        customer_id,
        COUNT(*) as total_visits,
        SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) as total_purchases,
        SUM(CASE WHEN purchase_amount > 0 THEN purchase_amount ELSE 0 END) as total_spent,
        CASE 
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) >= 5 
                AND SUM(CASE WHEN purchase_amount > 0 THEN purchase_amount ELSE 0 END) >= 1000 THEN 'VIP Customer'
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) >= 3 
                AND SUM(CASE WHEN purchase_amount > 0 THEN purchase_amount ELSE 0 END) >= 500 THEN 'Loyal Customer'
            WHEN SUM(CASE WHEN purchase_amount > 0 THEN 1 ELSE 0 END) >= 1 
                AND SUM(CASE WHEN purchase_amount > 0 THEN purchase_amount ELSE 0 END) >= 100 THEN 'Regular Customer'
            WHEN COUNT(*) >= 5 THEN 'Active Browser'
            ELSE 'New Visitor'
        END as customer_segment
    FROM customer_activity
    GROUP BY customer_id
) segmentation_data
GROUP BY customer_segment
ORDER BY avg_spent DESC;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. Customer Segment: Behavioral-based customer grouping
-- 2. Activity Score: Simple weighted activity measurement
-- 3. Value Tier: Revenue-based customer classification
-- 4. Marketing Strategy: Segment-specific campaign recommendations
-- =================================================================