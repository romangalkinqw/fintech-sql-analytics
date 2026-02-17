-- =====================================================
-- БАЗОВАЯ СТАТИСТИКА ПО ТРАНЗАКЦИЯМ
-- =====================================================

-- 1. Общая статистика по всем транзакциям, состоящая из аггрегирующих функций
SELECT 
    COUNT(*) as total_transactions,
    MIN(transaction_date) as first_date,
    MAX(transaction_date) as last_date,
    COUNT(DISTINCT description) as unique_categories,
    ROUND(SUM(debit)::numeric, 2) as total_debits,
    ROUND(SUM(credit)::numeric, 2) as total_credits,
    ROUND(AVG(balance)::numeric, 2) as avg_balance
FROM fact_transactions;

-- 2. Сравнение подозрительных и нормальных транзакций
SELECT 
    is_suspicious,
    COUNT(*) as transaction_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage,
    ROUND(AVG(debit)::numeric, 2) as avg_debit,
    ROUND(AVG(credit)::numeric, 2) as avg_credit,
    ROUND(AVG(balance)::numeric, 2) as avg_balance,
    ROUND(MIN(balance)::numeric, 2) as min_balance,
    ROUND(MAX(balance)::numeric, 2) as max_balance
FROM fact_transactions
GROUP BY is_suspicious
ORDER BY is_suspicious;

-- 3. Топ-10 дней с наибольшим объёмом списаний
SELECT 
    transaction_date,
    COUNT(*) as transactions_count,
    ROUND(SUM(debit)::numeric, 2) as total_debit,
    ROUND(SUM(credit)::numeric, 2) as total_credit
FROM fact_transactions
GROUP BY transaction_date
ORDER BY total_debit DESC NULLS LAST
LIMIT 10;
