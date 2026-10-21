Attribute VB_Name = "ReconciliationMacros"
Option Explicit

' Flags large transactions on the bank_statement sheet.
' Any amount above the threshold is made bold and red, so large items
' stand out during reconciliation review.
' Assumes: sheet named "bank_statement", headers in row 1, amounts in column B.

Sub HighlightLargeTransactions()

    Dim ws As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim threshold As Double

    Set ws = Worksheets("bank_statement")
    threshold = 10000

    lastRow = ws.Cells(ws.Rows.Count, "B").End(xlUp).Row

    For i = 2 To lastRow
        If Abs(ws.Cells(i, "B").Value) > threshold Then
            ws.Cells(i, "B").Font.Bold = True
            ws.Cells(i, "B").Font.Color = RGB(200, 0, 0)
        End If
    Next i

    MsgBox "Done! Highlighted all transactions over " & Format(threshold, "#,##0")

End Sub
