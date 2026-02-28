const columnDefs = [
  {
    headerName: 'Identity',
    children: [
      { field: 'id', headerName: 'ID' },
      { field: 'name', headerName: 'Name' },
    ],
  },
  {
    headerName: 'Metrics',
    children: [
      { field: 'qty', headerName: 'Qty' },
      { field: 'amount', headerName: 'Amount' },
    ],
  },
];

const rowData = [
  { id: 'A-100', name: 'Alpha', qty: 2, amount: 10.5 },
  { id: 'B-110', name: 'Beta', qty: 4, amount: 22.0 },
  { id: 'C-120', name: 'Gamma', qty: 1, amount: 8.0 },
];
