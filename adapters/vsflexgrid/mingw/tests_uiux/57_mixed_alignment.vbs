' Test 57: All 9 alignment values in one grid
' Tests every combination of horizontal (left/center/right) x vertical (top/center/bottom).
' flexAlignLeftTop=0, flexAlignLeftCenter=1, flexAlignLeftBottom=2
' flexAlignCenterTop=3, flexAlignCenterCenter=4, flexAlignCenterBottom=5
' flexAlignRightTop=6, flexAlignRightCenter=7, flexAlignRightBottom=8
fg.FontSize = 10
fg.Redraw = False

fg.Cols = 4
fg.Rows = 10
fg.FixedRows = 1
fg.FixedCols = 1

fg.TextMatrix(0, 0) = "Align"
fg.TextMatrix(0, 1) = "Col A"
fg.TextMatrix(0, 2) = "Col B"
fg.TextMatrix(0, 3) = "Col C"

' Tall rows to see vertical alignment
For i = 1 To 9
    fg.RowHeight(i) = 600
Next

fg.TextMatrix(1, 0) = "LT=0"
fg.TextMatrix(2, 0) = "LC=1"
fg.TextMatrix(3, 0) = "LB=2"
fg.TextMatrix(4, 0) = "CT=3"
fg.TextMatrix(5, 0) = "CC=4"
fg.TextMatrix(6, 0) = "CB=5"
fg.TextMatrix(7, 0) = "RT=6"
fg.TextMatrix(8, 0) = "RC=7"
fg.TextMatrix(9, 0) = "RB=8"

' Set each column to different alignment per row
' Col 1: alignment 0-8 for rows 1-9
fg.ColAlignment(1) = 0
fg.ColAlignment(2) = 4
fg.ColAlignment(3) = 8

For i = 1 To 9
    fg.TextMatrix(i, 1) = "Left/Center/Right"
    fg.TextMatrix(i, 2) = "Centered"
    fg.TextMatrix(i, 3) = "Right-Bottom"
Next

fg.ColWidth(0) = 900
fg.ColWidth(1) = 2400
fg.ColWidth(2) = 2000
fg.ColWidth(3) = 2000

fg.Redraw = True
