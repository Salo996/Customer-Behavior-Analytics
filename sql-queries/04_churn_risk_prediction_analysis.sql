-- =================================================================
-- CHURN RISK PREDICTION ANALYSIS [MEDIUM]
-- =================================================================
-- Business Question: Which customers are at highest risk of churning?
-- Strategic Value: Proactive retention strategies and revenue protection
-- Technical Implementation: Behavioral pattern analysis with risk scoring

WITH customer_activity_timeline AS (
    -- Create detailed customer activity timeline
    SELECT 
        user_pseudo_id as customer_id,
        DATE(TIMESTAMP_MICROS(event_timestamp)) as activity_date,
        event_name,
        -- Calculate days since last activity
        DATE_DIFF(
            CURRENT_DATE(), 
            DATE(TIMESTAMP_MICROS(event_timestamp)), 
            DAY
        ) as days_since_activity,
        -- Track purchase events specifically
        CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END as is_purchase,
        -- Extract purchase value
        COALESCE(
            (SELECT CAST(value.double_value AS NUMERIC) 
             FROM UNNEST(event_params) 
             WHERE key = 'value'), 
            (SELECT CAST(value.int_value AS NUMERIC) 
             FROM UNNEST(event_params) 
             WHERE key = 'value'),
            0
        ) as event_value
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

customer_behavioral_patterns AS (
    -- Analyze customer behavior patterns for churn indicators
    SELECT 
        customer_id,
        -- Recency metrics (key churn indicators)
        MIN(days_since_activity) as days_since_last_activity,
        MIN(CASE WHEN is_purchase = 1 THEN days_since_activity END) as days_since_last_purchase,
        MIN(CASE WHEN event_name = 'page_view' THEN days_since_activity END) as days_since_last_visit,
        MIN(CASE WHEN event_name = 'add_to_cart' THEN days_since_activity END) as days_since_last_cart_add,
        
        -- Frequency metrics
        COUNT(DISTINCT activity_date) as total_active_days,
        COUNT(*) as total_events,
        SUM(is_purchase) as total_purchases,
        COUNT(CASE WHEN event_name = 'page_view' THEN 1 END) as total_page_views,
        COUNT(CASE WHEN event_name = 'add_to_cart' THEN 1 END) as total_cart_adds,
        COUNT(CASE WHEN event_name = 'session_start' THEN 1 END) as total_sessions,
        
        -- Monetary metrics
        SUM(CASE WHEN is_purchase = 1 THEN event_value ELSE 0 END) as total_purchase_value,
        AVG(CASE WHEN is_purchase = 1 THEN event_value END) as avg_order_value,
        
        -- Activity timeline
        MIN(activity_date) as first_activity_date,
        MAX(activity_date) as last_activity_date,
        DATE_DIFF(MAX(activity_date), MIN(activity_date), DAY) + 1 as customer_lifespan_days,
        
        -- Engagement patterns
        COUNT(DISTINCT DATE_TRUNC(activity_date, WEEK)) as active_weeks,
        COUNT(DISTINCT DATE_TRUNC(activity_date, MONTH)) as active_months
    FROM customer_activity_timeline
    GROUP BY customer_id
),

churn_risk_scoring AS (
    -- Calculate comprehensive churn risk scores
    SELECT 
        customer_id,
        days_since_last_activity,
        days_since_last_purchase,
        days_since_last_visit,
        total_active_days,
        total_events,
        total_purchases,
        total_purchase_value,
        avg_order_value,
        customer_lifespan_days,
        active_weeks,
        active_months,
        
        -- Recency risk scores (higher days = higher risk)
        CASE 
            WHEN days_since_last_activity <= 7 THEN 1
            WHEN days_since_last_activity <= 14 THEN 2
            WHEN days_since_last_activity <= 30 THEN 3
            WHEN days_since_last_activity <= 60 THEN 4
            WHEN days_since_last_activity <= 90 THEN 5
            ELSE 6
        END as recency_risk_score,
        
        -- Purchase recency risk
        CASE 
            WHEN days_since_last_purchase IS NULL THEN 6  -- Never purchased
            WHEN days_since_last_purchase <= 14 THEN 1
            WHEN days_since_last_purchase <= 30 THEN 2
            WHEN days_since_last_purchase <= 60 THEN 3
            WHEN days_since_last_purchase <= 90 THEN 4
            WHEN days_since_last_purchase <= 180 THEN 5
            ELSE 6
        END as purchase_recency_risk,
        
        -- Frequency risk scores (lower frequency = higher risk)
        CASE 
            WHEN total_purchases >= 5 THEN 1
            WHEN total_purchases >= 3 THEN 2
            WHEN total_purchases >= 2 THEN 3
            WHEN total_purchases >= 1 THEN 4
            ELSE 6  -- No purchases
        END as purchase_frequency_risk,
        
        -- Engagement risk scores
        CASE 
            WHEN total_active_days >= 20 THEN 1
            WHEN total_active_days >= 10 THEN 2
            WHEN total_active_days >= 5 THEN 3
            WHEN total_active_days >= 2 THEN 4
            WHEN total_active_days = 1 THEN 5
            ELSE 6
        END as engagement_risk_score,
        
        -- Activity pattern analysis
        CASE 
            WHEN customer_lifespan_days > 0 
            THEN ROUND(total_active_days / customer_lifespan_days * 100, 2)
            ELSE 0
        END as activity_consistency_percent,
        
        -- Session engagement
        CASE 
            WHEN total_sessions > 0 
            THEN ROUND(total_page_views / total_sessions, 2)
            ELSE 0
        END as avg_pages_per_session
    FROM customer_behavioral_patterns
),

final_churn_risk_assessment AS (
    -- Create final churn risk assessment with composite scoring
    SELECT 
        customer_id,
        days_since_last_activity,
        days_since_last_purchase,
        total_purchases,
        total_purchase_value,
        avg_order_value,
        customer_lifespan_days,
        activity_consistency_percent,
        avg_pages_per_session,
        recency_risk_score,
        purchase_recency_risk,
        purchase_frequency_risk,
        engagement_risk_score,
        
        -- Composite churn risk score (weighted average)
        ROUND(
            (recency_risk_score * 0.3) +           -- 30% weight on general recency
            (purchase_recency_risk * 0.35) +       -- 35% weight on purchase recency
            (purchase_frequency_risk * 0.25) +     -- 25% weight on purchase frequency
            (engagement_risk_score * 0.1),         -- 10% weight on engagement
            2
        ) as composite_churn_risk_score,
        
        -- Risk category classification
        CASE 
            WHEN (
                (recency_risk_score * 0.3) +
                (purchase_recency_risk * 0.35) +
                (purchase_frequency_risk * 0.25) +
                (engagement_risk_score * 0.1)
            ) >= 5.0 THEN 'Critical Risk'
            WHEN (
                (recency_risk_score * 0.3) +
                (purchase_recency_risk * 0.35) +
                (purchase_frequency_risk * 0.25) +
                (engagement_risk_score * 0.1)
            ) >= 4.0 THEN 'High Risk'
            WHEN (
                (recency_risk_score * 0.3) +
                (purchase_recency_risk * 0.35) +
                (purchase_frequency_risk * 0.25) +
                (engagement_risk_score * 0.1)
            ) >= 3.0 THEN 'Medium Risk'
            WHEN (
                (recency_risk_score * 0.3) +
                (purchase_recency_risk * 0.35) +
                (purchase_frequency_risk * 0.25) +
                (engagement_risk_score * 0.1)
            ) >= 2.0 THEN 'Low Risk'
            ELSE 'Very Low Risk'
        END as churn_risk_category,
        
        -- Strategic retention recommendations
        CASE 
            WHEN (
                (recency_risk_score * 0.3) +
                (purchase_recency_risk * 0.35) +
                (purchase_frequency_risk * 0.25) +
                (engagement_risk_score * 0.1)
            ) >= 5.0 THEN 'Immediate intervention: Personal outreach, special offers'
            WHEN (
                (recency_risk_score * 0.3) +
                (purchase_recency_risk * 0.35) +
                (purchase_frequency_risk * 0.25) +
                (engagement_risk_score * 0.1)
            ) >= 4.0 THEN 'Urgent: Targeted email campaign, discount offers'
            WHEN (
                (recency_risk_score * 0.3) +
                (purchase_recency_risk * 0.35) +
                (purchase_frequency_risk * 0.25) +
                (engagement_risk_score * 0.1)
            ) >= 3.0 THEN 'Monitor: Re-engagement campaigns, content marketing'
            ELSE 'Maintain: Continue regular marketing, loyalty programs'
        END as retention_recommendation
    FROM churn_risk_scoring
)

-- EXECUTIVE SUMMARY: Churn Risk Analysis
SELECT 
    churn_risk_category,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as risk_segment_percentage,
    -- Risk metrics
    ROUND(AVG(composite_churn_risk_score), 2) as avg_risk_score,
    ROUND(AVG(days_since_last_activity), 1) as avg_days_since_last_activity,
    ROUND(AVG(COALESCE(days_since_last_purchase, 365)), 1) as avg_days_since_last_purchase,
    -- Business impact
    ROUND(SUM(COALESCE(total_purchase_value, 0)), 2) as total_revenue_at_risk,
    ROUND(AVG(COALESCE(total_purchase_value, 0)), 2) as avg_customer_value,
    ROUND(AVG(total_purchases), 1) as avg_purchase_frequency,
    -- Strategic actions
    retention_recommendation as recommended_action
FROM final_churn_risk_assessment
GROUP BY churn_risk_category, retention_recommendation
ORDER BY avg_risk_score DESC;

-- =================================================================
-- HIGH-RISK CUSTOMERS DETAILED ANALYSIS
-- =================================================================
SELECT 
    'HIGH RISK CUSTOMERS' as analysis_type,
    customer_id,
    churn_risk_category,
    composite_churn_risk_score,
    days_since_last_activity,
    days_since_last_purchase,
    total_purchases,
    total_purchase_value,
    activity_consistency_percent,
    retention_recommendation
FROM final_churn_risk_assessment
WHERE churn_risk_category IN ('Critical Risk', 'High Risk')
ORDER BY composite_churn_risk_score DESC, total_purchase_value DESC
LIMIT 25;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. Churn Risk Categories: Critical, High, Medium, Low, Very Low
-- 2. Composite Risk Score: Multi-factor churn probability
-- 3. Revenue at Risk: Financial impact of potential churn
-- 4. Retention Strategies: Targeted intervention approaches
-- 5. Behavioral Patterns: Activity consistency and engagement
-- =================================================================