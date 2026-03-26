' Test 70: Filter a bound ADODB.Recordset and refresh the grid.

On Error Resume Next

fg.Redraw = False
fg.FontSize = 10

Dim rs
Set rs = CreateObject("ADODB.Recordset")
If Err.Number = 0 Then
    rs.CursorLocation = 3
    rs.Fields.Append "CATEGORY", 200, 8
    rs.Fields.Append "ITEM_NAME", 200, 24
    rs.Open

    rs.AddNew
    rs("CATEGORY") = "A"
    rs("ITEM_NAME") = "Impeller"
    rs.Update

    rs.AddNew
    rs("CATEGORY") = "B"
    rs("ITEM_NAME") = "Seal"
    rs.Update

    rs.AddNew
    rs("CATEGORY") = "A"
    rs("ITEM_NAME") = "Bracket"
    rs.Update

    Set fg.DataSource = rs
    rs.Filter = "CATEGORY = 'A'"
    fg.DataRefresh

    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TopRow = 1
    fg.ColWidth(0) = 1200
    fg.ColWidth(1) = 2200

    fg.TextMatrix(0, 0) = "FILTER"
    fg.TextMatrix(0, 1) = "A"
    If fg.Rows > fg.FixedRows Then
        fg.TextMatrix(1, 1) = "ROWS=" & CStr(fg.Rows - fg.FixedRows)
    End If
Else
    Err.Clear
    fg.Cols = 2
    fg.Rows = 2
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TextMatrix(0, 0) = "ADODB"
    fg.TextMatrix(0, 1) = "Filter"
    fg.TextMatrix(1, 0) = "Fallback"
    fg.TextMatrix(1, 1) = "Unavailable"
End If

On Error GoTo 0
fg.Redraw = True
