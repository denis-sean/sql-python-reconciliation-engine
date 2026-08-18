-- ============================================================================
-- SQL FROM ZERO TO RECONCILIATION-READY
-- A self-paced course, built entirely on your own real data
-- (bank_reconciliation.db — bank_statement + ledger tables)
--
-- HOW TO USE THIS FILE:
-- 1. Open bank_reconciliation.db in DB Browser for SQLite
-- 2. Go to "Execute SQL" tab
-- 3. Work through ONE lesson block at a time — copy just that block,
--    paste it into the query box, run it (Ctrl+Enter), read the comments,
--    look at the result, THEN move to the next block.
-- 4. Don't paste the whole file at once — go slow, one block at a time.
-- ============================================================================


-- ============================================================================
-- LESSON 1: SELECT — look at raw data
-- ============================================================================
-- SELECT columns FROM table  — the most basic query. "Show me this data."

SELECT * FROM bank_statement LIMIT 5;
-- * means "all columns". LIMIT 5 means "only show 5 rows" so you don't
-- flood the screen. Always LIMIT when you're just exploring.

SELECT date, description, amount FROM ledger LIMIT 5;
-- Naming specific columns instead of * is better practice once you know
-- what you actually need — faster, and clearer to read.


-- ============================================================================
-- LESSON 2: WHERE — filter rows
-- ============================================================================
-- WHERE narrows down which rows come back, based on a condition.

SELECT date, description, amount
FROM bank_statement
WHERE amount < 0;
-- Only outgoing payments (negative amounts)

SELECT date, description, amount
FROM bank_statement
WHERE amount > 100000;
-- Only large inflows

SELECT date, description, amount
FROM bank_statement
WHERE date BETWEEN '2025-06-01' AND '2025-06-30';
-- Only June transactions — BETWEEN is inclusive on both ends

SELECT date, description, amount
FROM bank_statement
WHERE description LIKE '%Surgik%';
-- LIKE searches text. % means "anything can go here" (a wildcard).
-- '%Surgik%' means "contains the word Surgik anywhere in the text"


-- ============================================================================
-- LESSON 3: ORDER BY and LIMIT — sort and cap results
-- ============================================================================

SELECT date, description, amount
FROM bank_statement
ORDER BY amount ASC     -- ASC = smallest first (most negative first)
LIMIT 10;
-- Your 10 biggest outgoing payments

SELECT date, description, amount
FROM bank_statement
ORDER BY amount DESC    -- DESC = largest first
LIMIT 10;
-- Your 10 biggest incoming payments


-- ============================================================================
-- LESSON 4: Aggregate functions — COUNT, SUM, AVG, MIN, MAX
-- ============================================================================
-- These collapse many rows into a single summary number.

SELECT COUNT(*) AS total_transactions FROM bank_statement;
-- How many rows are in the table

SELECT SUM(amount) AS net_total FROM bank_statement
WHERE date BETWEEN '2025-06-01' AND '2025-06-30';
-- Total net cash movement in June (positive = net inflow)

SELECT AVG(amount) AS average_transaction FROM bank_statement;
-- Average transaction size

SELECT MIN(amount) AS biggest_outflow, MAX(amount) AS biggest_inflow
FROM bank_statement;
-- Smallest and largest single transactions in the whole table


-- ============================================================================
-- LESSON 5: GROUP BY — summarize by category
-- ============================================================================
-- GROUP BY is "give me one summary row per unique value in this column"
-- Extremely useful for things like "spending by month" or "count by risk tier"

SELECT
    SUBSTR(date, 1, 7) AS month,     -- SUBSTR(date,1,7) grabs "2025-06" from "2025-06-15"
    COUNT(*) AS num_transactions,
    SUM(amount) AS net_amount
FROM bank_statement
GROUP BY month
ORDER BY month;
-- One row per month, showing transaction count and net amount for each


-- ============================================================================
-- LESSON 6: DISTINCT — unique values only
-- ============================================================================

SELECT DISTINCT SUBSTR(date, 1, 7) AS month FROM bank_statement;
-- List every distinct month present in the data, no duplicates

SELECT COUNT(DISTINCT SUBSTR(date,1,7)) AS num_months FROM bank_statement;
-- Count how many distinct months are covered


-- ============================================================================
-- LESSON 7: JOIN — combine two tables based on a matching condition
-- ============================================================================
-- This is the big one. A JOIN connects rows from two tables where some
-- condition is true. Today's task: connect bank rows to ledger rows
-- where the amount matches AND the dates are close together.

SELECT
    b.date AS bank_date,
    l.date AS ledger_date,
    b.amount AS bank_amount,
    l.amount AS ledger_amount,
    b.description AS bank_description,
    l.description AS ledger_description
FROM bank_statement b
JOIN ledger l
    ON b.amount = l.amount
    AND ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) <= 7
WHERE b.date BETWEEN '2025-06-01' AND '2025-06-30'
ORDER BY b.date;
-- b and l are "aliases" — short nicknames for the table names, so you
-- don't have to type "bank_statement" and "ledger" every single time.
-- JULIANDAY() turns a date into a number so you can subtract dates and
-- measure the gap in days between them.


-- ============================================================================
-- LESSON 8: THE JOIN "FAN-OUT" TRAP — always verify with DISTINCT
-- ============================================================================
-- A JOIN can match ONE row on one side to MULTIPLE rows on the other side.
-- This inflates your row count and can silently mislead you. ALWAYS check.

-- Count of match-PAIRS (can be inflated by fan-out):
SELECT COUNT(*) AS match_pairs
FROM bank_statement b
JOIN ledger l
    ON b.amount = l.amount
    AND ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) <= 7
WHERE b.date BETWEEN '2025-06-01' AND '2025-06-30';

-- Count of UNIQUE bank transactions that found at least one match:
SELECT COUNT(DISTINCT b.txn_id) AS unique_bank_matched
FROM bank_statement b
JOIN ledger l
    ON b.amount = l.amount
    AND ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) <= 7
WHERE b.date BETWEEN '2025-06-01' AND '2025-06-30';

-- If these two numbers are different, you have fan-out — some bank
-- transactions matched more than one ledger row. That's not automatically
-- wrong, but you must know it's happening, not just trust the row count.


-- ============================================================================
-- LESSON 9: LEFT JOIN — find what did NOT match
-- ============================================================================
-- Regular JOIN only keeps rows that found a match on both sides.
-- LEFT JOIN keeps EVERY row from the left (first) table, even with no match
-- — the unmatched columns just come back empty (NULL).

SELECT
    b.date,
    b.description,
    b.amount
FROM bank_statement b
LEFT JOIN ledger l
    ON b.amount = l.amount
    AND ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) <= 7
WHERE b.date BETWEEN '2025-06-01' AND '2025-06-30'
    AND l.txn_id IS NULL          -- "only keep rows where NOTHING matched"
ORDER BY b.date;
-- This is your "unmatched bank items" list — the same thing you built
-- manually in pandas, in one query.

-- Same idea, flipped: unmatched LEDGER items (things booked but not seen in bank)
SELECT
    l.date,
    l.description,
    l.amount
FROM ledger l
LEFT JOIN bank_statement b
    ON l.amount = b.amount
    AND ABS(JULIANDAY(l.date) - JULIANDAY(b.date)) <= 7
WHERE l.date BETWEEN '2025-06-01' AND '2025-06-30'
    AND b.txn_id IS NULL
ORDER BY l.date;


-- ============================================================================
-- LESSON 10: CASE WHEN — build categories/logic inside SQL
-- ============================================================================
-- This is how you'd rebuild something like your credit risk tier logic
-- directly in SQL instead of Python.

SELECT
    date,
    description,
    amount,
    CASE
        WHEN amount >= 500000 THEN 'Large'
        WHEN amount >= 50000  THEN 'Medium'
        WHEN amount >= 0      THEN 'Small'
        ELSE 'Outflow'
    END AS transaction_size
FROM bank_statement
WHERE date BETWEEN '2025-06-01' AND '2025-06-30'
ORDER BY amount DESC;
-- CASE WHEN works top-to-bottom — the FIRST matching condition wins.


-- ============================================================================
-- LESSON 11: Subqueries — a query inside a query
-- ============================================================================
-- Sometimes you need the result of one query to feed into another.

SELECT date, description, amount
FROM bank_statement
WHERE amount < (
    SELECT AVG(amount) FROM bank_statement WHERE amount < 0
)
ORDER BY amount ASC;
-- "Show me outgoing payments that are BIGGER than the average outgoing
-- payment" — the inner query calculates that average on the fly.


-- ============================================================================
-- LESSON 12: UNION — stack two result sets into one
-- ============================================================================
-- Useful for building a single combined "reconciliation report" from
-- separate matched/unmatched queries.

SELECT 'MATCHED' AS status, b.date, b.description, b.amount
FROM bank_statement b
JOIN ledger l
    ON b.amount = l.amount
    AND ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) <= 7
WHERE b.date BETWEEN '2025-06-01' AND '2025-06-30'

UNION ALL

SELECT 'UNMATCHED' AS status, b.date, b.description, b.amount
FROM bank_statement b
LEFT JOIN ledger l
    ON b.amount = l.amount
    AND ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) <= 7
WHERE b.date BETWEEN '2025-06-01' AND '2025-06-30'
    AND l.txn_id IS NULL

ORDER BY 2;
-- ORDER BY 2 means "sort by the 2nd column in the result" (date) — with
-- UNION ALL, ORDER BY needs to refer to the combined result's column
-- position or its output name, not "b.date" (SQL no longer knows which
-- table "b" was once the two queries are stacked together).
-- UNION ALL stacks both result sets into one list, with a status label
-- showing which "bucket" each row came from. This is basically a
-- one-query version of your whole reconciliation report.


-- ============================================================================
-- LESSON 13: CREATE VIEW — save a query as a reusable "virtual table"
-- ============================================================================
-- A VIEW doesn't store data itself — it just saves the query so you can
-- reuse it by name instead of retyping it every time.

CREATE VIEW IF NOT EXISTS june_unmatched_bank AS
SELECT b.date, b.description, b.amount
FROM bank_statement b
LEFT JOIN ledger l
    ON b.amount = l.amount
    AND ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) <= 7
WHERE b.date BETWEEN '2025-06-01' AND '2025-06-30'
    AND l.txn_id IS NULL;

-- Now you can just do this instead of the whole query above:
SELECT * FROM june_unmatched_bank ORDER BY amount ASC;

-- To remove a view later:
-- DROP VIEW IF EXISTS june_unmatched_bank;


-- ============================================================================
-- LESSON 14 (bonus/stretch): Window functions — running totals
-- ============================================================================
-- This recreates the "running balance" concept from your Excel files,
-- calculated fresh from the transactions themselves.

SELECT
    date,
    description,
    amount,
    SUM(amount) OVER (ORDER BY date, txn_id) AS running_balance
FROM bank_statement
WHERE date BETWEEN '2025-06-01' AND '2025-06-30'
ORDER BY date, txn_id;
-- OVER (ORDER BY ...) tells SQL "keep a running total as you go down
-- the rows in this order" — no GROUP BY needed, every row stays visible.


-- ============================================================================
-- QUICK REFERENCE — what each keyword means
-- ============================================================================
-- SELECT      : which columns to show
-- FROM        : which table
-- WHERE       : filter rows (before grouping)
-- GROUP BY    : collapse rows into per-category summaries
-- HAVING      : filter AFTER grouping (e.g. HAVING COUNT(*) > 5)
-- ORDER BY    : sort results
-- LIMIT       : cap number of rows returned
-- JOIN        : combine two tables on a matching condition (only matches kept)
-- LEFT JOIN   : combine two tables, keep ALL left-table rows even with no match
-- DISTINCT    : remove duplicate rows / count unique values
-- CASE WHEN   : if/elif/else logic inside a query
-- UNION ALL   : stack two result sets together
-- CREATE VIEW : save a query under a reusable name
-- OVER()      : window function — running totals, rankings, etc. without collapsing rows
-- ============================================================================
