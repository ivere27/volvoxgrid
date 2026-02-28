const gridOptions = {
  defaultColDef: {
    sortable: true,
    filter: true,
    resizable: true,
    flex: 1,
    minWidth: 110,
  },
  columnDefs: [
    { field: 'make', headerName: 'Make' },
    { field: 'model', headerName: 'Model' },
    {
      field: 'price',
      headerName: 'Price',
      valueFormatter: (p) => '$' + Number(p.value ?? 0).toLocaleString('en-US'),
    },
    { field: 'electric', headerName: 'Electric' },
  ],
  rowData: [
    { make: 'Tesla', model: 'Model 3', price: 39990, electric: true },
    { make: 'Hyundai', model: 'IONIQ 5', price: 45200, electric: true },
    { make: 'Toyota', model: 'Camry', price: 28900, electric: false },
  ],
};
