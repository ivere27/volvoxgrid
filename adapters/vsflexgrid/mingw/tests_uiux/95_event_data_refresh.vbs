' Test 95: Before/AfterDataRefresh with cancel on the second refresh.
Dim gBeforeRefresh, gAfterRefresh
gBeforeRefresh = 0
gAfterRefresh = 0

Sub fg_BeforeDataRefresh(Cancel)
    gBeforeRefresh = gBeforeRefresh + 1
    If gBeforeRefresh = 2 Then Cancel = True
End Sub

Sub fg_AfterDataRefresh()
    gAfterRefresh = gAfterRefresh + 1
End Sub

fg.Redraw = False
fg.FontSize = 10

Dim rs
On Error Resume Next
Set rs = host.CreateObject("ADODB.Recordset")
If Err.Number = 0 Then
    rs.Fields.Append "ITEM_CODE", 200, 8
    rs.Fields.Append "ITEM_NAME", 200, 24
    rs.Open

    rs.AddNew
    rs("ITEM_CODE") = "A001"
    rs("ITEM_NAME") = "Rotor"
    rs.Update

    rs.AddNew
    rs("ITEM_CODE") = "A002"
    rs("ITEM_NAME") = "Stator"
    rs.Update

    fg.DataMode = 1
    Set fg.DataSource = rs
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.Row = 1
    fg.Col = 0
Else
    Dim errNum, errDesc
    errNum = Err.Number
    errDesc = Err.Description
    Err.Clear
    fg.Cols = 2
    fg.Rows = 2
    fg.FixedRows = 1
    fg.FixedCols = 0
    fg.TextMatrix(0, 0) = "ERR"
    fg.TextMatrix(0, 1) = CStr(errNum)
    fg.TextMatrix(1, 0) = "ADO"
    fg.TextMatrix(1, 1) = Left(errDesc, 32)
End If

On Error GoTo 0
fg.Redraw = True
