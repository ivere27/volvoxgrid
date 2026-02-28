const columnDefs = [
  {
    headerName: 'Identity',
    children: [
      { field: 'id', headerName: 'ID', width: 100 },
      { field: 'name', headerName: 'Name' },
    ],
  },
  { field: 'country', headerName: 'Country' },
  {
    headerName: 'Metrics',
    children: [
      { field: 'qty', headerName: 'Qty' },
      {
        field: 'amount',
        headerName: 'Amount',
        valueFormatter: (p) => '$' + Number(p.value ?? 0).toFixed(1),
      },
    ],
  },
];

const rowData = [
  { id: 'U-01', name: 'Alpha', country: 'KOR', qty: 2, amount: 10.5 },
  { id: 'U-02', name: 'Beta', country: 'USA', qty: 4, amount: 22.0 },
  { id: 'U-03', name: 'Gamma', country: 'ITA', qty: 1, amount: 8.0 },
];
