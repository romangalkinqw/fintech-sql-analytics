-- =====================================================
-- АНАЛИЗ С ОКОННЫМИ ФУНКЦИЯМИ
-- =====================================================

-- 1. Скользящее среднее по дням
WITH daily_stats AS (
    SELECT 
        transaction_date,
        COUNT(*) as daily_transactions,
        SUM(debit) as daily_debit,
        SUM(credit) as daily_credit,
        AVG(is_suspicious) as daily_suspicious_rate
    FROM fact_transactions
    GROUP BY transaction_date
)
SELECT 
    transaction_date,
    daily_transactions,
    ROUND(AVG(daily_transactions) OVER (ORDER BY transaction_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 2) as moving_avg_7days,
    ROUND(AVG(daily_transactions) OVER (ORDER BY transaction_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)::numeric, 2) as moving_avg_30days,
    daily_debit,
    ROUND(AVG(daily_debit) OVER (ORDER BY transaction_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 2) as debit_moving_avg,
    daily_suspicious_rate,
    ROUND(AVG(daily_suspicious_rate) OVER (ORDER BY transaction_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 4) as suspicious_moving_avg
FROM daily_stats
ORDER BY transaction_date;

-- 2. Ранжирование категорий по объему транзакций
WITH category_stats AS (
    SELECT 
        description,
        COUNT(*) as txn_count,
        SUM(debit) as total_debit,
        SUM(credit) as total_credit,
        AVG(is_suspicious) as suspicious_rate,
        MAX(transaction_date) as last_txn
    FROM fact_transactions
    GROUP BY description
    HAVING COUNT(*) > 5
)
SELECT 
    description,
    txn_count,
    ROUND(total_debit::numeric, 2) as total_debit,
    ROUND(total_credit::numeric, 2) as total_credit,
    ROUND(suspicious_rate * 100, 2) as suspicious_pct,
    RANK() OVER (ORDER BY total_debit DESC) as debit_rank,
    RANK() OVER (ORDER BY txn_count DESC) as frequency_rank,
    RANK() OVER (ORDER BY suspicious_rate DESC) as risk_rank,
    ROUND(100.0 * txn_count / SUM(txn_count) OVER (), 2) as pct_of_total_txns
FROM category_stats
ORDER BY debit_rank
LIMIT 30;

-- 3. Нарастающий итог по месяцам
WITH monthly_totals AS (
    SELECT 
        DATE_TRUNC('month', transaction_date) as month,
        COUNT(*) as monthly_txns,
        SUM(debit) as monthly_debit,
        SUM(credit) as monthly_credit,
        SUM(is_suspicious) as monthly_suspicious
    FROM fact_transactions
    GROUP BY DATE_TRUNC('month', transaction_date)
)
SELECT 
        TO_CHAR(month, 'YYYY-MM') as month,
    monthly_txns,
    ROUND(monthly_debit::numeric, 2) as monthly_debit,
    ROUND(monthly_credit::numeric, 2) as monthly_credit,
    monthly_suspicious,
    ROUND(SUM(monthly_txns) OVER (ORDER BY month)::numeric, 0) as cumulative_txns,
    ROUND(SUM(monthly_debit) OVER (ORDER BY month)::numeric, 2) as cumulative_debit,
    ROUND(SUM(monthly_credit) OVER (ORDER BY month)::numeric, 2) as cumulative_credit,
    ROUND(AVG(monthly_txns) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)::numeric, 0) as avg_last_3_months
FROM monthly_totals
ORDER BY month;

-- 4. Сравнение с предыдущим периодом 
WITH monthly_stats AS (
    SELECT 
        DATE_TRUNC('month', transaction_date) as month,
        COUNT(*) as txns,
        SUM(debit) as total_debit
    FROM fact_transactions
    GROUP BY DATE_TRUNC('month', transaction_date)
)
SELECT 
    TO_CHAR(month, 'YYYY-MM') as month,
    txns,
    ROUND(total_debit::numeric, 2) as total_debit,
    LAG(txns) OVER (ORDER BY month) as prev_month_txns,
    LAG(ROUND(total_debit::numeric, 2)) OVER (ORDER BY month) as prev_month_debit,
    ROUND(100.0 * (txns - LAG(txns) OVER (ORDER BY month)) / LAG(txns) OVER (ORDER BY month), 2) as txn_growth_pct,
    ROUND(100.0 * (total_debit - LAG(total_debit) OVER (ORDER BY month)) / LAG(total_debit) OVER (ORDER BY month), 2) as debit_growth_pct
FROM monthly_stats
ORDER BY month;

-- 5. Первые и последние транзакции по категориям 
WITH category_dates AS (
    SELECT 
        description,
        transaction_date,
        debit,
        FIRST_VALUE(transaction_date) OVER (PARTITION BY description ORDER BY transaction_date) as first_txn_date,
        FIRST_VALUE(debit) OVER (PARTITION BY description ORDER BY transaction_date) as first_txn_amount,
        LAST_VALUE(transaction_date) OVER (PARTITION BY description ORDER BY transaction_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as last_txn_date,
        LAST_VALUE(debit) OVER (PARTITION BY description ORDER BY transaction_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as last_txn_amount
    FROM fact_transactions
)
SELECT DISTINCT
    description,
    first_txn_date,
    ROUND(first_txn_amount::numeric, 2) as first_amount,
    last_txn_date,
    ROUND(last_txn_amount::numeric, 2) as last_amount,
    -- Вычитаем даты без EXTRACT
    (last_txn_date - first_txn_date) as days_active,
    ROUND((last_txn_amount - first_txn_amount)::numeric, 2) as amount_change
FROM category_dates
WHERE description IS NOT NULL
ORDER BY days_active DESC NULLS LAST
LIMIT 30;