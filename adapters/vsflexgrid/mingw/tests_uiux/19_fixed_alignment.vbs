' Test 19: Fixed header alignment
' Per-column alignment for the fixed header row.
fg.FontSize = 10
Call PopulateStandard()
fg.FixedAlignment(0) = 1  ' flexAlignLeftCenter
fg.FixedAlignment(1) = 4  ' flexAlignCenterCenter
fg.FixedAlignment(2) = 7  ' flexAlignRightCenter
fg.FixedAlignment(3) = 4  ' flexAlignCenterCenter
fg.FixedAlignment(4) = 1  ' flexAlignLeftCenter
