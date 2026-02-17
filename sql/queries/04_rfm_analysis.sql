-- =====================================================
-- RFM-АНАЛИЗ ПО КАТЕГОРИЯМ ТРАНЗАКЦИЙ
-- =====================================================

-- Создаем представление с RFM-метриками для категорий
WITH category_rfm AS (
    SELECT 
        description as category,
        -- Recency - дней с последней транзакции данной категории
        (CURRENT_DATE - MAX(transaction_date)) as recency,
        -- Frequency - количество транзакций в категории
        COUNT(*) as frequency,
        -- Monetary - общая сумма по категории
        ROUND(SUM(COALESCE(debit, 0) + COALESCE(credit, 0))::numeric, 2) as monetary,
        -- Дополнительно - доля подозрительных
        ROUND(100.0 * AVG(is_suspicious), 2) as suspicious_percentage
    FROM fact_transactions
    GROUP BY description
    HAVING COUNT(*) > 5  -- Достаточное количество
),
-- Разбиваем на 5 равных групп по перцентилям
rfm_scores AS (
    SELECT 
        category,
        recency,
        frequency,
        monetary,
        suspicious_percentage,
        NTILE(5) OVER (ORDER BY recency) as r_score,  -- чем меньше дней, тем лучше
        NTILE(5) OVER (ORDER BY frequency DESC) as f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) as m_score
    FROM category_rfm
    WHERE recency IS NOT NULL
),
-- Комбинируем scores
rfm_combined AS (
    SELECT 
        category,
        recency,
        frequency,
        monetary,
        suspicious_percentage,
        r_score,
        f_score,
        m_score,
        CONCAT(r_score, f_score, m_score) as rfm_cell,
        (r_score + f_score + m_score) as rfm_total
    FROM rfm_scores
)
-- Финальная сегментация категорий
SELECT 
    category,
    recency as days_since_last,
    frequency as transaction_count,
    monetary as total_amount,
    suspicious_percentage,
    r_score,
    f_score,
    m_score,
    rfm_cell,
    CASE 
        WHEN rfm_total >= 13 THEN 'VIP категории'
        WHEN rfm_total BETWEEN 10 AND 12 THEN 'Популярные'
        WHEN rfm_total BETWEEN 7 AND 9 THEN 'Обычные'
        WHEN rfm_total BETWEEN 4 AND 6 THEN 'Редкие'
        ELSE 'Неактивные'
    END as category_segment,
    CASE 
        WHEN suspicious_percentage > 10 THEN 'Высокорисковые'
        WHEN suspicious_percentage > 5 THEN 'Среднерисковые'
        ELSE 'Низкорисковые'
    END as risk_segment
FROM rfm_combined
ORDER BY rfm_total DESC, monetary DESC
LIMIT 50;

-- Детальный анализ VIP категорий
SELECT 
    description as category,
    COUNT(*) as transaction_count,
    MIN(transaction_date) as first_seen,
    MAX(transaction_date) as last_seen,
    (CURRENT_DATE - MAX(transaction_date)) as days_since_last,
    ROUND(AVG(debit)::numeric, 2) as avg_debit,
    ROUND(AVG(credit)::numeric, 2) as avg_credit,
    ROUND(SUM(debit)::numeric, 2) as total_debit,
    ROUND(SUM(credit)::numeric, 2) as total_credit,
    -- Соотношение дебета и кредита
    CASE 
        WHEN SUM(credit) > 0 THEN ROUND(SUM(debit) / SUM(credit)::numeric, 2)
        ELSE NULL
    END as debit_credit_ratio
FROM fact_transactions
WHERE description IN (
    SELECT description
    FROM fact_transactions
    GROUP BY description
    HAVING SUM(COALESCE(debit, 0) + COALESCE(credit, 0)) > 100000000  -- больше 100 млн
)
GROUP BY description
ORDER BY (SUM(debit) + SUM(credit)) DESC; 