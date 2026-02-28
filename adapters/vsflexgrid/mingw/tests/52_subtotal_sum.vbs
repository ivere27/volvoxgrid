' Test 52: Subtotal with Sum aggregate (flexSTSum=1)
' All previous subtotal tests use aggregate=5 (average).
' This tests Sum aggregation which is more common in ERP.
fg.FontSize = 10
Call PopulateStandard()
fg.Col = 1
fg.ColSel = 1
fg.Sort = 1

fg.Subtotal 2, 1, 2, "Sum", &HFFD0C0, &H000000, 1
fg.OutlineBar = 1
fg.OutlineCol = 0
