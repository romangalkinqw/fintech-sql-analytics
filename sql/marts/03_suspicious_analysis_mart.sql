-- =====================================================
-- ВИТРИНА 3: ДЕТАЛЬНЫЙ АНАЛИЗ ПОДОЗРИТЕЛЬНЫХ ТРАНЗАКЦИЙ
-- =====================================================

DROP TABLE IF EXISTS mart_suspicious_analysis CASCADE;

CREATE TABLE mart_suspicious_analysis AS
WITH suspicious_base AS (
    SELECT 
        -- Группировка по дням
        DATE_TRUNC('day', transaction_date) as day,
        COUNT(*) as total_transactions,
        SUM(CASE WHEN is_suspicious = 1 THEN 1 ELSE 0 END) as suspicious_count,
        SUM(CASE WHEN is_suspicious = 0 THEN 1 ELSE 0 END) as normal_count,
        -- Суммы
        ROUND(SUM(CASE WHEN is_suspicious = 1 THEN debit ELSE 0 END)::numeric, 2) as suspicious_debit,
        ROUND(SUM(CASE WHEN is_suspicious = 0 THEN debit ELSE 0 END)::numeric, 2) as normal_debit,
        ROUND(SUM(CASE WHEN is_suspicious = 1 THEN credit ELSE 0 END)::numeric, 2) as suspicious_credit,
        ROUND(SUM(CASE WHEN is_suspicious = 0 THEN credit ELSE 0 END)::numeric, 2) as normal_credit,
        -- Средние
        ROUND(AVG(CASE WHEN is_suspicious = 1 THEN debit END)::numeric, 2) as avg_suspicious_debit,
        ROUND(AVG(CASE WHEN is_suspicious = 0 THEN debit END)::numeric, 2) as avg_normal_debit,
        -- Категории
        COUNT(DISTINCT CASE WHEN is_suspicious = 1 THEN description END) as suspicious_categories,
        COUNT(DISTINCT CASE WHEN is_suspicious = 0 THEN description END) as normal_categories
    FROM fact_transactions
    GROUP BY DATE_TRUNC('day', transaction_date)
),
suspicious_stats AS (
    SELECT 
        day,
        total_transactions,
        suspicious_count,
        normal_count,
        ROUND(100.0 * suspicious_count / NULLIF(total_transactions, 0), 2) as suspicious_rate,
        -- Отклонения от среднего (для выявления аномалий)
        ROUND(AVG(suspicious_count) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 2) as avg_suspicious_7d,
        ROUND((suspicious_count - AVG(suspicious_count) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))::numeric, 2) as deviation_from_avg,
        -- Денежные метрики
        suspicious_debit,
        normal_debit,
        suspicious_credit,
        normal_credit,
        ROUND(100.0 * suspicious_debit / NULLIF(suspicious_debit + normal_debit, 0), 2) as suspicious_debit_share,
        avg_suspicious_debit,
        avg_normal_debit,
        -- Во сколько раз подозрительные транзакции крупнее
        ROUND(COALESCE(avg_suspicious_debit / NULLIF(avg_normal_debit, 0), 0)::numeric, 2) as suspicious_debit_multiplier,
        suspicious_categories,
        normal_categories
    FROM suspicious_base
)
SELECT 
    day,
    -- Дата в разных форматах
    TO_CHAR(day, 'YYYY-MM-DD') as date_str,
    EXTRACT(YEAR FROM day) as year,
    EXTRACT(MONTH FROM day) as month,
    EXTRACT(DOW FROM day) as day_of_week,
    TO_CHAR(day, 'Day') as day_name,
    -- Основные метрики
    total_transactions,
    suspicious_count,
    normal_count,
    suspicious_rate,
    -- Метрики аномалий
    avg_suspicious_7d,
    deviation_from_avg,
    CASE 
        WHEN suspicious_count > avg_suspicious_7d * 2 THEN 'КРИТИЧЕСКАЯ АНОМАЛИЯ'
        WHEN suspicious_count > avg_suspicious_7d * 1.5 THEN 'АНОМАЛИЯ'
        WHEN suspicious_count < avg_suspicious_7d * 0.5 THEN 'НИЗКАЯ АКТИВНОСТЬ'
        ELSE 'НОРМА'
    END as anomaly_flag,
    -- Денежные показатели
    suspicious_debit,
    normal_debit,
    suspicious_credit,
    normal_credit,
    suspicious_debit_share,
    avg_suspicious_debit,
    avg_normal_debit,
    suspicious_debit_multiplier,
    -- Категории
    suspicious_categories,
    normal_categories,
    ROUND(100.0 * suspicious_categories / NULLIF(suspicious_categories + normal_categories, 0), 2) as suspicious_categories_share,
    -- Флаги для быстрого анализа
    CASE WHEN suspicious_rate > 10 THEN 1 ELSE 0 END as high_risk_day_flag,
    CASE WHEN suspicious_debit_multiplier > 2 THEN 1 ELSE 0 END as large_suspicious_flag,
    -- Временная метка
    CURRENT_TIMESTAMP as updated_at
FROM suspicious_stats
ORDER BY day DESC;

-- Индексы для быстрого доступа
CREATE INDEX idx_mart_suspicious_day ON mart_suspicious_analysis(day DESC);
CREATE INDEX idx_mart_suspicious_rate ON mart_suspicious_analysis(suspicious_rate DESC);
CREATE INDEX idx_mart_anomaly ON mart_suspicious_analysis(anomaly_flag);
CREATE INDEX idx_mart_high_risk ON mart_suspicious_analysis(high_risk_day_flag);

-- Комментарии
COMMENT ON TABLE mart_suspicious_analysis IS 'Витрина для анализа подозрительных транзакций и аномалий';
COMMENT ON COLUMN mart_suspicious_analysis.anomaly_flag IS 'Флаг аномалии на основе отклонения от скользящего среднего';
COMMENT ON COLUMN mart_suspicious_analysis.suspicious_debit_multiplier IS 'Во сколько раз подозрительные транзакции крупнее нормальных';

-- =====================================================
-- ДОПОЛНИТЕЛЬНЫЕ ЗАПРОСЫ К ВИТРИНЕ
-- =====================================================

-- 1. Дни с максимальной долей подозрительных транзакций
SELECT 
    date_str,
    day_name,
    total_transactions,
    suspicious_count,
    suspicious_rate,
    anomaly_flag,
    suspicious_debit,
    avg_suspicious_debit
FROM mart_suspicious_analysis
WHERE suspicious_rate > 0
ORDER BY suspicious_rate DESC
LIMIT 20;

-- 2. Аномальные дни (для расследования)
SELECT 
    date_str,
    day_name,
    total_transactions,
    suspicious_count,
    avg_suspicious_7d,
    deviation_from_avg,
    anomaly_flag,
    suspicious_debit,
    suspicious_categories
FROM mart_suspicious_analysis
WHERE anomaly_flag IN ('КРИТИЧЕСКАЯ АНОМАЛИЯ', 'АНОМАЛИЯ')
ORDER BY deviation_from_avg DESC;

-- 3. Сводка по дням недели
SELECT 
    day_name,
    AVG(suspicious_rate) as avg_suspicious_rate,
    MAX(suspicious_rate) as max_suspicious_rate,
    SUM(suspicious_count) as total_suspicious,
    AVG(suspicious_debit_multiplier) as avg_amount_multiplier,
    COUNT(CASE WHEN anomaly_flag = 'КРИТИЧЕСКАЯ АНОМАЛИЯ' THEN 1 END) as critical_anomaly_days
FROM mart_suspicious_analysis
GROUP BY day_name, EXTRACT(DOW FROM day)
ORDER BY EXTRACT(DOW FROM day);

-- 4. Тренды по месяцам
SELECT 
    year,
    month,
    AVG(suspicious_rate) as avg_monthly_rate,
    SUM(suspicious_count) as total_suspicious,
    SUM(total_transactions) as total_txns,
    ROUND(100.0 * SUM(suspicious_count) / SUM(total_transactions), 2) as actual_rate,
    SUM(suspicious_debit) as total_suspicious_debit,
    COUNT(CASE WHEN anomaly_flag LIKE '%АНОМАЛИЯ%' THEN 1 END) as anomaly_days
FROM mart_suspicious_analysis
GROUP BY year, month
ORDER BY year, month;