const gridOptions = {
  containerStyle: {
    '--ag-header-column-separator-display': 'block',
    '--ag-header-column-separator-width': '2px',
    '--ag-header-column-separator-height': '62%',
    '--ag-header-column-separator-color': '#9aa8ba',
    '--ag-header-column-resize-handle-display': 'none',
  },
  defaultColDef: {
    sortable: true,
    resizable: true,
    minWidth: 95,
    flex: 1,
  },
  columnDefs: [
    {
      headerName: 'Identity',
      children: [
        { field: 'athlete', headerName: 'Athlete', minWidth: 120 },
        { field: 'country', headerName: 'Country', minWidth: 100 },
      ],
    },
    {
      headerName: 'Medals',
      children: [
        { field: 'gold', headerName: 'Gold', sort: 'desc' },
        { field: 'silver', headerName: 'Silver' },
        { field: 'bronze', headerName: 'Bronze' },
        { field: 'total', headerName: 'Total' },
      ],
    },
  ],
  rowData: [
    { athlete: 'Carla', country: 'ITA', gold: 3, silver: 0, bronze: 1, total: 4 },
    { athlete: 'Alice', country: 'KOR', gold: 2, silver: 1, bronze: 0, total: 3 },
    { athlete: 'Ben', country: 'USA', gold: 1, silver: 2, bronze: 2, total: 5 },
  ],
};
