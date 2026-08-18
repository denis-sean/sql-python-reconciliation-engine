"""
SQL-Powered Bank Reconciliation Engine
Project 10 — combines everything learned: Python automation + SQL joins,
running directly against a real SQLite database instead of CSVs.

This is Project 3 (Bank Reconciliation Automator) rebuilt on a proper
database foundation — same business logic, upgraded architecture.

Run with:
    python sql_reconciliation_engine.py

Requires: bank_reconciliation.db in the same folder (built earlier in
DB Browser for SQLite — contains bank_statement and ledger tables).
"""

import sqlite3
import pandas as pd
from datetime import datetime

DB_FILE = "sample_bank_reconciliation.db"
OUTPUT_FILE = "sql_reconciliation_report.xlsx"

DATE_WINDOW_DAYS = 7   # how many days apart a match can still count
START_DATE = "2025-06-01"
END_DATE = "2025-06-30"


def connect(db_file: str) -> sqlite3.Connection:
    """Open a connection to the SQLite database."""
    return sqlite3.connect(db_file)


def get_matched(conn: sqlite3.Connection) -> pd.DataFrame:
    """
    Matched transactions — same amount, within the date window.
    Uses DISTINCT bank txn_id logic to avoid double-counting fan-out matches
    (the exact issue we discovered and fixed during the SQL lessons).
    """
    query = """
        SELECT
            b.txn_id AS bank_txn_id,
            b.date AS bank_date,
            l.date AS ledger_date,
            b.amount AS bank_amount,
            l.amount AS ledger_amount,
            b.description AS bank_description,
            l.description AS ledger_description,
            ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) AS date_gap_days
        FROM bank_statement b
        JOIN ledger l
            ON b.amount = l.amount
            AND ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) <= ?
        WHERE b.date BETWEEN ? AND ?
        ORDER BY b.date;
    """
    df = pd.read_sql_query(query, conn, params=(DATE_WINDOW_DAYS, START_DATE, END_DATE))
    # Keep the closest-date match per bank transaction, drop the rest (de-fan-out)
    df = df.sort_values("date_gap_days").drop_duplicates(subset="bank_txn_id", keep="first")
    return df.sort_values("bank_date")


def get_unmatched_bank(conn: sqlite3.Connection) -> pd.DataFrame:
    """Bank transactions with no ledger match at all, within the date window."""
    query = """
        SELECT b.date, b.description, b.amount
        FROM bank_statement b
        LEFT JOIN ledger l
            ON b.amount = l.amount
            AND ABS(JULIANDAY(b.date) - JULIANDAY(l.date)) <= ?
        WHERE b.date BETWEEN ? AND ?
            AND l.txn_id IS NULL
        ORDER BY b.date;
    """
    return pd.read_sql_query(query, conn, params=(DATE_WINDOW_DAYS, START_DATE, END_DATE))


def get_unmatched_ledger(conn: sqlite3.Connection) -> pd.DataFrame:
    """Ledger entries with no bank match at all, within the date window."""
    query = """
        SELECT l.date, l.description, l.amount
        FROM ledger l
        LEFT JOIN bank_statement b
            ON l.amount = b.amount
            AND ABS(JULIANDAY(l.date) - JULIANDAY(b.date)) <= ?
        WHERE l.date BETWEEN ? AND ?
            AND b.txn_id IS NULL
        ORDER BY l.date;
    """
    return pd.read_sql_query(query, conn, params=(DATE_WINDOW_DAYS, START_DATE, END_DATE))


def get_summary_stats(conn: sqlite3.Connection) -> dict:
    """Quick summary counts, straight from SQL aggregates."""
    cur = conn.cursor()

    cur.execute("SELECT COUNT(*) FROM bank_statement WHERE date BETWEEN ? AND ?", (START_DATE, END_DATE))
    total_bank = cur.fetchone()[0]

    cur.execute("SELECT COUNT(*) FROM ledger WHERE date BETWEEN ? AND ?", (START_DATE, END_DATE))
    total_ledger = cur.fetchone()[0]

    return {"total_bank": total_bank, "total_ledger": total_ledger}


def export_report(matched: pd.DataFrame, unmatched_bank: pd.DataFrame,
                   unmatched_ledger: pd.DataFrame, stats: dict) -> None:
    """Export everything to a multi-sheet Excel report."""
    with pd.ExcelWriter(OUTPUT_FILE) as writer:
        matched.to_excel(writer, sheet_name="Matched", index=False)
        unmatched_bank.to_excel(writer, sheet_name="Unmatched Bank", index=False)
        unmatched_ledger.to_excel(writer, sheet_name="Unmatched Ledger", index=False)

        summary = pd.DataFrame({
            "Metric": [
                "Period",
                "Total Bank Transactions",
                "Total Ledger Entries",
                "Matched (unique, de-duplicated)",
                "Unmatched Bank Items",
                "Unmatched Ledger Items",
                "Reconciliation Rate",
            ],
            "Value": [
                f"{START_DATE} to {END_DATE}",
                stats["total_bank"],
                stats["total_ledger"],
                len(matched),
                len(unmatched_bank),
                len(unmatched_ledger),
                f"{len(matched) / stats['total_bank'] * 100:.1f}%",
            ]
        })
        summary.to_excel(writer, sheet_name="Summary", index=False)


def print_summary(matched: pd.DataFrame, unmatched_bank: pd.DataFrame,
                   unmatched_ledger: pd.DataFrame, stats: dict) -> None:
    print(f"\n{'='*70}")
    print(f"SQL-POWERED RECONCILIATION — {START_DATE} to {END_DATE}")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"{'='*70}\n")
    print(f"Total bank transactions:  {stats['total_bank']}")
    print(f"Total ledger entries:     {stats['total_ledger']}")
    print(f"Matched (de-duplicated):  {len(matched)}")
    print(f"Unmatched bank items:     {len(unmatched_bank)}")
    print(f"Unmatched ledger items:   {len(unmatched_ledger)}")
    print(f"Reconciliation rate:      {len(matched) / stats['total_bank'] * 100:.1f}%")
    print(f"\nReport saved to: {OUTPUT_FILE}")
    print(f"{'='*70}\n")


def main():
    print("Connecting to database...")
    conn = connect(DB_FILE)

    print("Running matched-transaction query...")
    matched = get_matched(conn)

    print("Running unmatched-bank query...")
    unmatched_bank = get_unmatched_bank(conn)

    print("Running unmatched-ledger query...")
    unmatched_ledger = get_unmatched_ledger(conn)

    print("Fetching summary stats...")
    stats = get_summary_stats(conn)

    conn.close()

    print("Exporting report...")
    export_report(matched, unmatched_bank, unmatched_ledger, stats)

    print_summary(matched, unmatched_bank, unmatched_ledger, stats)


if __name__ == "__main__":
    main()
