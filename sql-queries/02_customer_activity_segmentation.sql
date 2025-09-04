-- =================================================================
-- CUSTOMER ACTIVITY SEGMENTATION ANALYSIS [EASY]
-- =================================================================
-- Business Question: How can we segment customers by engagement levels?
-- Strategic Value: Enable targeted marketing and personalization strategies
-- Technical Implementation: Behavioral segmentation with engagement scoring

WITH customer_engagement AS (
    -- Calculate customer engagement metrics
    SELECT 
        user_pseudo_id as customer_id,
        COUNT(DISTINCT DATE(TIMESTAMP_MICROS(event_timestamp))) as days_active,
        COUNT(*) as total_events,
        COUNT(CASE WHEN event_name = 'page_view' THEN 1 END) as page_views,
        COUNT(CASE WHEN event_name = 'add_to_cart' THEN 1 END) as cart_adds,
        COUNT(CASE WHEN event_name = 'purchase' THEN 1 END) as purchases,
        COUNT(CASE WHEN event_name = 'begin_checkout' THEN 1 END) as checkouts_started,
        -- Calculate session duration (approximate)
        COUNT(CASE WHEN event_name = 'session_start' THEN 1 END) as total_sessions
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    GROUP BY user_pseudo_id
),

engagement_scores AS (
    -- Create engagement scoring system
    SELECT 
        customer_id,
        days_active,
        total_events,
        page_views,
        cart_adds,
        purchases,
        checkouts_started,
        total_sessions,
        -- Weighted engagement score
        (
            (days_active * 2) +           -- Days active weight: 2
            (purchases * 10) +            -- Purchase weight: 10
            (cart_adds * 3) +             -- Cart adds weight: 3
            (checkouts_started * 5) +     -- Checkout weight: 5
            (page_views * 0.5) +          -- Page view weight: 0.5
            (total_sessions * 1)          -- Session weight: 1
        ) as engagement_score,
        -- Calculate averages for comparison
        CASE 
            WHEN purchases > 0 THEN page_views / purchases 
            ELSE page_views 
        END as pages_per_purchase,
        CASE 
            WHEN cart_adds > 0 AND purchases > 0 THEN cart_adds / purchases 
            ELSE 0 
        END as cart_to_purchase_ratio
    FROM customer_engagement
),

customer_segments AS (
    -- Define customer segments based on behavior
    SELECT 
        customer_id,
        days_active,
        total_events,
        page_views,
        cart_adds,
        purchases,
        total_sessions,
        engagement_score,
        pages_per_purchase,
        cart_to_purchase_ratio,
        -- Segment customers by engagement level
        CASE 
            WHEN engagement_score >= 100 AND purchases >= 3 THEN 'VIP Champions'
            WHEN engagement_score >= 50 AND purchases >= 2 THEN 'Loyal Customers'
            WHEN engagement_score >= 25 AND purchases >= 1 THEN 'Active Buyers'
            WHEN engagement_score >= 10 AND cart_adds > 0 THEN 'Engaged Browsers'
            WHEN engagement_score >= 5 THEN 'Casual Visitors'
            ELSE 'New/Low Engagement'
        END as customer_segment,
        -- Business value classification
        CASE 
            WHEN purchases >= 3 THEN 'High Value'
            WHEN purchases >= 1 THEN 'Medium Value'
            WHEN cart_adds > 0 THEN 'Potential Value'
            ELSE 'Discovery Phase'
        END as value_classification
    FROM engagement_scores
)

-- EXECUTIVE SUMMARY: Customer Segmentation Analytics
SELECT 
    customer_segment,
    value_classification,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as segment_percentage,
    -- Key engagement metrics by segment
    ROUND(AVG(engagement_score), 1) as avg_engagement_score,
    ROUND(AVG(days_active), 1) as avg_days_active,
    ROUND(AVG(purchases), 2) as avg_purchases,
    ROUND(AVG(cart_adds), 1) as avg_cart_adds,
    ROUND(AVG(total_sessions), 1) as avg_sessions,
    -- Business intelligence insights
    CASE 
        WHEN AVG(purchases) >= 2 THEN 'Retention Focus'
        WHEN AVG(cart_adds) > AVG(purchases) THEN 'Conversion Focus'
        WHEN AVG(total_sessions) >= 5 THEN 'Engagement Focus'
        ELSE 'Activation Focus'
    END as recommended_strategy
FROM customer_segments
GROUP BY customer_segment, value_classification
ORDER BY avg_engagement_score DESC;

-- =================================================================
-- DETAILED SEGMENT BREAKDOWN FOR STRATEGIC PLANNING
-- =================================================================
SELECT 
    'SEGMENT SUMMARY' as analysis_type,
    customer_segment,
    COUNT(*) as total_customers,
    SUM(purchases) as total_purchases,
    ROUND(AVG(engagement_score), 1) as avg_score,
    -- Strategic recommendations
    CASE 
        WHEN customer_segment = 'VIP Champions' THEN 'Loyalty Programs & Exclusive Offers'
        WHEN customer_segment = 'Loyal Customers' THEN 'Upselling & Cross-selling'
        WHEN customer_segment = 'Active Buyers' THEN 'Retention Campaigns'
        WHEN customer_segment = 'Engaged Browsers' THEN 'Conversion Optimization'
        WHEN customer_segment = 'Casual Visitors' THEN 'Engagement Campaigns'
        ELSE 'Onboarding & Activation'
    END as marketing_strategy
FROM customer_segments
GROUP BY customer_segment
ORDER BY AVG(engagement_score) DESC;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. Customer Segments: Behavioral-based customer grouping
-- 2. Engagement Score: Weighted activity measurement
-- 3. Value Classification: Revenue potential assessment
-- 4. Strategic Recommendations: Targeted marketing approaches
-- =================================================================