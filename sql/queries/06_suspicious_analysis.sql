-- =====================================================
-- АНАЛИЗ ПОДОЗРИТЕЛЬНЫХ ТРАНЗАКЦИЙ
-- =====================================================

-- 1. Общая статистика по подозрительным транзакциям
SELECT 
    is_suspicious,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage,
    ROUND(AVG(debit)::numeric, 2) as avg_debit,
    ROUND(AVG(credit)::numeric, 2) as avg_credit,
    ROUND(AVG(balance)::numeric, 2) as avg_balance,
    ROUND(MIN(balance)::numeric, 2) as min_balance,
    ROUND(MAX(balance)::numeric, 2) as max_balance
FROM fact_transactions
GROUP BY is_suspicious;

-- 2. Динамика подозрительных транзакций по месяцам
SELECT 
    TO_CHAR(transaction_date, 'YYYY-MM') as month,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN is_suspicious = 1 THEN 1 ELSE 0 END) as suspicious_count,
    ROUND(100.0 * SUM(is_suspicious) / COUNT(*), 2) as suspicious_rate,
    ROUND(AVG(CASE WHEN is_suspicious = 1 THEN debit END)::numeric, 2) as avg_suspicious_debit,
    ROUND(AVG(CASE WHEN is_suspicious = 0 THEN debit END)::numeric, 2) as avg_normal_debit
FROM fact_transactions
GROUP BY TO_CHAR(transaction_date, 'YYYY-MM')
ORDER BY month;

-- 3. Категории с наибольшей долей подозрительных транзакций
SELECT 
    description,
    COUNT(*) as total,
    SUM(is_suspicious) as suspicious,
    ROUND(100.0 * SUM(is_suspicious) / COUNT(*), 2) as suspicious_pct,
    ROUND(AVG(debit)::numeric, 2) as avg_debit,
    ROUND(AVG(credit)::numeric, 2) as avg_credit
FROM fact_transactions
GROUP BY description
HAVING COUNT(*) > 10 AND SUM(is_suspicious) > 0
ORDER BY suspicious_pct DESC
LIMIT 20;

-- 4. Подозрительные транзакции по дням недели
SELECT 
    TO_CHAR(transaction_date, 'Day') as day_of_week,
    EXTRACT(DOW FROM transaction_date) as dow,
    COUNT(*) as total,
    SUM(is_suspicious) as suspicious,
    ROUND(100.0 * SUM(is_suspicious) / COUNT(*), 2) as suspicious_pct
FROM fact_transactions
GROUP BY TO_CHAR(transaction_date, 'Day'), EXTRACT(DOW FROM transaction_date)
ORDER BY dow;

-- 5. Крупные подозрительные транзакции
SELECT 
    transaction_date,
    description,
    debit,
    credit,
    balance
FROM fact_transactions
WHERE is_suspicious = 1 AND debit > 100000
ORDER BY debit DESC
LIMIT 20;