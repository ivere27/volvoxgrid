const gridOptions = {
  defaultColDef: {
    resizable: true,
    minWidth: 100,
    flex: 1,
  },
  columnDefs: [
    { field: 'make', headerName: 'Make', flex: 1 },
    { field: 'model', headerName: 'Model', flex: 2 },
    {
      field: 'price',
      headerName: 'Price',
      flex: 1,
      valueFormatter: (p) => '$' + Number(p.value ?? 0).toLocaleString('en-US'),
    },
    { field: 'electric', headerName: 'Electric', flex: 1 },
  ],
  rowData: [
    { make: 'Tesla', model: 'Model Y', price: 46990, electric: true },
    { make: 'Kia', model: 'EV6', price: 42900, electric: true },
    { make: 'Honda', model: 'Civic', price: 26300, electric: false },
  ],
};
