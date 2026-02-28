const gridOptions = {
  columnDefs: [
    { field: 'name', headerName: 'Name' },
    {
      field: 'amount',
      headerName: 'Amount',
      valueFormatter: (p) => '$' + Number(p.value ?? 0).toFixed(2),
    },
  ],
  pinnedTopRowData: [{ name: 'HEADER_SUM', amount: 99 }],
  rowData: [
    { name: 'Line-1', amount: 10 },
    { name: 'Line-2', amount: 20 },
    { name: 'Line-3', amount: 30 },
  ],
  pinnedBottomRowData: [{ name: 'FOOTER_SUM', amount: 60 }],
};
