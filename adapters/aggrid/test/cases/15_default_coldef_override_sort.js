const gridOptions = {
  defaultColDef: {
    sortable: true,
    resizable: true,
    flex: 1,
  },
  columnDefs: [
    { field: 'country', headerName: 'Country' },
    { field: 'city', headerName: 'City' },
    {
      field: 'population',
      headerName: 'Population',
      sort: 'desc',
      valueFormatter: (p) => Number(p.value ?? 0).toLocaleString('en-US'),
    },
    { field: 'capital', headerName: 'Capital', width: 120, flex: undefined },
  ],
  rowData: [
    { country: 'Korea', city: 'Seoul', population: 9500000, capital: 'Y' },
    { country: 'USA', city: 'New York', population: 8400000, capital: 'N' },
    { country: 'Japan', city: 'Tokyo', population: 14000000, capital: 'Y' },
  ],
};
