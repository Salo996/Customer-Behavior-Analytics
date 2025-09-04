-- =================================================================
-- CUSTOMER LIFETIME VALUE RANKING ANALYSIS [MEDIUM]
-- =================================================================
-- Business Question: Which customers have the highest lifetime value potential?
-- Strategic Value: Prioritize customer retention and identify revenue opportunities
-- Technical Implementation: Advanced LTV calculation with predictive scoring

WITH customer_purchase_data AS (
    -- Extract detailed purchase information
    SELECT 
        user_pseudo_id as customer_id,
        DATE(TIMESTAMP_MICROS(event_timestamp)) as purchase_date,
        -- Extract purchase value from event parameters
        COALESCE(
            (SELECT CAST(value.double_value AS NUMERIC) 
             FROM UNNEST(event_params) 
             WHERE key = 'value'), 
            (SELECT CAST(value.int_value AS NUMERIC) 
             FROM UNNEST(event_params) 
             WHERE key = 'value'),
            0
        ) as purchase_value,
        -- Extract currency
        (SELECT value.string_value 
         FROM UNNEST(event_params) 
         WHERE key = 'currency') as currency
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE event_name = 'purchase'
    AND _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND (
        (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'value') > 0
        OR (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'value') > 0
    )
),

customer_behavior_metrics AS (
    -- Calculate comprehensive customer behavior patterns
    SELECT 
        user_pseudo_id as customer_id,
        -- Activity metrics
        COUNT(DISTINCT DATE(TIMESTAMP_MICROS(event_timestamp))) as days_active,
        COUNT(*) as total_events,
        COUNT(CASE WHEN event_name = 'page_view' THEN 1 END) as total_page_views,
        COUNT(CASE WHEN event_name = 'add_to_cart' THEN 1 END) as total_cart_adds,
        COUNT(CASE WHEN event_name = 'begin_checkout' THEN 1 END) as checkout_starts,
        COUNT(CASE WHEN event_name = 'session_start' THEN 1 END) as total_sessions,
        -- Time-based analysis
        MIN(DATE(TIMESTAMP_MICROS(event_timestamp))) as first_seen,
        MAX(DATE(TIMESTAMP_MICROS(event_timestamp))) as last_seen,
        DATE_DIFF(MAX(DATE(TIMESTAMP_MICROS(event_timestamp))), 
                  MIN(DATE(TIMESTAMP_MICROS(event_timestamp))), DAY) + 1 as customer_lifespan_days
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    GROUP BY user_pseudo_id
),

customer_ltv_calculation AS (
    -- Advanced LTV calculation with behavioral scoring
    SELECT 
        cpd.customer_id,
        cbm.first_seen,
        cbm.last_seen,
        cbm.customer_lifespan_days,
        cbm.days_active,
        cbm.total_events,
        cbm.total_page_views,
        cbm.total_cart_adds,
        cbm.checkout_starts,
        cbm.total_sessions,
        -- Purchase metrics
        COUNT(cpd.purchase_date) as total_purchases,
        SUM(cpd.purchase_value) as total_revenue,
        AVG(cpd.purchase_value) as avg_order_value,
        MAX(cpd.purchase_value) as max_order_value,
        -- Advanced LTV calculations
        CASE 
            WHEN cbm.customer_lifespan_days > 0 
            THEN SUM(cpd.purchase_value) / cbm.customer_lifespan_days * 365
            ELSE SUM(cpd.purchase_value)
        END as annualized_ltv,
        -- Behavioral patterns
        CASE 
            WHEN cbm.total_cart_adds > 0 
            THEN COUNT(cpd.purchase_date) / cbm.total_cart_adds 
            ELSE 0 
        END as conversion_rate,
        CASE 
            WHEN cbm.total_sessions > 0 
            THEN cbm.total_page_views / cbm.total_sessions 
            ELSE 0 
        END as avg_pages_per_session,
        -- Engagement intensity
        CASE 
            WHEN cbm.days_active > 0 
            THEN cbm.total_events / cbm.days_active 
            ELSE 0 
        END as daily_engagement_intensity
    FROM customer_purchase_data cpd
    JOIN customer_behavior_metrics cbm ON cpd.customer_id = cbm.customer_id
    GROUP BY 
        cpd.customer_id, cbm.first_seen, cbm.last_seen, cbm.customer_lifespan_days,
        cbm.days_active, cbm.total_events, cbm.total_page_views, 
        cbm.total_cart_adds, cbm.checkout_starts, cbm.total_sessions
),

ltv_ranking_with_segments AS (
    -- Create LTV rankings and customer value segments
    SELECT 
        customer_id,
        total_revenue,
        total_purchases,
        avg_order_value,
        annualized_ltv,
        customer_lifespan_days,
        conversion_rate,
        daily_engagement_intensity,
        -- LTV Rankings
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) as revenue_rank,
        ROW_NUMBER() OVER (ORDER BY annualized_ltv DESC) as ltv_rank,
        ROW_NUMBER() OVER (ORDER BY total_purchases DESC) as frequency_rank,
        ROW_NUMBER() OVER (ORDER BY avg_order_value DESC) as aov_rank,
        -- Percentile rankings for balanced scoring
        PERCENT_RANK() OVER (ORDER BY total_revenue) as revenue_percentile,
        PERCENT_RANK() OVER (ORDER BY total_purchases) as frequency_percentile,
        PERCENT_RANK() OVER (ORDER BY avg_order_value) as aov_percentile,
        PERCENT_RANK() OVER (ORDER BY daily_engagement_intensity) as engagement_percentile,
        -- Composite LTV Score (weighted)
        (
            (PERCENT_RANK() OVER (ORDER BY total_revenue) * 0.4) +
            (PERCENT_RANK() OVER (ORDER BY total_purchases) * 0.3) +
            (PERCENT_RANK() OVER (ORDER BY avg_order_value) * 0.2) +
            (PERCENT_RANK() OVER (ORDER BY daily_engagement_intensity) * 0.1)
        ) * 100 as composite_ltv_score
    FROM customer_ltv_calculation
    WHERE total_revenue > 0
),

final_customer_segments AS (
    -- Final customer value segmentation
    SELECT 
        customer_id,
        total_revenue,
        total_purchases,
        avg_order_value,
        annualized_ltv,
        customer_lifespan_days,
        conversion_rate,
        composite_ltv_score,
        revenue_rank,
        ltv_rank,
        -- Strategic customer segments
        CASE 
            WHEN composite_ltv_score >= 90 THEN 'Platinum VIP'
            WHEN composite_ltv_score >= 75 THEN 'Gold Champions'
            WHEN composite_ltv_score >= 50 THEN 'Silver Loyalists'
            WHEN composite_ltv_score >= 25 THEN 'Bronze Customers'
            ELSE 'Developing Customers'
        END as ltv_segment,
        -- Business strategy recommendations
        CASE 
            WHEN composite_ltv_score >= 90 THEN 'White-glove service, exclusive access'
            WHEN composite_ltv_score >= 75 THEN 'Premium support, early access'
            WHEN composite_ltv_score >= 50 THEN 'Loyalty programs, cross-selling'
            WHEN composite_ltv_score >= 25 THEN 'Retention campaigns, upselling'
            ELSE 'Engagement and activation focus'
        END as retention_strategy
    FROM ltv_ranking_with_segments
)

-- EXECUTIVE SUMMARY: Customer Lifetime Value Analysis
SELECT 
    ltv_segment,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as segment_percentage,
    -- Financial metrics
    ROUND(AVG(total_revenue), 2) as avg_total_revenue,
    ROUND(AVG(annualized_ltv), 2) as avg_annualized_ltv,
    ROUND(AVG(avg_order_value), 2) as avg_order_value,
    ROUND(AVG(total_purchases), 1) as avg_purchase_frequency,
    -- Strategic insights
    ROUND(AVG(composite_ltv_score), 1) as avg_ltv_score,
    ROUND(SUM(total_revenue), 2) as segment_total_revenue,
    ROUND(SUM(total_revenue) * 100.0 / SUM(SUM(total_revenue)) OVER (), 2) as revenue_contribution_percent,
    -- Business recommendations
    retention_strategy
FROM final_customer_segments
GROUP BY ltv_segment, retention_strategy
ORDER BY avg_ltv_score DESC;

-- =================================================================
-- TOP CUSTOMERS DETAILED ANALYSIS
-- =================================================================
SELECT 
    'TOP 20 CUSTOMERS' as analysis_type,
    customer_id,
    ltv_segment,
    total_revenue,
    annualized_ltv,
    total_purchases,
    avg_order_value,
    customer_lifespan_days,
    ROUND(conversion_rate, 3) as conversion_rate,
    composite_ltv_score,
    revenue_rank
FROM final_customer_segments
WHERE revenue_rank <= 20
ORDER BY revenue_rank;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. Customer LTV Ranking: Revenue-based customer prioritization
-- 2. Composite LTV Score: Multi-factor customer value assessment
-- 3. Strategic Segments: Platinum, Gold, Silver, Bronze tiers
-- 4. Retention Strategy: Targeted approach by customer value
-- 5. Revenue Contribution: Pareto analysis of customer value
-- =================================================================