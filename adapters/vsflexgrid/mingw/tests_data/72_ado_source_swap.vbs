' Test 72: Rebind the grid from one ADODB.Recordset to another.

On Error Resume Next

fg.Redraw = False
fg.FontSize = 10

Dim rsA, rsB, fieldName
Set rsA = CreateObject("ADODB.Recordset")
If Err.Number = 0 Then
    rsA.CursorLocation = 3
    rsA.Fields.Append "DOC_NO", 200, 12
    rsA.Fields.Append "ITEM_NAME", 200, 24
    rsA.Open
    rsA.AddNew
    rsA("DOC_NO") = "D-3001"
    rsA("ITEM_NAME") = "Housing"
    rsA.Update

    Set rsB = CreateObject("ADODB.Recordset")
    rsB.CursorLocation = 3
    rsB.Fields.Append "LOT_NO", 200, 12
    rsB.Fields.Append "STATUS", 200, 16
    rsB.Open

    rsB.AddNew
    rsB("LOT_NO") = "L-01"
    rsB("STATUS") = "OPEN"
    rsB.Update

    rsB.AddNew
    rsB("LOT_NO") = "L-02"
    rsB("STATUS") = "HOLD"
    rsB.Update

    rsB.AddNew
    rsB("LOT_NO") = "L-03"
    rsB("STATUS") = "DONE"
    rsB.Update

    Set fg.DataSource = rsA
    Set fg.DataSource = rsB
    fg.DataRefresh

    fieldName = fg.DataSource.Fields(0).Name
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TopRow = 1
    fg.ColWidth(0) = 1400
    fg.ColWidth(1) = 1400

    fg.TextMatrix(0, 0) = fieldName
    fg.TextMatrix(0, 1) = "SWAP"
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
    fg.TextMatrix(0, 1) = "Swap"
    fg.TextMatrix(1, 0) = "Fallback"
    fg.TextMatrix(1, 1) = "Unavailable"
End If

On Error GoTo 0
fg.Redraw = True
