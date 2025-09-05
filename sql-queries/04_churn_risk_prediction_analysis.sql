-- =================================================================
-- CHURN RISK PREDICTION ANALYSIS [MEDIUM]
-- =================================================================
-- Business Question: Which customers haven't purchased recently and might churn?
-- Strategic Value: Identify at-risk customers for retention campaigns

-- Customer churn risk analysis
SELECT 
    customer_id,
    last_order_date,
    days_since_last_order,
    total_orders,
    total_spent,
    CASE 
        WHEN days_since_last_order > 90 THEN 'High Risk'
        WHEN days_since_last_order > 60 THEN 'Medium Risk'
        WHEN days_since_last_order > 30 THEN 'Low Risk'
        ELSE 'Active'
    END as churn_risk,
    CASE 
        WHEN total_spent >= 1000 THEN 'High Value'
        WHEN total_spent >= 300 THEN 'Medium Value'
        ELSE 'Low Value'
    END as customer_value
FROM (
    SELECT 
        customer_id,
        MAX(order_date) as last_order_date,
        DATEDIFF(CURRENT_DATE, MAX(order_date)) as days_since_last_order,
        COUNT(*) as total_orders,
        SUM(order_amount) as total_spent
    FROM customer_orders
    GROUP BY customer_id
) customer_activity
ORDER BY days_since_last_order DESC;

-- Churn risk summary with action plan
SELECT 
    churn_risk,
    customer_value,
    COUNT(*) as customer_count,
    ROUND(AVG(total_spent), 2) as avg_customer_value,
    CASE 
        WHEN churn_risk = 'High Risk' AND customer_value = 'High Value' THEN 'Personal call + special discount'
        WHEN churn_risk = 'High Risk' THEN 'Email campaign + discount offer'
        WHEN churn_risk = 'Medium Risk' THEN 'Re-engagement email series'
        WHEN churn_risk = 'Low Risk' THEN 'Gentle reminder + product recommendations'
        ELSE 'Continue regular marketing'
    END as recommended_action
FROM (
    SELECT 
        customer_id,
        SUM(order_amount) as total_spent,
        CASE 
            WHEN DATEDIFF(CURRENT_DATE, MAX(order_date)) > 90 THEN 'High Risk'
            WHEN DATEDIFF(CURRENT_DATE, MAX(order_date)) > 60 THEN 'Medium Risk'
            WHEN DATEDIFF(CURRENT_DATE, MAX(order_date)) > 30 THEN 'Low Risk'
            ELSE 'Active'
        END as churn_risk,
        CASE 
            WHEN SUM(order_amount) >= 1000 THEN 'High Value'
            WHEN SUM(order_amount) >= 300 THEN 'Medium Value'
            ELSE 'Low Value'
        END as customer_value
    FROM customer_orders
    GROUP BY customer_id
) risk_analysis
GROUP BY churn_risk, customer_value
ORDER BY 
    CASE churn_risk 
        WHEN 'High Risk' THEN 1 
        WHEN 'Medium Risk' THEN 2 
        WHEN 'Low Risk' THEN 3 
        ELSE 4 
    END,
    avg_customer_value DESC;

-- =================================================================
-- KEY INSIGHTS: At-risk customers prioritized by value for retention
-- =================================================================