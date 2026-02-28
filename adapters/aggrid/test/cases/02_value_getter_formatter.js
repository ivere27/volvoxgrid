const columnDefs = [
  { field: 'name', headerName: 'Name' },
  {
    field: 'score',
    headerName: 'Score',
    valueGetter: (p) => (p.data.base ?? 0) * (p.data.multiplier ?? 1),
    valueFormatter: (p) => Number(p.value).toFixed(1),
  },
];

const rowData = [
  { name: 'Desk', base: 12, multiplier: 2 },
  { name: 'Chair', base: 5, multiplier: 3 },
  { name: 'Lamp', base: 2.5, multiplier: 4 },
];
