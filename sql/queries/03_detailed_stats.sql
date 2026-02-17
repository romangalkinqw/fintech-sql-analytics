-- =====================================================
-- ДЕТАЛЬНАЯ СТАТИСТИКА И АНАЛИЗ ТРАНЗАКЦИЙ
-- =====================================================

-- 1. Распределение транзакций по суммам

SELECT 
    CASE 
        WHEN debit < 100 THEN '0-100'
        WHEN debit BETWEEN 100 AND 500 THEN '100-500'
        WHEN debit BETWEEN 500 AND 1000 THEN '500-1000'
        WHEN debit BETWEEN 1000 AND 5000 THEN '1000-5000'
        WHEN debit > 5000 THEN '5000+'
        ELSE 'No debit'
    END as debit_range,
    COUNT(*) as transactions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage,
    ROUND(AVG(is_suspicious)::numeric, 4) as suspicious_rate
FROM fact_transactions
GROUP BY 
    CASE 
        WHEN debit < 100 THEN '0-100'
        WHEN debit BETWEEN 100 AND 500 THEN '100-500'
        WHEN debit BETWEEN 500 AND 1000 THEN '500-1000'
        WHEN debit BETWEEN 1000 AND 5000 THEN '1000-5000'
        WHEN debit > 5000 THEN '5000+'
        ELSE 'No debit'
    END
ORDER BY 
    MIN(debit) NULLS LAST;  

-- 2. Анализ подозрительных транзакций по дням недели

SELECT 
    TO_CHAR(transaction_date, 'Day') as day_of_week,
    EXTRACT(DOW FROM transaction_date) as dow_number,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN is_suspicious = 1 THEN 1 ELSE 0 END) as suspicious_count,
    ROUND(100.0 * SUM(CASE WHEN is_suspicious = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) as suspicious_percentage
FROM fact_transactions
GROUP BY day_of_week, EXTRACT(DOW FROM transaction_date)
ORDER BY dow_number;

-- 3. Скользящее среднее

SELECT 
    transaction_date,
    COUNT(*) as daily_transactions,
    ROUND(AVG(COUNT(*)) OVER (ORDER BY transaction_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 2) as moving_avg_7days,
    ROUND(AVG(COUNT(*)) OVER (ORDER BY transaction_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)::numeric, 2) as moving_avg_30days
FROM fact_transactions
GROUP BY transaction_date
ORDER BY transaction_date;

-- 4. Топ-10 подозрительных описаний транзакций
SELECT 
    description,
    COUNT(*) as total_count,
    SUM(CASE WHEN is_suspicious = 1 THEN 1 ELSE 0 END) as suspicious_count,
    ROUND(100.0 * SUM(CASE WHEN is_suspicious = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) as suspicious_percentage
FROM fact_transactions
GROUP BY description
HAVING COUNT(*) > 10  -- только популярные категории
ORDER BY suspicious_percentage DESC
LIMIT 10;

-- 5. Кумулятивные суммы (нарастающий итог)
WITH daily_stats AS (
    SELECT 
        transaction_date,
        COUNT(*) as trans_count,
        SUM(debit) as total_debit,
        SUM(credit) as total_credit
    FROM fact_transactions
    GROUP BY transaction_date
)
SELECT 
    transaction_date,
    trans_count,
    total_debit,
    total_credit,
    SUM(trans_count) OVER (ORDER BY transaction_date) as cumulative_transactions,
    SUM(total_debit) OVER (ORDER BY transaction_date) as cumulative_debits,
    SUM(total_credit) OVER (ORDER BY transaction_date) as cumulative_credits
FROM daily_stats
ORDER BY transaction_date;