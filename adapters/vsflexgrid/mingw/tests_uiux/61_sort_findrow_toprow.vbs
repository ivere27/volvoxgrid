' Test 61: Sort + key lookup + TopRow navigation
' Mirrors BeforeSort/AfterSort pattern that restores focus row after sort.
fg.Redraw = False
fg.FontSize = 10

fg.Cols = 5
fg.Rows = 21
fg.FixedRows = 1
fg.FixedCols = 1

fg.TextMatrix(0, 0) = "#"
fg.TextMatrix(0, 1) = "Key"
fg.TextMatrix(0, 2) = "Name"
fg.TextMatrix(0, 3) = "Qty"
fg.TextMatrix(0, 4) = "Region"

Dim keys
keys = Array("K-011", "K-003", "K-019", "K-005", "K-001", "K-017", "K-009", "K-013", "K-007", "K-015", _
             "K-002", "K-018", "K-004", "K-020", "K-006", "K-014", "K-008", "K-016", "K-010", "K-012")
Dim regionCodes
regionCodes = Array("N", "S", "E", "W")

Dim i
For i = 1 To 20
    fg.TextMatrix(i, 0) = CStr(i)
    fg.TextMatrix(i, 1) = keys(i - 1)
    fg.TextMatrix(i, 2) = "Item " & Right(keys(i - 1), 3)
    fg.TextMatrix(i, 3) = CStr((i * 7) Mod 41 + 10)
    fg.TextMatrix(i, 4) = regionCodes((i - 1) Mod 4)
Next

fg.ColWidth(0) = 600
fg.ColWidth(1) = 1300
fg.ColWidth(2) = 1800
fg.ColWidth(3) = 900
fg.ColWidth(4) = 900
fg.ColAlignment(3) = 7

' Sort by key then find a specific row and move viewport to it.
fg.Col = 1
fg.ColSel = 1
fg.Sort = 1

Dim targetRow
' After sorting Key ascending, "K-017" lands on row 17.
targetRow = 17

If targetRow >= fg.FixedRows Then
    fg.Row = targetRow
    If fg.Row > 3 Then
        fg.TopRow = fg.Row - 2
    Else
        fg.TopRow = fg.Row
    End If
End If

fg.Redraw = True
