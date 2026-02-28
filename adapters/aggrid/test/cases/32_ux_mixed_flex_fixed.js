const gridOptions = {
  columnDefs: [
    { field: 'id', headerName: 'ID', width: 80 },
    { field: 'name', headerName: 'Name', flex: 2, minWidth: 120 },
    { field: 'category', headerName: 'Category', width: 130 },
    { field: 'description', headerName: 'Description', flex: 3, minWidth: 150 },
    { field: 'price', headerName: 'Price', width: 100,
      valueFormatter: (p) => `$${Number(p.value ?? 0).toFixed(2)}`,
    },
  ],
  rowData: [
    { id: 'P-01', name: 'Widget A', category: 'Hardware', description: 'Standard mounting bracket', price: 12.50 },
    { id: 'P-02', name: 'Sensor B', category: 'Electronics', description: 'Thermal sensor module v2', price: 34.99 },
    { id: 'P-03', name: 'Cable C', category: 'Wiring', description: 'Shielded cable harness 2m', price: 8.75 },
  ],
};
