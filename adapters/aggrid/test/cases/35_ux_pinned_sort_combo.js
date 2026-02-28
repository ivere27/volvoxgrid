const gridOptions = {
  defaultColDef: {
    sortable: true,
    resizable: true,
    flex: 1,
    minWidth: 100,
  },
  columnDefs: [
    { field: 'region', headerName: 'Region', pinned: 'left', width: 120, flex: undefined },
    {
      headerName: 'Performance',
      children: [
        { field: 'revenue', headerName: 'Revenue', sort: 'desc',
          valueFormatter: (p) => `$${Number(p.value ?? 0).toLocaleString('en-US')}`,
        },
        { field: 'deals', headerName: 'Deals' },
        { field: 'conversion', headerName: 'Conv %',
          valueFormatter: (p) => `${Number(p.value ?? 0).toFixed(1)}%`,
        },
      ],
    },
  ],
  pinnedTopRowData: [
    { region: 'TARGET', revenue: 500000, deals: 100, conversion: 25.0 },
  ],
  rowData: [
    { region: 'APAC', revenue: 180000, deals: 42, conversion: 28.5 },
    { region: 'EMEA', revenue: 145000, deals: 37, conversion: 22.1 },
    { region: 'NA', revenue: 210000, deals: 51, conversion: 31.2 },
    { region: 'LATAM', revenue: 65000, deals: 18, conversion: 15.8 },
  ],
  pinnedBottomRowData: [
    { region: 'TOTAL', revenue: 600000, deals: 148, conversion: 24.4 },
  ],
};
