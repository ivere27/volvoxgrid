const columnDefs = [
  { field: 'category', headerName: 'Category', width: 180 },
  { field: 'qty', headerName: 'Qty', width: 100 },
  {
    field: 'amount',
    headerName: 'Amount',
    width: 140,
    valueFormatter: (p) => '$' + Number(p.value ?? 0).toFixed(2),
  },
];

const pinnedTopRowData = [
  { category: 'TARGET', qty: 20, amount: 100.0 },
  { category: 'FORECAST', qty: 18, amount: 92.5 },
];

const rowData = [
  { category: 'North', qty: 6, amount: 31.0 },
  { category: 'South', qty: 5, amount: 26.5 },
  { category: 'East', qty: 4, amount: 18.0 },
  { category: 'West', qty: 3, amount: 15.0 },
];

const pinnedBottomRowData = [
  { category: 'SUBTOTAL', qty: 18, amount: 90.5 },
  { category: 'GRAND TOTAL', qty: 18, amount: 90.5 },
];
