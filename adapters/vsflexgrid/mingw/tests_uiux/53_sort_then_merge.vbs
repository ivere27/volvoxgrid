' Test 53: Sort then merge — grouped report
' Sort by Category, then enable MergeCol on sorted column.
' Common ERP query report pattern (module-C).
fg.FontSize = 10
Call PopulateStandard()

fg.Col = 1
fg.ColSel = 1
fg.Sort = 1  ' sort ascending by Category

fg.MergeCells = 2  ' flexMergeFree
fg.MergeCol(1) = True  ' merge on Category column
