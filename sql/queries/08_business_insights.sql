-- =====================================================
-- БИЗНЕС-МЕТРИКИ И КЛЮЧЕВЫЕ ПОКАЗАТЕЛИ (KPI)
-- =====================================================

-- 1. ОБЩИЕ ПОКАЗАТЕЛИ
WITH totals AS (
    SELECT 
        COUNT(*) as total_txns,
        COUNT(DISTINCT description) as total_categories,
        COUNT(DISTINCT DATE_TRUNC('day', transaction_date)) as active_days,
        MIN(transaction_date) as first_date,
        MAX(transaction_date) as last_date,
        SUM(debit) as total_debit,
        SUM(credit) as total_credit,
        SUM(is_suspicious) as total_suspicious,
        AVG(debit) as avg_debit,
        AVG(credit) as avg_credit
    FROM fact_transactions
)
SELECT 
    'ОБЩИЕ ПОКАЗАТЕЛИ' as metric_group,
    'Всего транзакций' as metric_name,
    total_txns::text as value,
    '' as unit
FROM totals
UNION ALL
SELECT 'ОБЩИЕ ПОКАЗАТЕЛИ', 'Уникальных категорий', total_categories::text, '' FROM totals
UNION ALL
SELECT 'ОБЩИЕ ПОКАЗАТЕЛИ', 'Активных дней', active_days::text, '' FROM totals
UNION ALL
SELECT 'ОБЩИЕ ПОКАЗАТЕЛИ', 'Период', first_date::text || ' - ' || last_date::text, '' FROM totals
UNION ALL
SELECT 'ОБЩИЕ ПОКАЗАТЕЛИ', 'Общий дебет', ROUND(total_debit::numeric, 2)::text, 'руб' FROM totals
UNION ALL
SELECT 'ОБЩИЕ ПОКАЗАТЕЛИ', 'Общий кредит', ROUND(total_credit::numeric, 2)::text, 'руб' FROM totals
UNION ALL
SELECT 'ОБЩИЕ ПОКАЗАТЕЛИ', 'Средний дебет', ROUND(avg_debit::numeric, 2)::text, 'руб' FROM totals
UNION ALL
SELECT 'ОБЩИЕ ПОКАЗАТЕЛИ', 'Средний кредит', ROUND(avg_credit::numeric, 2)::text, 'руб' FROM totals
UNION ALL
SELECT 'ОБЩИЕ ПОКАЗАТЕЛИ', 'Подозрительных транзакций', total_suspicious::text, '' FROM totals
UNION ALL
SELECT 'ОБЩИЕ ПОКАЗАТЕЛИ', 'Доля подозрительных', 
    ROUND(100.0 * total_suspicious / total_txns, 2)::text, '%' FROM totals;

-- 2. ДИНАМИКА ПО МЕСЯЦАМ
SELECT 
    TO_CHAR(DATE_TRUNC('month', transaction_date), 'YYYY-MM') as month,
    COUNT(*) as transactions,
    COUNT(DISTINCT description) as categories,
    ROUND(SUM(debit)::numeric, 2) as total_debit,
    ROUND(SUM(credit)::numeric, 2) as total_credit,
    ROUND(AVG(debit)::numeric, 2) as avg_debit,
    SUM(is_suspicious) as suspicious_count,
    ROUND(100.0 * SUM(is_suspicious) / COUNT(*), 2) as suspicious_pct,
    ROUND(100.0 * (SUM(debit) - LAG(SUM(debit)) OVER (ORDER BY DATE_TRUNC('month', transaction_date))) / 
        NULLIF(LAG(SUM(debit)) OVER (ORDER BY DATE_TRUNC('month', transaction_date)), 0), 2) as growth_pct
FROM fact_transactions
GROUP BY DATE_TRUNC('month', transaction_date)
ORDER BY month;

-- 3. ТОП-10 КАТЕГОРИЙ ПО ОБЪЕМУ
SELECT 
    description as category,
    COUNT(*) as txn_count,
    ROUND(SUM(debit)::numeric, 2) as total_debit,
    ROUND(SUM(credit)::numeric, 2) as total_credit,
    ROUND(AVG(debit)::numeric, 2) as avg_debit,
    SUM(is_suspicious) as suspicious_count,
    ROUND(100.0 * SUM(is_suspicious) / COUNT(*), 2) as suspicious_pct
FROM fact_transactions
GROUP BY description
HAVING COUNT(*) > 10
ORDER BY SUM(debit) DESC NULLS LAST
LIMIT 10;

-- 4. РАСПРЕДЕЛЕНИЕ ПОДОЗРИТЕЛЬНЫХ ТРАНЗАКЦИЙ ПО ДНЯМ НЕДЕЛИ
SELECT 
    TO_CHAR(transaction_date, 'Day') as day_of_week,
    EXTRACT(DOW FROM transaction_date) as dow,
    COUNT(*) as total_txns,
    SUM(is_suspicious) as suspicious_txns,
    ROUND(100.0 * SUM(is_suspicious) / COUNT(*), 2) as suspicious_pct,
    ROUND(AVG(debit)::numeric, 2) as avg_debit,
    ROUND(AVG(credit)::numeric, 2) as avg_credit
FROM fact_transactions
GROUP BY TO_CHAR(transaction_date, 'Day'), EXTRACT(DOW FROM transaction_date)
ORDER BY dow;

-- 5. СЕЗОННОСТЬ
SELECT 
    EXTRACT(DAY FROM transaction_date) as day_of_month,
    COUNT(*) as avg_transactions,
    ROUND(AVG(debit)::numeric, 2) as avg_debit,
    ROUND(AVG(credit)::numeric, 2) as avg_credit,
    ROUND(100.0 * AVG(is_suspicious), 2) as avg_suspicious_pct
FROM fact_transactions
GROUP BY EXTRACT(DAY FROM transaction_date)
ORDER BY day_of_month;

-- 6. АНАЛИЗ РИСКОВ
WITH risk_stats AS (
    SELECT 
        CASE 
            WHEN debit > 100000 THEN 'Крупные (>100k)'
            WHEN debit > 50000 THEN 'Средние (50k-100k)'
            WHEN debit > 10000 THEN 'Малые (10k-50k)'
            ELSE 'Микро (<10k)'
        END as amount_category,
        COUNT(*) as total,
        SUM(is_suspicious) as suspicious,
        ROUND(100.0 * SUM(is_suspicious) / COUNT(*), 2) as risk_rate
    FROM fact_transactions
    GROUP BY 
        CASE 
            WHEN debit > 100000 THEN 'Крупные (>100k)'
            WHEN debit > 50000 THEN 'Средние (50k-100k)'
            WHEN debit > 10000 THEN 'Малые (10k-50k)'
            ELSE 'Микро (<10k)'
        END
)
SELECT 
    amount_category,
    total,
    suspicious,
    risk_rate as risk_percentage,
    CASE 
        WHEN risk_rate > 10 THEN 'КРИТИЧЕСКИЙ РИСК'
        WHEN risk_rate > 5 THEN 'ВЫСОКИЙ РИСК'
        WHEN risk_rate > 2 THEN 'СРЕДНИЙ РИСК'
        ELSE 'НИЗКИЙ РИСК'
    END as risk_level
FROM risk_stats
ORDER BY risk_rate DESC;

-- 7. ИТОГОВЫЙ ДАШБОРД
WITH daily_avg AS (
    SELECT 
        AVG(COUNT(*)) OVER () as avg_daily_txns,
        AVG(SUM(debit)) OVER () as avg_daily_debit
    FROM fact_transactions
    GROUP BY transaction_date
    LIMIT 1
)
SELECT 
    (SELECT COUNT(*) FROM fact_transactions) as total_transactions,
    (SELECT COUNT(DISTINCT description) FROM fact_transactions) as unique_categories,
    (SELECT ROUND(AVG(debit)::numeric, 2) FROM fact_transactions) as overall_avg_debit,
    (SELECT ROUND(100.0 * SUM(is_suspicious) / COUNT(*), 2) FROM fact_transactions) as overall_risk_pct,
    (SELECT COUNT(*) FROM fact_transactions WHERE is_suspicious = 1) as total_suspicious,
    (SELECT ROUND(SUM(debit)::numeric, 2) FROM fact_transactions) as total_volume,
    (SELECT ROUND(AVG(daily_txns)::numeric, 2) 
     FROM (SELECT COUNT(*) as daily_txns FROM fact_transactions GROUP BY transaction_date) as d) as avg_daily_txns;