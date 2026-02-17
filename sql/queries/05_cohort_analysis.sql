-- =====================================================
-- КОГОРТНЫЙ АНАЛИЗ ПО НЕДЕЛЯМ (на основе дат)
-- =====================================================

-- 1. Определяем когорты по неделе первой транзакции для каждой категории
WITH first_activity AS (
    SELECT 
        description,
        MIN(transaction_date) as first_seen_date
    FROM fact_transactions
    GROUP BY description
),
-- 2. Создаём недельные когорты
cohorts AS (
    SELECT 
        description,
        DATE_TRUNC('week', first_seen_date) as cohort_week
    FROM first_activity
    WHERE first_seen_date IS NOT NULL
),
-- 3. Активность по неделям
weekly_activity AS (
    SELECT 
        c.description,
        c.cohort_week,
        DATE_TRUNC('week', t.transaction_date) as activity_week,
        COUNT(*) as transactions,
        SUM(t.debit) as total_debit,
        SUM(t.credit) as total_credit
    FROM cohorts c
    JOIN fact_transactions t ON c.description = t.description
    GROUP BY c.description, c.cohort_week, DATE_TRUNC('week', t.transaction_date)
),
-- 4. Размер когорт (сколько категорий в каждой неделе)
cohort_size AS (
    SELECT 
        cohort_week,
        COUNT(DISTINCT description) as size
    FROM cohorts
    GROUP BY cohort_week
),
-- 5. Когортная таблица удержания
cohort_retention AS (
    SELECT 
        wa.cohort_week,
        cs.size as cohort_size,
        EXTRACT(WEEK FROM wa.activity_week) - EXTRACT(WEEK FROM wa.cohort_week) as week_number,
        COUNT(DISTINCT wa.description) as active_categories,
        SUM(wa.transactions) as total_transactions,
        SUM(wa.total_debit) as week_debit,
        SUM(wa.total_credit) as week_credit
    FROM weekly_activity wa
    JOIN cohort_size cs ON wa.cohort_week = cs.cohort_week
    GROUP BY wa.cohort_week, cs.size, EXTRACT(WEEK FROM wa.activity_week) - EXTRACT(WEEK FROM wa.cohort_week)
)
-- 6. Итоговая таблица
SELECT 
    TO_CHAR(cohort_week, 'YYYY-MM-DD') as cohort_week,
    cohort_size,
    ROUND(100.0 * MAX(CASE WHEN week_number = 0 THEN active_categories END) / cohort_size, 2) as week_0_pct,
    ROUND(100.0 * MAX(CASE WHEN week_number = 1 THEN active_categories END) / cohort_size, 2) as week_1_pct,
    ROUND(100.0 * MAX(CASE WHEN week_number = 2 THEN active_categories END) / cohort_size, 2) as week_2_pct,
    ROUND(100.0 * MAX(CASE WHEN week_number = 3 THEN active_categories END) / cohort_size, 2) as week_3_pct,
    ROUND(100.0 * MAX(CASE WHEN week_number = 4 THEN active_categories END) / cohort_size, 2) as week_4_pct,
    -- Дополнительно: объём транзакций по неделям
    ROUND(MAX(CASE WHEN week_number = 0 THEN total_transactions END)::numeric, 0) as week_0_txns,
    ROUND(MAX(CASE WHEN week_number = 1 THEN total_transactions END)::numeric, 0) as week_1_txns,
    ROUND(MAX(CASE WHEN week_number = 2 THEN total_transactions END)::numeric, 0) as week_2_txns,
    ROUND(MAX(CASE WHEN week_number = 3 THEN total_transactions END)::numeric, 0) as week_3_txns,
    ROUND(MAX(CASE WHEN week_number = 4 THEN total_transactions END)::numeric, 0) as week_4_txns
FROM cohort_retention
GROUP BY cohort_week, cohort_size
ORDER BY cohort_week;