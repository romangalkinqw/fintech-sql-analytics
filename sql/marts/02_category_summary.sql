-- =====================================================
-- ВИТРИНА 2: СВОДКА ПО КАТЕГОРИЯМ ТРАНЗАКЦИЙ
-- =====================================================

DROP TABLE IF EXISTS mart_category_summary CASCADE;

CREATE TABLE mart_category_summary AS
WITH category_base AS (
    SELECT 
        description as category,
        COUNT(*) as transaction_count,
        COUNT(DISTINCT transaction_date) as active_days,
        MIN(transaction_date) as first_seen,
        MAX(transaction_date) as last_seen,
        SUM(debit) as total_debit,
        SUM(credit) as total_credit,
        AVG(debit) as avg_debit,
        AVG(credit) as avg_credit,
        SUM(is_suspicious) as suspicious_count,
        AVG(is_suspicious) as suspicious_rate
    FROM fact_transactions
    GROUP BY description
    HAVING COUNT(*) > 5  -- только категории с активностью
)
SELECT 
    category,
    transaction_count,
    active_days,
    first_seen,
    last_seen,
    (CURRENT_DATE - last_seen) as days_since_last,
    ROUND(COALESCE(total_debit, 0)::numeric, 2) as total_debit,
    ROUND(COALESCE(total_credit, 0)::numeric, 2) as total_credit,
    ROUND(COALESCE(total_debit + total_credit, 0)::numeric, 2) as total_volume,
    ROUND(COALESCE(avg_debit, 0)::numeric, 2) as avg_debit,
    ROUND(COALESCE(avg_credit, 0)::numeric, 2) as avg_credit,
    suspicious_count,
    ROUND(100.0 * suspicious_rate, 2) as suspicious_percentage,
    -- Сегментация
    CASE 
        WHEN COALESCE(total_debit + total_credit, 0) > 1000000 THEN 'HIGH VALUE'
        WHEN COALESCE(total_debit + total_credit, 0) > 100000 THEN 'MEDIUM VALUE'
        ELSE 'LOW VALUE'
    END as value_segment,
    CASE 
        WHEN transaction_count > 100 THEN 'VERY FREQUENT'
        WHEN transaction_count > 50 THEN 'FREQUENT'
        WHEN transaction_count > 10 THEN 'REGULAR'
        ELSE 'RARE'
    END as frequency_segment,
    CASE 
        WHEN suspicious_rate > 0.1 THEN 'HIGH RISK'
        WHEN suspicious_rate > 0.05 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END as risk_segment,
    CURRENT_TIMESTAMP as updated_at
FROM category_base
ORDER BY total_volume DESC;

-- Индексы
CREATE INDEX idx_mart_category ON mart_category_summary(category);
CREATE INDEX idx_mart_risk ON mart_category_summary(risk_segment);
CREATE INDEX idx_mart_volume ON mart_category_summary(total_volume DESC);

-- Проверка
SELECT COUNT(*) as categories FROM mart_category_summary;
SELECT * FROM mart_category_summary LIMIT 10;