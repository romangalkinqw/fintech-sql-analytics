-- =====================================================
-- ВИТРИНА 1: ЕЖЕДНЕВНЫЕ МЕТРИКИ
-- =====================================================

-- Создаем витрину 
DROP TABLE IF EXISTS mart_daily_metrics CASCADE;

CREATE TABLE mart_daily_metrics AS
WITH daily_base AS (
    SELECT 
        transaction_date,
        COUNT(*) as transactions,
        COUNT(DISTINCT description) as unique_categories,
        SUM(debit) as total_debit,
        SUM(credit) as total_credit,
        SUM(is_suspicious) as suspicious_count,
        AVG(debit) as avg_debit,
        AVG(credit) as avg_credit,
        AVG(balance) as avg_balance
    FROM fact_transactions
    GROUP BY transaction_date
)
SELECT 
    transaction_date,
    EXTRACT(YEAR FROM transaction_date) as year,
    EXTRACT(MONTH FROM transaction_date) as month,
    EXTRACT(DOW FROM transaction_date) as day_of_week,
    TO_CHAR(transaction_date, 'Day') as day_name,
    transactions,
    unique_categories,
    ROUND(COALESCE(total_debit, 0)::numeric, 2) as total_debit,
    ROUND(COALESCE(total_credit, 0)::numeric, 2) as total_credit,
    ROUND(COALESCE(total_debit - total_credit, 0)::numeric, 2) as net_flow,
    suspicious_count,
    ROUND(100.0 * suspicious_count / NULLIF(transactions, 0), 2) as suspicious_rate,
    ROUND(COALESCE(avg_debit, 0)::numeric, 2) as avg_debit,
    ROUND(COALESCE(avg_credit, 0)::numeric, 2) as avg_credit,
    ROUND(COALESCE(avg_balance, 0)::numeric, 2) as avg_balance,
    -- Добавляем скользящие средние прямо в витрину
    ROUND(AVG(transactions) OVER (ORDER BY transaction_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 2) as transactions_ma7,
    ROUND(AVG(suspicious_count) OVER (ORDER BY transaction_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 2) as suspicious_ma7,
    CURRENT_TIMESTAMP as updated_at
FROM daily_base
ORDER BY transaction_date;

-- Добавляем индексы для быстрых запросов
CREATE INDEX idx_mart_date ON mart_daily_metrics(transaction_date);
CREATE INDEX idx_mart_year ON mart_daily_metrics(year);
CREATE INDEX idx_mart_suspicious ON mart_daily_metrics(suspicious_rate);

-- Комментарии
COMMENT ON TABLE mart_daily_metrics IS 'Ежедневная витрина транзакций для дашбордов';
COMMENT ON COLUMN mart_daily_metrics.transactions_ma7 IS 'Скользящее среднее за 7 дней';
COMMENT ON COLUMN mart_daily_metrics.suspicious_rate IS 'Процент подозрительных транзакций';

-- Проверка
SELECT COUNT(*) as rows_in_mart FROM mart_daily_metrics;
SELECT * FROM mart_daily_metrics LIMIT 10;