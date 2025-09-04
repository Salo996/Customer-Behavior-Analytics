-- =================================================================
-- CHURN RISK PREDICTION ANALYSIS [MEDIUM]
-- =================================================================
-- Business Question: Which customers are at risk of churning?
-- Strategic Value: Proactive retention strategies and revenue protection
-- Technical Implementation: Risk scoring based on customer behavior patterns

-- Customer churn risk analysis
SELECT 
    customer_id,
    last_purchase_date,
    days_since_last_purchase,
    total_purchases,
    total_spent,
    avg_order_value,
    -- Calculate churn risk score (higher score = higher risk)
    CASE 
        WHEN days_since_last_purchase >= 90 THEN 5
        WHEN days_since_last_purchase >= 60 THEN 4
        WHEN days_since_last_purchase >= 30 THEN 3
        WHEN days_since_last_purchase >= 14 THEN 2
        ELSE 1
    END +
    CASE 
        WHEN total_purchases = 1 THEN 3
        WHEN total_purchases = 2 THEN 2
        WHEN total_purchases <= 5 THEN 1
        ELSE 0
    END as churn_risk_score,
    -- Risk category classification
    CASE 
        WHEN days_since_last_purchase >= 90 AND total_purchases <= 2 THEN 'Critical Risk'
        WHEN days_since_last_purchase >= 60 THEN 'High Risk'
        WHEN days_since_last_purchase >= 30 THEN 'Medium Risk'
        WHEN days_since_last_purchase >= 14 THEN 'Low Risk'
        ELSE 'Active Customer'
    END as risk_category,
    -- Customer value assessment
    CASE 
        WHEN total_spent >= 1000 THEN 'High Value'
        WHEN total_spent >= 300 THEN 'Medium Value'
        WHEN total_spent >= 100 THEN 'Low Value'
        ELSE 'Minimal Value'
    END as customer_value
FROM (
    -- Calculate customer behavior metrics
    SELECT 
        customer_id,
        MAX(purchase_date) as last_purchase_date,
        CURRENT_DATE - MAX(purchase_date) as days_since_last_purchase,
        COUNT(*) as total_purchases,
        SUM(purchase_amount) as total_spent,
        ROUND(AVG(purchase_amount), 2) as avg_order_value
    FROM customer_transactions
    WHERE purchase_amount > 0
    GROUP BY customer_id
) customer_behavior
ORDER BY churn_risk_score DESC, total_spent DESC;

-- Churn risk summary by category
SELECT 
    risk_category,
    COUNT(*) as customer_count,
    ROUND(AVG(days_since_last_purchase), 0) as avg_days_inactive,
    ROUND(AVG(total_purchases), 1) as avg_purchases,
    ROUND(AVG(total_spent), 2) as avg_spent,
    ROUND(SUM(total_spent), 2) as total_revenue_at_risk,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage_of_customers,
    -- Retention strategy recommendations
    CASE 
        WHEN risk_category = 'Critical Risk' THEN 'Immediate personal outreach + discount offer'
        WHEN risk_category = 'High Risk' THEN 'Targeted email campaign + special promotion'
        WHEN risk_category = 'Medium Risk' THEN 'Re-engagement campaign + product recommendations'
        WHEN risk_category = 'Low Risk' THEN 'Gentle reminder + loyalty program'
        ELSE 'Continue regular marketing'
    END as recommended_action
FROM (
    SELECT 
        customer_id,
        CURRENT_DATE - MAX(purchase_date) as days_since_last_purchase,
        COUNT(*) as total_purchases,
        SUM(purchase_amount) as total_spent,
        CASE 
            WHEN CURRENT_DATE - MAX(purchase_date) >= 90 AND COUNT(*) <= 2 THEN 'Critical Risk'
            WHEN CURRENT_DATE - MAX(purchase_date) >= 60 THEN 'High Risk'
            WHEN CURRENT_DATE - MAX(purchase_date) >= 30 THEN 'Medium Risk'
            WHEN CURRENT_DATE - MAX(purchase_date) >= 14 THEN 'Low Risk'
            ELSE 'Active Customer'
        END as risk_category
    FROM customer_transactions
    WHERE purchase_amount > 0
    GROUP BY customer_id
) risk_analysis
GROUP BY risk_category
ORDER BY avg_spent DESC;

-- High-risk customers requiring immediate attention
SELECT 
    'HIGH PRIORITY CUSTOMERS' as priority_level,
    customer_id,
    risk_category,
    days_since_last_purchase,
    total_purchases,
    total_spent,
    customer_value,
    -- Urgency level
    CASE 
        WHEN risk_category = 'Critical Risk' AND total_spent >= 500 THEN 'URGENT - High Value'
        WHEN risk_category = 'Critical Risk' THEN 'URGENT'
        WHEN risk_category = 'High Risk' AND total_spent >= 300 THEN 'HIGH - Medium Value'
        ELSE 'HIGH'
    END as urgency_level
FROM (
    SELECT 
        customer_id,
        CURRENT_DATE - MAX(purchase_date) as days_since_last_purchase,
        COUNT(*) as total_purchases,
        SUM(purchase_amount) as total_spent,
        CASE 
            WHEN CURRENT_DATE - MAX(purchase_date) >= 90 AND COUNT(*) <= 2 THEN 'Critical Risk'
            WHEN CURRENT_DATE - MAX(purchase_date) >= 60 THEN 'High Risk'
            ELSE 'Lower Risk'
        END as risk_category,
        CASE 
            WHEN SUM(purchase_amount) >= 1000 THEN 'High Value'
            WHEN SUM(purchase_amount) >= 300 THEN 'Medium Value'
            WHEN SUM(purchase_amount) >= 100 THEN 'Low Value'
            ELSE 'Minimal Value'
        END as customer_value
    FROM customer_transactions
    WHERE purchase_amount > 0
    GROUP BY customer_id
) high_risk_customers
WHERE risk_category IN ('Critical Risk', 'High Risk')
ORDER BY total_spent DESC, days_since_last_purchase DESC
LIMIT 25;

-- =================================================================
-- KEY BUSINESS METRICS:
-- 1. Churn Risk Score: Behavioral risk assessment (1-8 scale)
-- 2. Risk Categories: Critical, High, Medium, Low risk classification
-- 3. Revenue at Risk: Financial impact of potential customer loss
-- 4. Recommended Actions: Specific retention strategies by risk level
-- =================================================================