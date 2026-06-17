-- Create and populate once per session
CREATE TABLE #recalled_lots (
    lot_number VARCHAR(50)
);

-- Bulk insert from a flat file (one lot number per line)
BULK INSERT #recalled_lots
FROM 'C:\path\to\lot_numbers.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 1
);

-- Add an index for join performance
CREATE INDEX idx_lot ON #recalled_lots(lot_number);

-- Then use #recalled_lots anywhere recalled_lots appeared before
SELECT c.person_id
FROM your_cohort_table c
WHERE NOT EXISTS (
    SELECT 1
    FROM drug_exposure de
    INNER JOIN #recalled_lots rl ON de.lot_number = rl.lot_number
    WHERE de.person_id = c.person_id
);