-- =================================================================
-- CUSTOMER LIFETIME VALUE RANKING ANALYSIS [MEDIUM]
-- =================================================================
-- Business Question: Which customers have the highest lifetime value?
-- Strategic Value: Prioritize customer retention and identify revenue opportunities
-- Technical Implementation: LTV calculation with ranking

-- Customer lifetime value analysis with ranking
SELECT 
    customer_id,
    first_purchase_date,
    last_purchase_date,
    days_as_customer,
    total_purchases,
    total_spent,
    avg_order_value,
    -- Calculate lifetime value score
    ROUND(total_spent + (total_purchases * 10) + (days_as_customer * 0.5), 2) as ltv_score,
    -- Rank customers by different metrics
    RANK() OVER (ORDER BY total_spent DESC) as spending_rank,
    RANK() OVER (ORDER BY total_purchases DESC) as frequency_rank,
    RANK() OVER (ORDER BY avg_order_value DESC) as avg_order_rank,
    -- Customer tier classification
    CASE 
        WHEN total_spent >= 2000 AND total_purchases >= 5 THEN 'Platinum'
        WHEN total_spent >= 1000 AND total_purchases >= 3 THEN 'Gold'
        WHEN total_spent >= 500 AND total_purchases >= 2 THEN 'Silver'
        WHEN total_spent >= 100 THEN 'Bronze'
        ELSE 'Basic'
    END as customer_tier
FROM (
    -- Calculate customer metrics
    SELECT 
        customer_id,
        MIN(purchase_date) as first_purchase_date,
        MAX(purchase_date) as last_purchase_date,
        MAX(purchase_date) - MIN(purchase_date) as days_as_customer,
        COUNT(*) as total_purchases,
        SUM(purchase_amount) as total_spent,
        ROUND(AVG(purchase_amount), 2) as avg_order_value
    FROM customer_transactions
    WHERE purchase_amount > 0
    GROUP BY customer_id
) customer_ltv_data
ORDER BY ltv_score DESC;

-- LTV segment analysis for business insights
SELECT 
    customer_tier,
    COUNT(*) as customer_count,
    ROUND(AVG(total_spent), 2) as avg_total_spent,
    ROUND(AVG(total_purchases), 1) as avg_purchases,
    ROUND(AVG(avg_order_value), 2) as avg_order_value,
    ROUND(AVG(days_as_customer), 0) as avg_customer_days,
    ROUND(SUM(total_spent), 2) as tier_total_revenue,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as tier_percentage,
    -- Strategic recommendations by tier
    CASE 
        WHEN customer_tier = 'Platinum' THEN 'VIP treatment, exclusive access, personal account manager'
        WHEN customer_tier = 'Gold' THEN 'Premium support, early access to products'
        WHEN customer_tier = 'Silver' THEN 'Loyalty program, targeted offers'
        WHEN customer_tier = 'Bronze' THEN 'Upselling campaigns, bundle offers'
        ELSE 'Basic retention, welcome series'
    END as retention_strategy
FROM (
    SELECT 
        customer_id,
        COUNT(*) as total_purchases,
        SUM(purchase_amount) as total_spent,
        ROUND(AVG(purchase_amount), 2) as avg_order_value,
        MAX(purchase_date) - MIN(purchase_date) as days_as_customer,
        CASE 
            WHEN SUM(purchase_amount) >= 2000 AND COUNT(*) >= 5 THEN 'Platinum'
            WHEN SUM(purchase_amount) >= 1000 AND COUNT(*) >= 3 THEN 'Gold'
            WHEN SUM(purchase_amount) >= 500 AND COUNT(*) >= 2 THEN 'Silver'
            WHEN SUM(purchase_amount) >= 100 THEN 'Bronze'
            ELSE 'Basic'
        END as customer_tier
    FROM customer_transactions
    WHERE purchase_amount > 0
    GROUP BY customer_id
) tier_analysis
GROUP BY customer_tier
ORDER BY avg_total_spent DESC;

-- Top 20 customers by lifetime value
SELECT 
    'TOP CUSTOMERS' as analysis_type,
    customer_id,
    customer_tier,
    total_spent,
    total_purchases,
    avg_order_value,
    days_as_customer,
    spending_rank
FROM (
    SELECT 
        customer_id,
        SUM(purchase_amount) as total_spent,
        COUNT(*) as total_purchases,
        ROUND(AVG(purchase_amount), 2) as avg_order_value,
        MAX(purchase_date) - MIN(purchase_date) as days_as_customer,
        RANK() OVER (ORDER BY SUM(purchase_amount) DESC) as spending_rank,
        CASE 
            WHEN SUM(purchase_amount) >= 2000 AND COUNT(*) >= 5 THEN 'Platinum'
            WHEN SUM(purchase_amount) >= 1000 AND COUNT(*) >= 3 THEN 'Gold'
            WHEN SUM(purchase_amount) >= 500 AND COUNT(*) >= 2 THEN 'Silver'
            WHEN SUM(purchase_amount) >= 100 THEN 'Bronze'
            ELSE 'Basic'
        END as customer_tier
    FROM customer_transactions
    WHERE purchase_amount > 0
    GROUP BY customer_id
) top_customers
WHERE spending_rank <= 20
ORDER BY spending_rank;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. LTV Score: Comprehensive customer value measurement
-- 2. Customer Tiers: Platinum, Gold, Silver, Bronze classification
-- 3. Rankings: Multiple ranking criteria for customer prioritization
-- 4. Retention Strategy: Tier-based customer treatment recommendations
-- =================================================================