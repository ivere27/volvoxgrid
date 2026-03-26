' Test 68: ADO property surface + DataRefresh rebind
' Verifies DataSource getter, DataMode, VirtualData, and DataRefresh.

On Error Resume Next

fg.Redraw = False
fg.FontSize = 10

Dim rs, modeVal, virtualVal, sourceField
Set rs = CreateObject("ADODB.Recordset")
If Err.Number = 0 Then
    rs.Fields.Append "ITEM_CODE", 200, 12
    rs.Fields.Append "ITEM_NAME", 200, 24
    rs.Open

    rs.AddNew
    rs("ITEM_CODE") = "A-2001"
    rs("ITEM_NAME") = "Valve"
    rs.Update

    fg.DataMode = 3
    fg.VirtualData = True
    Set fg.DataSource = rs

    modeVal = fg.DataMode
    virtualVal = fg.VirtualData
    sourceField = fg.DataSource.Fields(0).Name

    rs.AddNew
    rs("ITEM_CODE") = "A-2002"
    rs("ITEM_NAME") = "Impeller"
    rs.Update

    fg.DataRefresh
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TopRow = 1

    fg.TextMatrix(0, 0) = sourceField
    fg.TextMatrix(0, 1) = "M=" & CStr(modeVal) & ",V=" & CStr(CBool(virtualVal))
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
    fg.TextMatrix(0, 1) = "Unavailable"
    fg.TextMatrix(1, 0) = "Fallback"
    fg.TextMatrix(1, 1) = "No ADO runtime"
End If

On Error GoTo 0
fg.Redraw = True
