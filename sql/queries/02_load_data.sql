-- =====================================================
-- ЗАГРУЗКА ДАННЫХ ИЗ CSV В ТАБЛИЦУ
-- =====================================================

-- Очистка таблицы перед загрузкой файлов
TRUNCATE fact_transactions RESTART IDENTITY;

-- Загружаем данные из CSV-файла
-- В терминале
\copy fact_transactions(transaction_date, description, debit, credit, balance, is_suspicious) 
FROM 'C:/Users/romop/fintech-sql-analytics/data/transactions_Dataset.csv' 
DELIMITER ',' 
CSV HEADER;

-- Проверка загрузки
SELECT COUNT(*) as loaded_rows FROM fact_transactions;
