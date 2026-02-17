-- =====================================================
-- СХЕМА БАЗЫ ДАННЫХ ДЛЯ ФИНТЕХ-АНАЛИТИКИ
-- =====================================================

-- Таблица транзакций из Kaggle датасета - Bank Transaction Records along Suspicious Flags
CREATE TABLE IF NOT EXISTS fact_transactions (
    transaction_id SERIAL PRIMARY KEY,
    transaction_date DATE,
    description VARCHAR(255),
    debit DECIMAL(15,2),
    credit DECIMAL(15,2),
    balance DECIMAL(15,2),
    is_suspicious INTEGER CHECK (is_suspicious IN (0,1))
);

-- Индексы для ускорения запросов
CREATE INDEX IF NOT EXISTS idx_transactions_date ON fact_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_transactions_suspicious ON fact_transactions(is_suspicious);

-- Комментарии к таблице и колонкам
COMMENT ON TABLE fact_transactions IS 'Факты транзакций из Kaggle датасета';
COMMENT ON COLUMN fact_transactions.is_suspicious IS 'Флаг подозрительности: 0 - норма, 1 - подозрительно';

-- Проверка структуры 
SELECT 'Таблица fact_transactions создана успешно' as message;