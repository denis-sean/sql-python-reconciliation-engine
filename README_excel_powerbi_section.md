## Excel Automation & Power BI (Power Query, VBA, DAX)

The same bank-reconciliation problem, solved with Excel and Power BI tools. Sample data only; no real financial data is included.

| Step | Tool | What it does |
|---|---|---|
| 1 | **Power Query** | Merges the bank statement and the internal ledger (Left Outer join on amount and date) and filters to unmatched rows. |
| 2 | **VBA** | `HighlightLargeTransactions` loops through the bank statement and flags any amount over 10,000 in bold red. A button on the sheet runs it. See `HighlightLargeTransactions.bas`. |
| 3 | **Power BI + DAX** | Column chart of bank transactions by date, coloured by a calculated column: `Size Category = IF(bank_statement[amount] > 10000, "Large (over 10,000)", "Normal")`. |

![Power BI dashboard](powerbi_dashboard.png)

Skills shown: Power Query merges, VBA loops and conditionals, DAX calculated columns, Power BI visuals.
