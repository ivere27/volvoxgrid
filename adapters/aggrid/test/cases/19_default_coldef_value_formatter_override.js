const gridOptions = {
  defaultColDef: {
    sortable: true,
    resizable: true,
    valueFormatter: (p) => {
      if (p.value == null || p.value === '') {
        return '-';
      }
      return String(p.value);
    },
  },
  columnDefs: [
    { field: 'region', headerName: 'Region', minWidth: 140 },
    {
      field: 'closedDeals',
      headerName: 'Closed Deals',
      valueFormatter: (p) => Number(p.value ?? 0).toLocaleString('en-US'),
    },
    {
      field: 'revenue',
      headerName: 'Revenue',
      valueFormatter: (p) => '$' + Number(p.value ?? 0).toLocaleString('en-US'),
    },
    { field: 'note', headerName: 'Note' },
  ],
  rowData: [
    { region: 'APAC', closedDeals: 42, revenue: 128000, note: 'On track' },
    { region: 'EMEA', closedDeals: 37, revenue: 99000, note: '' },
    { region: 'NA', closedDeals: 51, revenue: 154000 },
  ],
};
