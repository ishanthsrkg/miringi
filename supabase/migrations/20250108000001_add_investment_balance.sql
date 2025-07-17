ALTER TABLE balances ADD COLUMN IF NOT EXISTS investment_balance DECIMAL(15,2) DEFAULT 0;

UPDATE balances SET investment_balance = 0 WHERE investment_balance IS NULL;
