' Test 30: Fill style repeat
' With FillRepeat, setting a property applies to all selected cells.
fg.FontSize = 10
Call PopulateStandard()
fg.FillStyle = 1  ' flexFillRepeat
fg.Row = 2
fg.Col = 1
fg.RowSel = 6
fg.ColSel = 3
