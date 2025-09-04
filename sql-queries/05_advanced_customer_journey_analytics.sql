-- =================================================================
-- ADVANCED CUSTOMER JOURNEY ANALYTICS [MEDIUM-HARD]
-- =================================================================
-- Business Question: What are the optimal customer journey paths to conversion?
-- Strategic Value: Optimize marketing funnels and improve conversion rates
-- Technical Implementation: Multi-touch attribution and path analysis

WITH customer_events_sequenced AS (
    -- Create sequenced customer journey events with advanced analytics
    SELECT 
        user_pseudo_id as customer_id,
        event_name,
        DATE(TIMESTAMP_MICROS(event_timestamp)) as event_date,
        TIMESTAMP_MICROS(event_timestamp) as event_timestamp,
        -- Create session-based sequencing
        LAG(event_name) OVER (
            PARTITION BY user_pseudo_id 
            ORDER BY TIMESTAMP_MICROS(event_timestamp)
        ) as previous_event,
        LEAD(event_name) OVER (
            PARTITION BY user_pseudo_id 
            ORDER BY TIMESTAMP_MICROS(event_timestamp)
        ) as next_event,
        -- Event sequencing within customer journey
        ROW_NUMBER() OVER (
            PARTITION BY user_pseudo_id 
            ORDER BY TIMESTAMP_MICROS(event_timestamp)
        ) as event_sequence_number,
        -- Time between events
        TIMESTAMP_DIFF(
            TIMESTAMP_MICROS(event_timestamp),
            LAG(TIMESTAMP_MICROS(event_timestamp)) OVER (
                PARTITION BY user_pseudo_id 
                ORDER BY TIMESTAMP_MICROS(event_timestamp)
            ),
            MINUTE
        ) as minutes_since_previous_event,
        -- Extract event value for revenue attribution
        COALESCE(
            (SELECT CAST(value.double_value AS NUMERIC) 
             FROM UNNEST(event_params) 
             WHERE key = 'value'), 
            (SELECT CAST(value.int_value AS NUMERIC) 
             FROM UNNEST(event_params) 
             WHERE key = 'value'),
            0
        ) as event_value,
        -- Session identification (new session if >30 minutes gap)
        SUM(CASE 
            WHEN TIMESTAMP_DIFF(
                TIMESTAMP_MICROS(event_timestamp),
                LAG(TIMESTAMP_MICROS(event_timestamp)) OVER (
                    PARTITION BY user_pseudo_id 
                    ORDER BY TIMESTAMP_MICROS(event_timestamp)
                ),
                MINUTE
            ) > 30 OR LAG(TIMESTAMP_MICROS(event_timestamp)) OVER (
                PARTITION BY user_pseudo_id 
                ORDER BY TIMESTAMP_MICROS(event_timestamp)
            ) IS NULL THEN 1 
            ELSE 0 
        END) OVER (
            PARTITION BY user_pseudo_id 
            ORDER BY TIMESTAMP_MICROS(event_timestamp) 
            ROWS UNBOUNDED PRECEDING
        ) as session_number
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND user_pseudo_id IS NOT NULL
),

customer_journey_paths AS (
    -- Analyze customer journey paths and conversion funnels
    SELECT 
        customer_id,
        session_number,
        -- Key journey milestones
        MIN(CASE WHEN event_name = 'session_start' THEN event_sequence_number END) as first_session_start,
        MIN(CASE WHEN event_name = 'page_view' THEN event_sequence_number END) as first_page_view,
        MIN(CASE WHEN event_name = 'view_item' THEN event_sequence_number END) as first_item_view,
        MIN(CASE WHEN event_name = 'add_to_cart' THEN event_sequence_number END) as first_cart_add,
        MIN(CASE WHEN event_name = 'begin_checkout' THEN event_sequence_number END) as first_checkout_start,
        MIN(CASE WHEN event_name = 'purchase' THEN event_sequence_number END) as first_purchase,
        -- Journey metrics
        COUNT(DISTINCT event_name) as unique_event_types,
        COUNT(*) as total_events_in_session,
        MAX(event_sequence_number) - MIN(event_sequence_number) + 1 as session_event_span,
        -- Conversion indicators
        MAX(CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END) as session_converted,
        SUM(CASE WHEN event_name = 'purchase' THEN event_value ELSE 0 END) as session_revenue,
        -- Time analysis
        MIN(event_timestamp) as session_start_time,
        MAX(event_timestamp) as session_end_time,
        TIMESTAMP_DIFF(MAX(event_timestamp), MIN(event_timestamp), MINUTE) as session_duration_minutes
    FROM customer_events_sequenced
    GROUP BY customer_id, session_number
),

conversion_path_analysis AS (
    -- Advanced conversion path and multi-touch attribution analysis
    SELECT 
        cjp.customer_id,
        -- Customer journey overview
        COUNT(cjp.session_number) as total_sessions,
        SUM(cjp.session_converted) as total_conversions,
        SUM(cjp.session_revenue) as total_customer_revenue,
        AVG(cjp.session_duration_minutes) as avg_session_duration,
        
        -- Journey progression analysis
        COUNT(CASE WHEN cjp.first_page_view IS NOT NULL THEN 1 END) as sessions_with_page_views,
        COUNT(CASE WHEN cjp.first_item_view IS NOT NULL THEN 1 END) as sessions_with_item_views,
        COUNT(CASE WHEN cjp.first_cart_add IS NOT NULL THEN 1 END) as sessions_with_cart_adds,
        COUNT(CASE WHEN cjp.first_checkout_start IS NOT NULL THEN 1 END) as sessions_with_checkout_starts,
        COUNT(CASE WHEN cjp.first_purchase IS NOT NULL THEN 1 END) as sessions_with_purchases,
        
        -- Conversion funnel metrics
        CASE 
            WHEN COUNT(cjp.session_number) > 0 
            THEN ROUND(COUNT(CASE WHEN cjp.first_item_view IS NOT NULL THEN 1 END) * 100.0 / COUNT(cjp.session_number), 2)
            ELSE 0 
        END as page_view_to_item_view_rate,
        
        CASE 
            WHEN COUNT(CASE WHEN cjp.first_item_view IS NOT NULL THEN 1 END) > 0 
            THEN ROUND(COUNT(CASE WHEN cjp.first_cart_add IS NOT NULL THEN 1 END) * 100.0 / COUNT(CASE WHEN cjp.first_item_view IS NOT NULL THEN 1 END), 2)
            ELSE 0 
        END as item_view_to_cart_rate,
        
        CASE 
            WHEN COUNT(CASE WHEN cjp.first_cart_add IS NOT NULL THEN 1 END) > 0 
            THEN ROUND(COUNT(CASE WHEN cjp.first_checkout_start IS NOT NULL THEN 1 END) * 100.0 / COUNT(CASE WHEN cjp.first_cart_add IS NOT NULL THEN 1 END), 2)
            ELSE 0 
        END as cart_to_checkout_rate,
        
        CASE 
            WHEN COUNT(CASE WHEN cjp.first_checkout_start IS NOT NULL THEN 1 END) > 0 
            THEN ROUND(COUNT(CASE WHEN cjp.first_purchase IS NOT NULL THEN 1 END) * 100.0 / COUNT(CASE WHEN cjp.first_checkout_start IS NOT NULL THEN 1 END), 2)
            ELSE 0 
        END as checkout_to_purchase_rate,
        
        -- Overall conversion rate
        CASE 
            WHEN COUNT(cjp.session_number) > 0 
            THEN ROUND(SUM(cjp.session_converted) * 100.0 / COUNT(cjp.session_number), 2)
            ELSE 0 
        END as overall_conversion_rate,
        
        -- Customer value classification
        CASE 
            WHEN SUM(cjp.total_conversions) >= 3 THEN 'High-Value Multi-Purchaser'
            WHEN SUM(cjp.total_conversions) >= 2 THEN 'Repeat Customer' 
            WHEN SUM(cjp.total_conversions) = 1 THEN 'Single Purchaser'
            WHEN COUNT(CASE WHEN cjp.first_cart_add IS NOT NULL THEN 1 END) > 0 THEN 'Cart Abandoner'
            WHEN COUNT(CASE WHEN cjp.first_item_view IS NOT NULL THEN 1 END) > 0 THEN 'Browser'
            ELSE 'Visitor Only'
        END as customer_journey_segment,
        
        -- Journey efficiency metrics
        CASE 
            WHEN SUM(cjp.session_converted) > 0 
            THEN ROUND(COUNT(cjp.session_number) / SUM(cjp.session_converted), 2)
            ELSE COUNT(cjp.session_number)
        END as sessions_to_conversion,
        
        -- Advanced attribution scoring
        CASE 
            WHEN COUNT(cjp.session_number) = 1 AND SUM(cjp.session_converted) = 1 THEN 'Single Session Converter'
            WHEN COUNT(cjp.session_number) > 1 AND SUM(cjp.session_converted) = 1 THEN 'Multi-Session Converter'
            WHEN COUNT(cjp.session_number) > 1 AND SUM(cjp.session_converted) > 1 THEN 'Repeat Multi-Session Converter'
            ELSE 'Non-Converter'
        END as conversion_pattern
    FROM customer_journey_paths cjp
    GROUP BY cjp.customer_id
),

journey_performance_segments AS (
    -- Create performance-based journey segments for strategic analysis
    SELECT 
        customer_journey_segment,
        conversion_pattern,
        COUNT(*) as customer_count,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as segment_percentage,
        -- Performance metrics
        ROUND(AVG(total_sessions), 1) as avg_sessions,
        ROUND(AVG(total_conversions), 2) as avg_conversions,
        ROUND(AVG(total_customer_revenue), 2) as avg_revenue,
        ROUND(AVG(overall_conversion_rate), 2) as avg_conversion_rate,
        ROUND(AVG(sessions_to_conversion), 1) as avg_sessions_to_conversion,
        -- Funnel performance
        ROUND(AVG(page_view_to_item_view_rate), 2) as avg_browse_to_interest_rate,
        ROUND(AVG(item_view_to_cart_rate), 2) as avg_interest_to_consideration_rate,
        ROUND(AVG(cart_to_checkout_rate), 2) as avg_consideration_to_intent_rate,
        ROUND(AVG(checkout_to_purchase_rate), 2) as avg_intent_to_conversion_rate,
        -- Strategic recommendations
        CASE 
            WHEN AVG(checkout_to_purchase_rate) < 50 THEN 'Focus: Checkout optimization'
            WHEN AVG(cart_to_checkout_rate) < 30 THEN 'Focus: Cart abandonment reduction'
            WHEN AVG(item_view_to_cart_rate) < 20 THEN 'Focus: Product page conversion'
            WHEN AVG(page_view_to_item_view_rate) < 40 THEN 'Focus: Navigation and discovery'
            ELSE 'Focus: Acquisition and awareness'
        END as optimization_priority
    FROM conversion_path_analysis
    GROUP BY customer_journey_segment, conversion_pattern
)

-- EXECUTIVE SUMMARY: Customer Journey Analytics
SELECT 
    customer_journey_segment,
    conversion_pattern,
    customer_count,
    segment_percentage,
    avg_sessions,
    avg_conversions,
    avg_revenue,
    avg_conversion_rate,
    avg_sessions_to_conversion,
    -- Journey funnel insights
    avg_browse_to_interest_rate,
    avg_interest_to_consideration_rate, 
    avg_consideration_to_intent_rate,
    avg_intent_to_conversion_rate,
    optimization_priority
FROM journey_performance_segments
ORDER BY avg_revenue DESC, avg_conversion_rate DESC;

-- =================================================================
-- CONVERSION FUNNEL ANALYSIS SUMMARY
-- =================================================================
SELECT 
    'FUNNEL PERFORMANCE' as analysis_type,
    -- Overall funnel metrics
    COUNT(DISTINCT customer_id) as total_customers,
    ROUND(AVG(page_view_to_item_view_rate), 2) as overall_browse_to_interest_rate,
    ROUND(AVG(item_view_to_cart_rate), 2) as overall_interest_to_consideration_rate,
    ROUND(AVG(cart_to_checkout_rate), 2) as overall_consideration_to_intent_rate,
    ROUND(AVG(checkout_to_purchase_rate), 2) as overall_intent_to_conversion_rate,
    ROUND(AVG(overall_conversion_rate), 2) as overall_conversion_rate,
    -- Revenue impact
    ROUND(SUM(total_customer_revenue), 2) as total_revenue,
    ROUND(AVG(total_customer_revenue), 2) as avg_revenue_per_customer,
    -- Efficiency metrics
    ROUND(AVG(sessions_to_conversion), 1) as avg_sessions_to_convert,
    -- Strategic insights
    'Multi-touch attribution and journey optimization' as strategic_focus
FROM conversion_path_analysis
WHERE total_customer_revenue > 0;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. Customer Journey Segments: Behavioral journey classification
-- 2. Conversion Patterns: Single vs. multi-session analysis
-- 3. Funnel Performance: Stage-by-stage conversion rates
-- 4. Multi-Touch Attribution: Revenue attribution across touchpoints
-- 5. Journey Optimization: Strategic improvement recommendations
-- =================================================================