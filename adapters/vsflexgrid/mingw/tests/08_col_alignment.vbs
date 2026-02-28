' Test 08: Column alignment
' Mix of left, center, right alignment across columns.
fg.FontSize = 10
Call PopulateStandard()
fg.ColAlignment(0) = 1  ' flexAlignLeftCenter
fg.ColAlignment(1) = 4  ' flexAlignCenterCenter
fg.ColAlignment(2) = 7  ' flexAlignRightCenter
fg.ColAlignment(3) = 4  ' flexAlignCenterCenter
fg.ColAlignment(4) = 1  ' flexAlignLeftCenter
