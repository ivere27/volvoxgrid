' Test 64: Visible-row recovery helpers (sfFindVisibleRow pattern)
fg.Redraw = False
fg.FontSize = 10

fg.Cols = 4
fg.Rows = 14
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "Seq"
fg.TextMatrix(0, 1) = "Code"
fg.TextMatrix(0, 2) = "Name"
fg.TextMatrix(0, 3) = "State"

Dim i
For i = 1 To 13
    fg.TextMatrix(i, 0) = CStr(i)
    fg.TextMatrix(i, 1) = "K-" & Right("00" & CStr(i), 2)
    fg.TextMatrix(i, 2) = "Row " & CStr(i)
    fg.TextMatrix(i, 3) = ""
Next

fg.RowHidden(4) = True
fg.RowHidden(5) = True
fg.RowHidden(6) = True
fg.RowHidden(7) = True

Function sfFindNextVisibleRow(oSheet, lRow)
    Dim lIdx
    sfFindNextVisibleRow = -1
    For lIdx = lRow To oSheet.Rows - 1
        If Not oSheet.RowHidden(lIdx) Then
            sfFindNextVisibleRow = lIdx
            Exit Function
        End If
    Next
End Function

Function sfFindPrevVisibleRow(oSheet, lRow)
    Dim lIdx
    sfFindPrevVisibleRow = -1
    For lIdx = lRow To oSheet.FixedRows Step -1
        If Not oSheet.RowHidden(lIdx) Then
            sfFindPrevVisibleRow = lIdx
            Exit Function
        End If
    Next
End Function

Function sfFindVisibleRow(oSheet, lRow)
    sfFindVisibleRow = sfFindNextVisibleRow(oSheet, lRow)
    If sfFindVisibleRow = -1 Then
        sfFindVisibleRow = sfFindPrevVisibleRow(oSheet, lRow)
    End If
End Function

Dim targetRow, recoveredRow
targetRow = 6
recoveredRow = sfFindVisibleRow(fg, targetRow)
If recoveredRow >= fg.FixedRows Then
    fg.Row = recoveredRow
    fg.Col = 1
    If recoveredRow > fg.FixedRows Then
        fg.TopRow = recoveredRow - 1
    Else
        fg.TopRow = fg.FixedRows
    End If
    fg.TextMatrix(recoveredRow, 3) = "RECOVERED"
    fg.Cell(6, recoveredRow, 0, recoveredRow, fg.Cols - 1) = RGB(240, 252, 240)
End If

fg.ColWidth(0) = 700
fg.ColWidth(1) = 1000
fg.ColWidth(2) = 1400
fg.ColWidth(3) = 1300

fg.Redraw = True
