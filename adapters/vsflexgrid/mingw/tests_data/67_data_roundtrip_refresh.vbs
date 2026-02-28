' Test 67: Data roundtrip pattern (sfMakeSheetToArrayEx -> sfIsValidData -> sfRefreshSheetEx)

fg.Redraw = False
fg.FontSize = 10

fg.Cols = 5
fg.Rows = 8
fg.FixedRows = 1
fg.FixedCols = 0

fg.TextMatrix(0, 0) = "MARK"
fg.TextMatrix(0, 1) = "DOC_NO"
fg.TextMatrix(0, 2) = "ITEM_NAME"
fg.TextMatrix(0, 3) = "QTY"
fg.TextMatrix(0, 4) = "STATUS"

fg.TextMatrix(1, 0) = "I": fg.TextMatrix(1, 1) = "D-001": fg.TextMatrix(1, 2) = "Rotor":     fg.TextMatrix(1, 3) = "10": fg.TextMatrix(1, 4) = "NEW"
fg.TextMatrix(2, 0) = "U": fg.TextMatrix(2, 1) = "D-002": fg.TextMatrix(2, 2) = "Stator":    fg.TextMatrix(2, 3) = "22": fg.TextMatrix(2, 4) = "EDIT"
fg.TextMatrix(3, 0) = "D": fg.TextMatrix(3, 1) = "D-003": fg.TextMatrix(3, 2) = "Seal":      fg.TextMatrix(3, 3) = "05": fg.TextMatrix(3, 4) = "DROP"
fg.TextMatrix(4, 0) = "":  fg.TextMatrix(4, 1) = "D-004": fg.TextMatrix(4, 2) = "Bearing":   fg.TextMatrix(4, 3) = "15": fg.TextMatrix(4, 4) = "KEEP"
fg.TextMatrix(5, 0) = "U": fg.TextMatrix(5, 1) = "D-005": fg.TextMatrix(5, 2) = "Coupling":  fg.TextMatrix(5, 3) = "09": fg.TextMatrix(5, 4) = "EDIT"
fg.TextMatrix(6, 0) = "D": fg.TextMatrix(6, 1) = "D-006": fg.TextMatrix(6, 2) = "Bracket":   fg.TextMatrix(6, 3) = "07": fg.TextMatrix(6, 4) = "DROP"
fg.TextMatrix(7, 0) = "I": fg.TextMatrix(7, 1) = "D-007": fg.TextMatrix(7, 2) = "Fastener":  fg.TextMatrix(7, 3) = "18": fg.TextMatrix(7, 4) = "NEW"

fg.ColWidth(0) = 800
fg.ColWidth(1) = 1300
fg.ColWidth(2) = 1700
fg.ColWidth(3) = 900
fg.ColWidth(4) = 1600

Function sfMakeSheetToArrayEx(oSheet, sMark)
    Dim r, mark, count, idx, aDataSet

    count = -1
    For r = oSheet.FixedRows To oSheet.Rows - 1
        mark = UCase(Trim(oSheet.TextMatrix(r, 0)))
        If Len(mark) > 0 Then
            If Len(sMark) = 0 Or mark = UCase(sMark) Then
                count = count + 1
            End If
        End If
    Next

    If count < 0 Then
        sfMakeSheetToArrayEx = False
        Exit Function
    End If

    ReDim aDataSet(count, 4)
    idx = 0
    For r = oSheet.FixedRows To oSheet.Rows - 1
        mark = UCase(Trim(oSheet.TextMatrix(r, 0)))
        If Len(mark) > 0 Then
            If Len(sMark) = 0 Or mark = UCase(sMark) Then
                aDataSet(idx, 0) = r
                aDataSet(idx, 1) = mark
                aDataSet(idx, 2) = oSheet.TextMatrix(r, 1)
                aDataSet(idx, 3) = oSheet.TextMatrix(r, 2)
                aDataSet(idx, 4) = oSheet.TextMatrix(r, 3)
                idx = idx + 1
            End If
        End If
    Next

    sfMakeSheetToArrayEx = aDataSet
End Function

Function sfIsValidData(oSheet, aDataSet, bMake)
    sfIsValidData = IsArray(aDataSet)
End Function

Sub sfRefreshSheetEx(oSheet, aDataSet, sSetCols)
    Dim i, rowNo, mark

    If Not IsArray(aDataSet) Then Exit Sub

    For i = UBound(aDataSet, 1) To 0 Step -1
        rowNo = CLng(aDataSet(i, 0))
        mark = UCase(CStr(aDataSet(i, 1)))
        Select Case mark
            Case "D"
                oSheet.RemoveItem rowNo
            Case Else
                oSheet.TextMatrix(rowNo, 0) = "S"
                oSheet.TextMatrix(rowNo, 4) = "SYNC"
                oSheet.RowData(rowNo) = "SAVE"
        End Select
    Next
End Sub

Function CountMark(oSheet, sMark)
    Dim r, cnt
    cnt = 0
    For r = oSheet.FixedRows To oSheet.Rows - 1
        If UCase(Trim(oSheet.TextMatrix(r, 0))) = UCase(sMark) Then
            cnt = cnt + 1
        End If
    Next
    CountMark = cnt
End Function

Dim aDataSet, ok
aDataSet = sfMakeSheetToArrayEx(fg, "")
ok = sfIsValidData(fg, aDataSet, True)
If ok Then
    Call sfRefreshSheetEx(fg, aDataSet, "DOC_NO,ITEM_NAME,QTY,STATUS")
End If

fg.TextMatrix(0, 4) = "I=" & CStr(CountMark(fg, "I")) & _
                      ",U=" & CStr(CountMark(fg, "U")) & _
                      ",D=" & CStr(CountMark(fg, "D")) & _
                      ",S=" & CStr(CountMark(fg, "S"))
fg.TopRow = 1
fg.Redraw = True
