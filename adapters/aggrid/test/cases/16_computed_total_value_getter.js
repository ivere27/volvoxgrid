const columnDefs = [
  { field: 'item', headerName: 'Item' },
  { field: 'qty', headerName: 'Qty' },
  { field: 'unitPrice', headerName: 'Unit Price' },
  {
    field: 'total',
    headerName: 'Total',
    valueGetter: (p) => Number(p.data.qty ?? 0) * Number(p.data.unitPrice ?? 0),
    valueFormatter: (p) => '$' + Number(p.value ?? 0).toFixed(2),
  },
];

const rowData = [
  { item: 'Notebook', qty: 4, unitPrice: 3.5 },
  { item: 'Marker', qty: 10, unitPrice: 1.2 },
  { item: 'Paper', qty: 2, unitPrice: 6.75 },
];
