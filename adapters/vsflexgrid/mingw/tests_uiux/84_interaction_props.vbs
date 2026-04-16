' Test 84: ExplorerBar / TabBehavior / AllowUserFreezing with UX tab navigation
Dim gTrackMoves, gAfterRC, gLastRow, gLastCol
gTrackMoves = False
gAfterRC = 0
gLastRow = 2
gLastCol = 0

Sub UpdateStatus()
    fg.TextMatrix(1, 0) = "Cursor"
    fg.TextMatrix(1, 1) = CStr(gLastRow) & "," & CStr(gLastCol)
    fg.TextMatrix(1, 2) = "Moves=" & CStr(gAfterRC)
    fg.TextMatrix(1, 3) = CStr(fg.TabBehavior) & "/" & CStr(fg.ExplorerBar) & "/" & CStr(fg.AllowUserFreezing)
End Sub

Sub fg_AfterRowColChange(OldRow, OldCol, NewRow, NewCol)
    If gTrackMoves Then
        gAfterRC = gAfterRC + 1
        gLastRow = NewRow
        gLastCol = NewCol
        UpdateStatus
    End If
End Sub

fg.Redraw = False
fg.FontSize = 10

fg.Cols = 4
fg.Rows = 6
fg.FixedRows = 2
fg.FixedCols = 0

fg.ExplorerBar = 7          ' flexExSortShowAndMove
fg.TabBehavior = 1          ' flexTabCells
fg.AllowUserFreezing = 3    ' flexFreezeBoth

fg.TextMatrix(0, 0) = "Property"
fg.TextMatrix(0, 1) = "Value"
fg.TextMatrix(0, 2) = "SortKey"
fg.TextMatrix(0, 3) = "State"

UpdateStatus

fg.TextMatrix(2, 0) = "TabBehavior"
fg.TextMatrix(2, 1) = CStr(fg.TabBehavior)
fg.TextMatrix(2, 2) = "B"
fg.TextMatrix(2, 3) = "HostKey"

fg.TextMatrix(3, 0) = "ExplorerBar"
fg.TextMatrix(3, 1) = CStr(fg.ExplorerBar)
fg.TextMatrix(3, 2) = "A"
fg.TextMatrix(3, 3) = "SortHdr"

fg.TextMatrix(4, 0) = "AllowUserFreezing"
fg.TextMatrix(4, 1) = CStr(fg.AllowUserFreezing)
fg.TextMatrix(4, 2) = "C"
fg.TextMatrix(4, 3) = "Freeze"

fg.TextMatrix(5, 0) = "Summary"
fg.TextMatrix(5, 1) = CStr(fg.TabBehavior) & "/" & CStr(fg.ExplorerBar) & "/" & CStr(fg.AllowUserFreezing)
fg.TextMatrix(5, 2) = "D"
fg.TextMatrix(5, 3) = "Ready"

fg.ColWidth(0) = 2200
fg.ColWidth(1) = 1200
fg.ColWidth(2) = 1000
fg.ColWidth(3) = 1400
fg.BackColorFixed = RGB(214, 228, 245)
fg.ColAlignment(1) = 7

' Sorting with ExplorerBar enabled should show the sort arrow on SortKey.
fg.Col = 2
fg.ColSel = 2
fg.Sort = 1

' Keep a stable starting cell for the UX script after the sort pass.
fg.Row = 2
fg.Col = 0
gLastRow = 2
gLastCol = 0
UpdateStatus
gTrackMoves = True

fg.Redraw = True
